#!/usr/bin/env python3
"""
dae_triangulate.py
==================
Convert all <polylist> and <polygons> primitives in a COLLADA (.dae) file
to <triangles>, making the model fully compatible with Google Earth Pro
and Liquid Galaxy (which only support the <triangles> primitive type).

It also gracefully handles generic edge cases:
- Normalizes any Collada version to 1.4.1 schema.
- Translates models above Z=0 to prevent Google Earth terrain culling.
- Fixes Y_UP side-lying bug.
- Downgrades incompatible shaders to lambert.

Strategy
--------
Pure XML manipulation via lxml -- no pycollada object model involved.
This avoids all pycollada API fragility and handles any conforming
COLLADA file generically.

Usage
-----
    python dae_triangulate.py  input.dae  output.dae

Dependencies
------------
    pip install lxml          # that is all -- no pycollada needed

Compatible with Python 3.4+.
"""

import sys
import os
import argparse
import zipfile
import tempfile
import glob
from lxml import etree

TAG_TRIANGLES = "triangles"
TAG_POLYLIST  = "polylist"
TAG_POLYGONS  = "polygons"
TAG_TRISTRIPS = "tristrips"
TAG_TRIFANS   = "trifans"
TAG_P         = "p"
TAG_PH        = "ph"
TAG_VCOUNT    = "vcount"
ATTR_COUNT    = "count"

PRIMITIVE_TAGS = {
    TAG_POLYLIST,
    TAG_POLYGONS,
    TAG_TRISTRIPS,
    TAG_TRIFANS,
}

# ---------------------------------------------------------------------------
# Core helpers
# ---------------------------------------------------------------------------

def _get_vertex_index_stride(primitive_element):
    """
    Return the interleave stride: (max offset across all <input> children) + 1.
    A primitive with no <input> elements defaults to stride 1.
    """
    inputs = primitive_element.findall("input")
    if not inputs:
        return 1
    return max(int(inp.get("offset", "0")) for inp in inputs) + 1


def _fan_triangulate(face_vertex_counts, flat_indices, vertex_index_stride):
    """
    Fan-triangulate an interleaved index array.
    """
    out = []
    tri_count = 0
    pos = 0

    for n_verts in face_vertex_counts:
        # Gather one row (vertex_index_stride wide) per vertex of this face
        rows = []
        for _ in range(n_verts):
            rows.append(flat_indices[pos : pos + vertex_index_stride])
            pos += vertex_index_stride

        if n_verts < 3:
            continue
        if n_verts == 3:
            out.extend(rows[0])
            out.extend(rows[1])
            out.extend(rows[2])
            tri_count += 1
        else:
            for i in range(1, n_verts - 1):
                out.extend(rows[0])
                out.extend(rows[i])
                out.extend(rows[i + 1])
                tri_count += 1

    return out, tri_count


# ---------------------------------------------------------------------------
# Per-element conversion
# ---------------------------------------------------------------------------

def _convert_polylist(primitive_element):
    """
    Convert a <polylist> element to <triangles> in-place.
    Returns (old_face_count, new_tri_count), or None if malformed.
    """
    vertex_count_element = primitive_element.find(TAG_VCOUNT)
    indices_element      = primitive_element.find(TAG_P)

    # Empty primitive
    if indices_element is None:
        primitive_element.tag = TAG_TRIANGLES
        if vertex_count_element is not None:
            primitive_element.remove(vertex_count_element)
        primitive_element.set(ATTR_COUNT, "0")
        return (0, 0)

    flat_indices = list(map(int, indices_element.text.split())) if (indices_element.text or "").strip() else []
    face_vertex_counts = (
        list(map(int, vertex_count_element.text.split()))
        if (vertex_count_element is not None and (vertex_count_element.text or "").strip())
        else []
    )
    old_count = len(face_vertex_counts)
    vertex_index_stride = _get_vertex_index_stride(primitive_element)

    if not face_vertex_counts and flat_indices:
        face_size = 3 * vertex_index_stride
        if vertex_index_stride > 0 and len(flat_indices) % face_size == 0:
            old_count = len(flat_indices) // face_size
            face_vertex_counts = [3] * old_count
        else:
            return None

    if all(v == 3 for v in face_vertex_counts):
        if vertex_count_element is not None:
            primitive_element.remove(vertex_count_element)
        primitive_element.tag = TAG_TRIANGLES
        primitive_element.set(ATTR_COUNT, str(old_count))
        return (old_count, old_count)

    triangulated_indices, new_tri_count = _fan_triangulate(face_vertex_counts, flat_indices, vertex_index_stride)
    indices_element.text = " ".join(map(str, triangulated_indices))
    if vertex_count_element is not None:
        primitive_element.remove(vertex_count_element)

    primitive_element.tag = TAG_TRIANGLES
    primitive_element.set(ATTR_COUNT, str(new_tri_count))
    return (old_count, new_tri_count)


def _convert_polygons(primitive_element):
    """
    Convert a <polygons> element to <triangles> in-place.
    """
    vertex_count_element   = primitive_element.find(TAG_VCOUNT)
    sub_indices_list       = primitive_element.findall(TAG_P)
    sub_polygon_holes_list = primitive_element.findall(TAG_PH)

    if sub_polygon_holes_list:
        print("    [WARN] %d <ph> (polygon-with-holes) element(s) found. "
              "Holes are dropped; only outer contour triangulated." % len(sub_polygon_holes_list))

    if vertex_count_element is not None and len(sub_indices_list) == 1 and not sub_polygon_holes_list:
        return _convert_polylist(primitive_element)

    old_count = len(sub_indices_list) + len(sub_polygon_holes_list)
    vertex_index_stride = _get_vertex_index_stride(primitive_element)
    triangulated_flat_indices = []
    new_tri_count = 0

    for sub_indices in sub_indices_list:
        row_data = list(map(int, sub_indices.text.split())) if (sub_indices.text or "").strip() else []
        n_verts  = len(row_data) // vertex_index_stride if vertex_index_stride else 0
        rows     = [row_data[i * vertex_index_stride : (i + 1) * vertex_index_stride] for i in range(n_verts)]
        if n_verts >= 3:
            if n_verts == 3:
                triangulated_flat_indices.extend(row_data)
                new_tri_count += 1
            else:
                for i in range(1, n_verts - 1):
                    triangulated_flat_indices.extend(rows[0])
                    triangulated_flat_indices.extend(rows[i])
                    triangulated_flat_indices.extend(rows[i + 1])
                    new_tri_count += 1
        primitive_element.remove(sub_indices)

    for ph in sub_polygon_holes_list:
        outer_indices = ph.find(TAG_P)
        if outer_indices is not None and (outer_indices.text or "").strip():
            row_data = list(map(int, outer_indices.text.split()))
            n_verts  = len(row_data) // vertex_index_stride if vertex_index_stride else 0
            rows     = [row_data[i * vertex_index_stride : (i + 1) * vertex_index_stride] for i in range(n_verts)]
            if n_verts >= 3:
                for i in range(1, n_verts - 1):
                    triangulated_flat_indices.extend(rows[0])
                    triangulated_flat_indices.extend(rows[i])
                    triangulated_flat_indices.extend(rows[i + 1])
                    new_tri_count += 1
        primitive_element.remove(ph)

    if vertex_count_element is not None:
        primitive_element.remove(vertex_count_element)

    new_indices_element      = etree.SubElement(primitive_element, TAG_P)
    new_indices_element.text = " ".join(map(str, triangulated_flat_indices))

    primitive_element.tag = TAG_TRIANGLES
    primitive_element.set(ATTR_COUNT, str(new_tri_count))
    return (old_count, new_tri_count)

def _convert_tristrips(primitive_element):
    """Convert <tristrips> to <triangles> in-place."""
    sub_indices_list = primitive_element.findall(TAG_P)
    vertex_index_stride = _get_vertex_index_stride(primitive_element)
    if not vertex_index_stride: return None
    
    triangulated_flat_indices = []
    new_tri_count = 0
    old_count = len(sub_indices_list)
    
    for sub_indices in sub_indices_list:
        row_data = list(map(int, sub_indices.text.split())) if (sub_indices.text or "").strip() else []
        n_verts  = len(row_data) // vertex_index_stride
        rows     = [row_data[i * vertex_index_stride : (i + 1) * vertex_index_stride] for i in range(n_verts)]
        
        for i in range(n_verts - 2):
            if i % 2 == 0:
                triangulated_flat_indices.extend(rows[i])
                triangulated_flat_indices.extend(rows[i+1])
                triangulated_flat_indices.extend(rows[i+2])
            else:
                triangulated_flat_indices.extend(rows[i+1])
                triangulated_flat_indices.extend(rows[i])
                triangulated_flat_indices.extend(rows[i+2])
            new_tri_count += 1
        primitive_element.remove(sub_indices)
        
    new_indices_element = etree.SubElement(primitive_element, TAG_P)
    new_indices_element.text = " ".join(map(str, triangulated_flat_indices))
    primitive_element.tag = TAG_TRIANGLES
    primitive_element.set(ATTR_COUNT, str(new_tri_count))
    return (old_count, new_tri_count)

def _convert_trifans(primitive_element):
    """Convert <trifans> to <triangles> in-place."""
    sub_indices_list = primitive_element.findall(TAG_P)
    vertex_index_stride = _get_vertex_index_stride(primitive_element)
    if not vertex_index_stride: return None
    
    triangulated_flat_indices = []
    new_tri_count = 0
    old_count = len(sub_indices_list)
    
    for sub_indices in sub_indices_list:
        row_data = list(map(int, sub_indices.text.split())) if (sub_indices.text or "").strip() else []
        n_verts  = len(row_data) // vertex_index_stride
        rows     = [row_data[i * vertex_index_stride : (i + 1) * vertex_index_stride] for i in range(n_verts)]
        
        for i in range(n_verts - 2):
            triangulated_flat_indices.extend(rows[0])
            triangulated_flat_indices.extend(rows[i+1])
            triangulated_flat_indices.extend(rows[i+2])
            new_tri_count += 1
        primitive_element.remove(sub_indices)
        
    new_indices_element = etree.SubElement(primitive_element, TAG_P)
    new_indices_element.text = " ".join(map(str, triangulated_flat_indices))
    primitive_element.tag = TAG_TRIANGLES
    primitive_element.set(ATTR_COUNT, str(new_tri_count))
    return (old_count, new_tri_count)

def _normalize_scale_unit(root):
    """
    Force normalize scale unit to 1.0 (Meters).
    Returns the old scale multiplier (float) so vertices can be adjusted.
    """
    asset = root.find("asset")
    if asset is None:
        return 1.0

    unit = asset.find("unit")
    if unit is None:
        etree.SubElement(asset, "unit", meter="1.0", name="meter")
        print("NOTE  : Added missing <unit> tag (meter='1.0')")
        return 1.0

    old_meter = unit.get("meter")
    if old_meter in ("1.0", "1"):
        return 1.0

    try:
        old_multiplier = float(old_meter)
    except (ValueError, TypeError):
        old_multiplier = 1.0

    unit.set("meter", "1.0")
    unit.set("name", "meter")
    print("NOTE  : Normalized <unit> from meter='%s' to meter='1.0'. Applying %.4f multiplier to vertices." % (old_meter, old_multiplier))
    return old_multiplier

def _strip_transparency(root):
    """
    Remove <transparent> and <transparency> tags.
    """
    count = 0
    for tag_name in ["transparent", "transparency"]:
        for elem in root.iter(tag_name):
            parent = elem.getparent()
            if parent is not None:
                parent.remove(elem)
                count += 1
    if count > 0:
        print("NOTE  : Removed %d transparency-related tags to prevent Google Earth invisibility bug." % count)

def _strip_useless_libraries(root):
    """Remove extraneous library tags that GE ignores to save file size and parsing time."""
    useless_tags = [
        "library_cameras",
        "library_lights",
        "library_animations",
        "library_controllers",
        "library_force_fields"
    ]
    count = 0
    for tag in useless_tags:
        for elem in root.iter(tag):
            parent = elem.getparent()
            if parent is not None:
                parent.remove(elem)
                count += 1
    if count > 0:
        print("NOTE  : Removed %d extraneous libraries (cameras, lights, animations) to reduce file bloat." % count)

def _normalize_shaders(root):
    """
    Downgrade <phong> and <blinn> to <lambert> to prevent physical rig shader crashes.
    Remove <index_of_refraction>.
    """
    shader_count = 0
    ior_count = 0

    for tag in ["phong", "blinn"]:
        for shader in root.iter(tag):
            shader.tag = "lambert"
            shader_count += 1
    
    for ior in root.iter("index_of_refraction"):
        parent = ior.getparent()
        if parent is not None:
            parent.remove(ior)
            ior_count += 1

    if shader_count > 0:
        print("NOTE  : Downgraded %d <phong>/<blinn> shaders to <lambert>." % shader_count)
    if ior_count > 0:
        print("NOTE  : Removed %d <index_of_refraction> tags." % ior_count)

def _apply_vertex_scale_and_offset(root, sx, sy, sz):
    """
    Calculates Auto-Base Translation (finding the lowest point and lifting the model to Z=0)
    and applies vertex coordinates scaling.
    """
    up_axis_node = root.find(".//up_axis")
    is_y_up = False
    if up_axis_node is not None and up_axis_node.text:
        is_y_up = (up_axis_node.text.strip() == "Y_UP")

    if sx == 1.0 and sy == 1.0 and sz == 1.0 and not is_y_up:
        pass # We might still need to apply translation!

    position_source_ids = set()
    for vertices in root.iter("vertices"):
        for inp in vertices.findall("input"):
            if inp.get("semantic") == "POSITION":
                src = inp.get("source", "")
                if src.startswith("#"):
                    position_source_ids.add(src[1:])
    
    # Calculate min altitude
    min_val = float('inf')
    for source in root.iter("source"):
        if source.get("id") in position_source_ids:
            float_array = source.find("float_array")
            if float_array is not None and (float_array.text or "").strip():
                parts = float_array.text.split()
                try:
                    for i in range(0, len(parts), 3):
                        val = float(parts[i+1]) if is_y_up else float(parts[i+2])
                        if val < min_val: min_val = val
                except ValueError: pass
                
    offset = 0.0
    if min_val < 0 and min_val != float('inf'):
        offset = abs(min_val)
        print("NOTE  : Auto-Base Translation applied! Model lowest point was %.3f. Shifted up by %.3f to prevent terrain culling." % (min_val, offset))

    count = 0
    for source in root.iter("source"):
        if source.get("id") in position_source_ids:
            float_array = source.find("float_array")
            if float_array is not None and (float_array.text or "").strip():
                parts = float_array.text.split()
                try:
                    floats = []
                    for i in range(0, len(parts), 3):
                        x = float(parts[i]) * sx
                        y = float(parts[i+1])
                        z = float(parts[i+2])
                        if is_y_up:
                            y = (y + offset) * sy
                            z = z * sz
                        else:
                            y = y * sy
                            z = (z + offset) * sz
                        floats.extend([x, y, z])
                    float_array.text = " ".join("{0:.6f}".format(v) for v in floats)
                    count += 1
                except ValueError: pass
    
    if count > 0:
        print("NOTE  : Applied vertex transformations to %d position arrays." % count)

def _inject_missing_materials(root):
    """Inject a default white lambert material for any geometry lacking a material binding."""
    fallback_mat_id = "LG_Fallback_Material"
    fallback_eff_id = "LG_Fallback_Effect"
    needs_fallback = False
    
    for geom in root.iter("geometry"):
        mesh = geom.find("mesh")
        if mesh is None: continue
        for prim_tag in ["triangles", "polylist", "polygons", "tristrips", "trifans"]:
            for prim in mesh.iter(prim_tag):
                if not prim.get("material"):
                    prim.set("material", fallback_mat_id)
                    needs_fallback = True
    
    for instance_geom in root.iter("instance_geometry"):
        url = instance_geom.get("url", "")
        if not url.startswith("#"): continue
        
        geom_id = url[1:]
        geom = root.find(".//geometry[@id='%s']" % geom_id)
        if geom is None: continue
        
        symbols_needed = set()
        for prim_tag in ["triangles", "polylist", "polygons", "tristrips", "trifans"]:
            for prim in geom.iter(prim_tag):
                sym = prim.get("material")
                if sym: symbols_needed.add(sym)
                
        if not symbols_needed: continue
        
        bind_material = instance_geom.find("bind_material")
        if bind_material is None:
            bind_material = etree.SubElement(instance_geom, "bind_material")
            technique_common = etree.SubElement(bind_material, "technique_common")
        else:
            technique_common = bind_material.find("technique_common")
            if technique_common is None:
                technique_common = etree.SubElement(bind_material, "technique_common")
        
        bound_symbols = set()
        for inst_mat in technique_common.findall("instance_material"):
            bound_symbols.add(inst_mat.get("symbol"))
            
        for sym in symbols_needed:
            if sym not in bound_symbols:
                etree.SubElement(technique_common, "instance_material", symbol=sym, target="#" + fallback_mat_id)
                needs_fallback = True
                
    if needs_fallback:
        _add_fallback_material(root, fallback_mat_id, fallback_eff_id)
        print("NOTE  : Injected fallback white material for un-textured/un-materialized geometry.")

def _add_fallback_material(root, mat_id, eff_id):
    lib_eff = root.find("library_effects")
    if lib_eff is None:
        lib_eff = etree.Element("library_effects")
        root.insert(0, lib_eff)
    effect = etree.SubElement(lib_eff, "effect", id=eff_id)
    profile = etree.SubElement(effect, "profile_COMMON")
    technique = etree.SubElement(profile, "technique", sid="common")
    lambert = etree.SubElement(technique, "lambert")
    emission = etree.SubElement(lambert, "emission")
    etree.SubElement(emission, "color").text = "0 0 0 1"
    diffuse = etree.SubElement(lambert, "diffuse")
    etree.SubElement(diffuse, "color").text = "0.8 0.8 0.8 1"
    
    lib_mat = root.find("library_materials")
    if lib_mat is None:
        lib_mat = etree.Element("library_materials")
        root.insert(1, lib_mat)
    mat = etree.SubElement(lib_mat, "material", id=mat_id)
    etree.SubElement(mat, "instance_effect", url="#" + eff_id)

def _normalize_up_axis(root):
    """
    If up_axis is Y_UP, convert it to Z_UP and wrap the root visual_scene nodes
    in a 90-degree X-axis rotation matrix to fix the Google Earth side-lying bug.
    """
    up_axis_node = root.find(".//up_axis")
    if up_axis_node is not None and up_axis_node.text and up_axis_node.text.strip() == "Y_UP":
        up_axis_node.text = "Z_UP"
        
        visual_scene = root.find(".//visual_scene")
        if visual_scene is not None:
            for node in list(visual_scene):
                if node.tag == "node":
                    # Wrap the node
                    node_id = node.get("id", "wrapped_node")
                    wrapper = etree.Element("node", id="%s_Y_to_Z_Rotation" % node_id)
                    matrix = etree.SubElement(wrapper, "matrix")
                    # Rotate 90 degrees around X axis:
                    matrix.text = "1 0 0 0  0 0 -1 0  0 1 0 0  0 0 0 1"
                    visual_scene.remove(node)
                    wrapper.append(node)
                    visual_scene.append(wrapper)
        print("NOTE  : Normalized <up_axis> from Y_UP to Z_UP and wrapped visual_scene in rotation matrix.")

# ---------------------------------------------------------------------------
# Main conversion
# ---------------------------------------------------------------------------

def convert_dae_file(input_path, output_path, sx=1.0, sy=1.0, sz=1.0):
    print("Parsing  : %s" % input_path)

    try:
        parser = etree.XMLParser(remove_comments=False, recover=True)
        tree   = etree.parse(input_path, parser)
    except OSError as exc:
        print("ERROR: Cannot open input file: %s" % exc)
        sys.exit(1)
    except etree.XMLSyntaxError as exc:
        print("ERROR: XML syntax error in input file: %s" % exc)
        sys.exit(1)

    root = tree.getroot()

    # Recursively strip all namespaces to handle any version cleanly
    for elem in root.getiterator():
        if not hasattr(elem.tag, 'find'): continue
        i = elem.tag.find('}')
        if i >= 0:
            elem.tag = elem.tag[i+1:]

    unit_multiplier = _normalize_scale_unit(root)
    sx *= unit_multiplier
    sy *= unit_multiplier
    sz *= unit_multiplier

    _strip_transparency(root)
    _strip_useless_libraries(root)
    _normalize_shaders(root)
    _inject_missing_materials(root)
    _apply_vertex_scale_and_offset(root, sx, sy, sz)
    _normalize_up_axis(root)

    primitives = []
    for tag in PRIMITIVE_TAGS:
        primitives.extend(root.iter(tag))

    if not primitives:
        print("NOTE  : No <polylist> or <polygons> elements found in this file.")
        print("        The file may already use only <triangles> primitives.")
        _write_tree(tree, output_path, root)
        return 0

    total_converted = 0
    total_old_faces = 0
    total_new_tris  = 0
    total_skipped   = 0

    for primitive_element in primitives:
        short_tag = primitive_element.tag
        mat       = primitive_element.get("material", "<no material>")
        geom_name = _find_geom_name(primitive_element)

        print("  <%s>  geometry='%s'  material='%s'" % (short_tag, geom_name, mat))

        if short_tag == TAG_POLYLIST:
            result = _convert_polylist(primitive_element)
        elif short_tag == TAG_POLYGONS:
            result = _convert_polygons(primitive_element)
        elif short_tag == TAG_TRISTRIPS:
            result = _convert_tristrips(primitive_element)
        elif short_tag == TAG_TRIFANS:
            result = _convert_trifans(primitive_element)
        else:
            result = None

        if result is None:
            print("    [WARN] Skipped -- could not determine face topology (malformed element).")
            total_skipped += 1
            continue

        old_faces, new_tris = result
        note = " (already all triangles -- retagged only)" if old_faces == new_tris else ""
        print("    %d faces  ->  %d triangles%s" % (old_faces, new_tris, note))

        total_old_faces += old_faces
        total_new_tris  += new_tris
        total_converted += 1

    _write_tree(tree, output_path, root)

    print("")
    print("=" * 62)
    print("  Primitives converted : %d" % total_converted)
    if total_skipped:
        print("  Primitives skipped   : %d  (malformed -- see warnings)" % total_skipped)
    print("  Total input faces    : %d" % total_old_faces)
    print("  Total output tris    : %d" % total_new_tris)
    print("  Output written to    : %s" % output_path)
    print("=" * 62)

    return total_converted


def _find_geom_name(element):
    """Walk up the element tree to find the nearest geometry id/name."""
    node = element.getparent()
    while node is not None:
        if node.tag == "geometry":
            return node.get("name") or node.get("id") or "(unnamed)"
        node = node.getparent()
    return "(unknown)"


def _write_tree(tree, output_path, root):
    """Serialise the lxml ElementTree, injecting standard 1.4.1 namespace without prefixes."""
    print("Writing  : %s" % output_path)
    try:
        import re
        xml_bytes = etree.tostring(tree, xml_declaration=True, encoding="utf-8", pretty_print=True)
        xml_str = xml_bytes.decode('utf-8')
        # Replace the entire <COLLADA> opening tag to prevent any duplicate xmlns or version attributes
        xml_str = re.sub(r'<COLLADA[^>]*>', '<COLLADA xmlns="http://www.collada.org/2005/11/COLLADASchema" version="1.4.1">', xml_str)
        with open(output_path, 'w', encoding='utf-8') as f:
            f.write(xml_str)
    except OSError as exc:
        print("ERROR: Cannot write output file: %s" % exc)
        sys.exit(1)


# ---------------------------------------------------------------------------
# CLI
# ---------------------------------------------------------------------------

def build_parser():
    p = argparse.ArgumentParser(
        description=(
            "Triangulate a COLLADA (.dae) file.\n"
            "Converts every <polylist> and <polygons> element to <triangles>\n"
            "for Google Earth Pro / Liquid Galaxy compatibility.\n\n"
            "Dependency: pip install lxml"
        ),
        formatter_class=argparse.RawDescriptionHelpFormatter,
    )
    p.add_argument("input",  help="Path to the source .dae or .zip file")
    p.add_argument("output", help="Path for the output file or directory")
    p.add_argument("--scale-x", type=float, default=1.0, help="Scale factor for X axis")
    p.add_argument("--scale-y", type=float, default=1.0, help="Scale factor for Y axis")
    p.add_argument("--scale-z", type=float, default=1.0, help="Scale factor for Z axis")
    p.add_argument("--is-zip", action="store_true", help="Input is a zip file, output is a directory to extract to.")
    return p


def process_zip_to_dir(input_zip, output_dir, sx=1.0, sy=1.0, sz=1.0):
    print("Extracting ZIP: %s to %s" % (input_zip, output_dir))
    os.makedirs(output_dir, exist_ok=True)
    with zipfile.ZipFile(input_zip, 'r') as zf:
        zf.extractall(output_dir)
        
    dae_files = glob.glob(os.path.join(output_dir, "**/*.dae"), recursive=True)
    if not dae_files:
        print("ERROR: No .dae file found inside ZIP")
        sys.exit(1)
        
    # Pick the largest DAE file as the main model
    main_dae = max(dae_files, key=os.path.getsize)
    
    # Clean up file bloat (other DAEs, OBJs, FBXs, etc.)
    unwanted_exts = {'.obj', '.fbx', '.blend', '.3ds', '.c4d', '.stl', '.gltf', '.glb'}
    for root, dirs, files in os.walk(output_dir):
        for f in files:
            file_path = os.path.join(root, f)
            ext = os.path.splitext(f)[1].lower()
            if file_path != main_dae and (ext == '.dae' or ext in unwanted_exts):
                try:
                    os.remove(file_path)
                except Exception:
                    pass
                    
    # Triangulate and sanitize the main DAE in-place
    convert_dae_file(main_dae, main_dae, sx, sy, sz)
    
    # Print the relative path so Dart can capture it
    rel_path = os.path.relpath(main_dae, output_dir)
    rel_path = rel_path.replace("\\", "/") # Ensure forward slashes for KML Link
    print("LG_DAE_PATH=%s" % rel_path)


def process_kmz(input_path, output_path, sx=1.0, sy=1.0, sz=1.0):
    print("Extracting KMZ: %s" % input_path)
    with tempfile.TemporaryDirectory() as tmpdir:
        with zipfile.ZipFile(input_path, 'r') as zf:
            zf.extractall(tmpdir)
            
        dae_files = glob.glob(os.path.join(tmpdir, "**/*.dae"), recursive=True)
        if not dae_files:
            print("ERROR: No .dae file found inside KMZ")
            sys.exit(1)
            
        for dae_path in dae_files:
            convert_dae_file(dae_path, dae_path, sx, sy, sz)
            
        print("Re-zipping into: %s" % output_path)
        with zipfile.ZipFile(output_path, 'w', zipfile.ZIP_DEFLATED) as zf:
            for root, dirs, files in os.walk(tmpdir):
                for file in files:
                    file_path = os.path.join(root, file)
                    arcname = os.path.relpath(file_path, tmpdir)
                    zf.write(file_path, arcname)

def main():
    parser = build_parser()
    args   = parser.parse_args()

    input_path  = os.path.abspath(args.input)
    output_path = os.path.abspath(args.output)

    if not os.path.isfile(input_path):
        print("ERROR: Input file not found: %s" % input_path)
        sys.exit(1)

    if input_path == output_path:
        print("ERROR: Input and output paths must be different "
              "(use a different filename or directory).")
        sys.exit(1)

    if not args.is_zip:
        out_dir = os.path.dirname(output_path)
        if out_dir:
            os.makedirs(out_dir, exist_ok=True)

    if args.is_zip:
        process_zip_to_dir(input_path, output_path, args.scale_x, args.scale_y, args.scale_z)
    elif input_path.lower().endswith('.kmz'):
        process_kmz(input_path, output_path, args.scale_x, args.scale_y, args.scale_z)
    else:
        convert_dae_file(input_path, output_path, args.scale_x, args.scale_y, args.scale_z)


if __name__ == "__main__":
    main()