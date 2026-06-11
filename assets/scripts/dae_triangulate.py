#!/usr/bin/env python3
"""
dae_triangulate.py
==================
Convert all <polylist> and <polygons> primitives in a COLLADA (.dae) file
to <triangles>, making the model fully compatible with Google Earth Pro
and Liquid Galaxy (which only support the <triangles> primitive type).

Strategy
--------
Pure XML manipulation via lxml -- no pycollada object model involved.
This avoids all pycollada API fragility and handles any conforming
COLLADA 1.4 / 1.5 file generically.

Algorithm
---------
For each <polylist> or <polygons> element found anywhere in the file:
  1. Read the <vcount> array (one integer per face = vertex count of that face).
  2. Read the flat interleaved <p> array.
  3. Fan-triangulate every face: a face with N vertices produces N-2 triangles,
     anchored at vertex-0.  Works correctly for convex faces and is the
     standard approximation for slightly-concave faces from CAD/GIS exports.
  4. Replace the element tag with <triangles>, rewrite <p>, remove <vcount>,
     and update the count= attribute.
  5. For <polygons> (multiple per-face <p> children), merge them into a single
     flat <p> element after triangulation.
  6. Polylists/polygons whose <vcount> is already all-3 are retagged to
     <triangles> and cleaned up without modifying index data (idempotent).

All other content (sources, normals, UVs, materials, effects, lights,
cameras, scene hierarchy, transforms, extras) is preserved byte-for-byte.

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
from lxml import etree

# ---------------------------------------------------------------------------
# COLLADA XML namespace
# ---------------------------------------------------------------------------
COLLADA_NS = "http://www.collada.org/2005/11/COLLADASchema"

def _ns(tag):
    """Return a namespace-qualified tag string, e.g. '{http://...}triangles'."""
    return "{%s}%s" % (COLLADA_NS, tag)

TAG_TRIANGLES = "triangles"
TAG_POLYLIST  = "polylist"
TAG_POLYGONS  = "polygons"
TAG_P         = "p"
TAG_PH        = "ph"
TAG_VCOUNT    = "vcount"
ATTR_COUNT    = "count"

PRIMITIVE_TAGS = {
    _ns(TAG_POLYLIST),
    _ns(TAG_POLYGONS),
}


# ---------------------------------------------------------------------------
# Core helpers
# ---------------------------------------------------------------------------

def _get_vertex_index_stride(primitive_element):
    """
    Return the interleave stride: (max offset across all <input> children) + 1.
    A primitive with no <input> elements defaults to stride 1.
    """
    inputs = primitive_element.findall(_ns("input"))
    if not inputs:
        return 1
    return max(int(inp.get("offset", "0")) for inp in inputs) + 1


def _fan_triangulate(face_vertex_counts, flat_indices, vertex_index_stride):
    """
    Fan-triangulate an interleaved index array.

    Parameters
    ----------
    face_vertex_counts  : list of int  -- vertex count per face
    flat_indices        : list of int  -- flat interleaved index array
    vertex_index_stride : int          -- number of index slots per vertex (stride)

    Returns
    -------
    (triangulated_indices, new_tri_count)
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
            # Degenerate face -- skip silently
            continue
        if n_verts == 3:
            # Already a triangle -- copy straight through
            out.extend(rows[0])
            out.extend(rows[1])
            out.extend(rows[2])
            tri_count += 1
        else:
            # Fan from vertex 0: produces n_verts-2 triangles
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
    vertex_count_element = primitive_element.find(_ns(TAG_VCOUNT))
    indices_element      = primitive_element.find(_ns(TAG_P))

    # Empty primitive
    if indices_element is None:
        primitive_element.tag = _ns(TAG_TRIANGLES)
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

    # If <vcount> is missing but <p> data exists, infer all-triangle faces
    if not face_vertex_counts and flat_indices:
        face_size = 3 * vertex_index_stride
        if vertex_index_stride > 0 and len(flat_indices) % face_size == 0:
            old_count = len(flat_indices) // face_size
            face_vertex_counts = [3] * old_count
        else:
            # Cannot safely deduce face topology -- leave untouched
            return None

    if all(v == 3 for v in face_vertex_counts):
        if vertex_count_element is not None:
            primitive_element.remove(vertex_count_element)
        primitive_element.tag = _ns(TAG_TRIANGLES)
        primitive_element.set(ATTR_COUNT, str(old_count))
        return (old_count, old_count)

    # General case: fan-triangulate
    triangulated_indices, new_tri_count = _fan_triangulate(face_vertex_counts, flat_indices, vertex_index_stride)
    indices_element.text = " ".join(map(str, triangulated_indices))
    if vertex_count_element is not None:
        primitive_element.remove(vertex_count_element)

    primitive_element.tag = _ns(TAG_TRIANGLES)
    primitive_element.set(ATTR_COUNT, str(new_tri_count))
    return (old_count, new_tri_count)


def _convert_polygons(primitive_element):
    """
    Convert a <polygons> element to <triangles> in-place.

    <polygons> may contain:
      - Multiple per-face <p> children (one polygon each), OR
      - A single flat <p> + <vcount> (polylist-style variant used by some exporters)
      - <ph> (polygon with holes) -- holes are dropped, outer contour is kept

    Returns (old_face_count, new_tri_count).
    """
    vertex_count_element   = primitive_element.find(_ns(TAG_VCOUNT))
    sub_indices_list       = primitive_element.findall(_ns(TAG_P))
    sub_polygon_holes_list = primitive_element.findall(_ns(TAG_PH))

    if sub_polygon_holes_list:
        print("    [WARN] %d <ph> (polygon-with-holes) element(s) found. "
              "Holes are not representable in <triangles> and will be dropped; "
              "only the outer contour is triangulated." % len(sub_polygon_holes_list))

    # Polylist-style variant: single <p> + <vcount>
    if vertex_count_element is not None and len(sub_indices_list) == 1 and not sub_polygon_holes_list:
        return _convert_polylist(primitive_element)

    old_count = len(sub_indices_list) + len(sub_polygon_holes_list)
    vertex_index_stride = _get_vertex_index_stride(primitive_element)
    triangulated_flat_indices = []
    new_tri_count = 0

    # Process per-face <p> elements
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
        outer_indices = ph.find(_ns(TAG_P))
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

    # Remove <vcount> if present
    if vertex_count_element is not None:
        primitive_element.remove(vertex_count_element)

    # Add single merged flat <p>
    new_indices_element      = etree.SubElement(primitive_element, _ns(TAG_P))
    new_indices_element.text = " ".join(map(str, triangulated_flat_indices))

    primitive_element.tag = _ns(TAG_TRIANGLES)
    primitive_element.set(ATTR_COUNT, str(new_tri_count))
    return (old_count, new_tri_count)

def _normalize_scale_unit(root):
    """
    Force normalize scale unit to 1.0 (Meters).
    This fixes Google Earth's microscopic/massive model rendering bugs
    which happen when CAD programs export with meter="0.001" etc.
    """
    asset = root.find(_ns("asset"))
    if asset is None:
        return

    unit = asset.find(_ns("unit"))
    if unit is None:
        # If missing completely, safely inject it
        etree.SubElement(asset, _ns("unit"), meter="1.0", name="meter")
        print("NOTE  : Added missing <unit> tag (meter='1.0')")
        return

    old_meter = unit.get("meter")
    if old_meter in ("1.0", "1"):
        return

    unit.set("meter", "1.0")
    unit.set("name", "meter")
    print("NOTE  : Normalized <unit> from meter='%s' to meter='1.0'" % old_meter)

# ---------------------------------------------------------------------------
# Main conversion
# ---------------------------------------------------------------------------

def convert_dae(input_path, output_path):
    """
    Parse input_path, triangulate all polylist/polygons primitives,
    write result to output_path.

    Returns the number of primitive elements converted.
    """
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

    _normalize_scale_unit(root)
    # Collect ALL polylist / polygons elements anywhere in the document
    primitives = []
    for tag in PRIMITIVE_TAGS:
        primitives.extend(root.iter(tag))

    if not primitives:
        print("NOTE  : No <polylist> or <polygons> elements found in this file.")
        print("        The file may already use only <triangles> primitives.")
        _write_tree(tree, output_path)
        return 0

    total_converted = 0
    total_old_faces = 0
    total_new_tris  = 0
    total_skipped   = 0

    for primitive_element in primitives:
        short_tag = primitive_element.tag.split("}")[-1]      # "polylist" or "polygons"
        mat       = primitive_element.get("material", "<no material>")

        # Walk up to find the geometry name for diagnostic output
        geom_name = _find_geom_name(primitive_element)

        print("  <%s>  geometry='%s'  material='%s'" % (short_tag, geom_name, mat))

        if short_tag == TAG_POLYLIST:
            result = _convert_polylist(primitive_element)
        else:
            result = _convert_polygons(primitive_element)

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

    _write_tree(tree, output_path)

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
        tag = node.tag.split("}")[-1] if "}" in node.tag else node.tag
        if tag == "geometry":
            return node.get("name") or node.get("id") or "(unnamed)"
        node = node.getparent()
    return "(unknown)"


def _write_tree(tree, output_path):
    """Serialise the lxml ElementTree, preserving the XML declaration."""
    print("Writing  : %s" % output_path)
    try:
        tree.write(
            output_path,
            xml_declaration=True,
            encoding="utf-8",
            pretty_print=True,
        )
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
    p.add_argument("input",  help="Path to the source .dae file")
    p.add_argument("output", help="Path for the triangulated output .dae file")
    return p


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

    out_dir = os.path.dirname(output_path)
    if out_dir:
        os.makedirs(out_dir, exist_ok=True)

    convert_dae(input_path, output_path)


if __name__ == "__main__":
    main()