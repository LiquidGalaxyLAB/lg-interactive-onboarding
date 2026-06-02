#!/usr/bin/env python3
"""
dae_triangulate.py
==================
Convert all <polylist> and <polygons> primitives in a COLLADA (.dae) file
to <triangles>, making the model fully compatible with Google Earth Pro
and Liquid Galaxy (which only support the <triangles> primitive type).

Strategy
--------
Pure XML manipulation via lxml — no pycollada object model involved.
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
    pip install lxml          # that is all — no pycollada needed

Cross-platform: works on Windows, Linux, macOS with Python 3.8+.
"""

import sys
import os
import argparse
from lxml import etree

# ---------------------------------------------------------------------------
# COLLADA XML namespace
# ---------------------------------------------------------------------------
COLLADA_NS     = "http://www.collada.org/2005/11/COLLADASchema"
PRIMITIVE_TAGS = {
    f"{{{COLLADA_NS}}}polylist",
    f"{{{COLLADA_NS}}}polygons",
}


# ---------------------------------------------------------------------------
# Core helpers
# ---------------------------------------------------------------------------

def _n_inputs(prim_el: etree._Element) -> int:
    """
    Return the interleave stride: (max offset across all <input> children) + 1.
    A primitive with no <input> elements defaults to stride 1.
    """
    inputs = prim_el.findall(f"{{{COLLADA_NS}}}input")
    if not inputs:
        return 1
    return max(int(inp.get("offset", "0")) for inp in inputs) + 1


def _fan_triangulate(vcounts: list, pdata: list, n_inputs: int):
    """
    Fan-triangulate an interleaved index array.

    Parameters
    ----------
    vcounts   : list[int]  -- vertex count per face
    pdata     : list[int]  -- flat interleaved index array
    n_inputs  : int        -- number of index slots per vertex (stride)

    Returns
    -------
    (new_pdata: list[int], new_tri_count: int)
    """
    out = []
    tri_count = 0
    pos = 0

    for n_verts in vcounts:
        # Gather one row (n_inputs wide) per vertex of this face
        rows = []
        for _ in range(n_verts):
            rows.append(pdata[pos : pos + n_inputs])
            pos += n_inputs

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

def _convert_polylist(el: etree._Element):
    """
    Convert a <polylist> element to <triangles> in-place.

    Returns (old_face_count, new_tri_count), or None if malformed.
    """
    vcount_el = el.find(f"{{{COLLADA_NS}}}vcount")
    p_el      = el.find(f"{{{COLLADA_NS}}}p")

    # Empty primitive
    if p_el is None:
        el.tag = f"{{{COLLADA_NS}}}triangles"
        if vcount_el is not None:
            el.remove(vcount_el)
        el.set("count", "0")
        return (0, 0)

    pdata   = list(map(int, p_el.text.split())) if (p_el.text or "").strip() else []
    vcounts = (
        list(map(int, vcount_el.text.split()))
        if (vcount_el is not None and (vcount_el.text or "").strip())
        else []
    )
    old_count = len(vcounts)
    n_inp     = _n_inputs(el)

    # If <vcount> is missing but <p> data exists, infer all-triangle faces
    if not vcounts and pdata:
        face_size = 3 * n_inp
        if n_inp > 0 and len(pdata) % face_size == 0:
            old_count = len(pdata) // face_size
            vcounts   = [3] * old_count
        else:
            # Cannot safely deduce face topology -- leave untouched
            return None

    # Already all triangles -- just retag and clean up
    if all(v == 3 for v in vcounts):
        if vcount_el is not None:
            el.remove(vcount_el)
        el.tag = f"{{{COLLADA_NS}}}triangles"
        el.set("count", str(old_count))
        return (old_count, old_count)

    # General case: fan-triangulate
    new_pdata, new_tri_count = _fan_triangulate(vcounts, pdata, n_inp)
    p_el.text = " ".join(map(str, new_pdata))
    if vcount_el is not None:
        el.remove(vcount_el)

    el.tag = f"{{{COLLADA_NS}}}triangles"
    el.set("count", str(new_tri_count))
    return (old_count, new_tri_count)


def _convert_polygons(el: etree._Element):
    """
    Convert a <polygons> element to <triangles> in-place.

    <polygons> may contain:
      - Multiple per-face <p> children (one polygon each), OR
      - A single flat <p> + <vcount> (polylist-style variant used by some exporters)
      - <ph> (polygon with holes) -- holes are dropped, outer contour is kept

    Returns (old_face_count, new_tri_count).
    """
    vcount_el   = el.find(f"{{{COLLADA_NS}}}vcount")
    sub_p_list  = el.findall(f"{{{COLLADA_NS}}}p")
    sub_ph_list = el.findall(f"{{{COLLADA_NS}}}ph")

    if sub_ph_list:
        print(f"    [WARN] {len(sub_ph_list)} <ph> (polygon-with-holes) element(s) found. "
              "Holes are not representable in <triangles> and will be dropped; "
              "only the outer contour is triangulated.")

    # Polylist-style variant: single <p> + <vcount>
    if vcount_el is not None and len(sub_p_list) == 1 and not sub_ph_list:
        return _convert_polylist(el)

    old_count = len(sub_p_list) + len(sub_ph_list)
    n_inp     = _n_inputs(el)
    new_flat  = []
    new_tri_count = 0

    # Process per-face <p> elements
    for sp in sub_p_list:
        row_data = list(map(int, sp.text.split())) if (sp.text or "").strip() else []
        n_verts  = len(row_data) // n_inp if n_inp else 0
        rows     = [row_data[i * n_inp : (i + 1) * n_inp] for i in range(n_verts)]
        if n_verts >= 3:
            if n_verts == 3:
                new_flat.extend(row_data)
                new_tri_count += 1
            else:
                for i in range(1, n_verts - 1):
                    new_flat.extend(rows[0])
                    new_flat.extend(rows[i])
                    new_flat.extend(rows[i + 1])
                    new_tri_count += 1
        el.remove(sp)

    # Process <ph> (outer contour of polygon-with-holes; drop inner <h> rings)
    for ph in sub_ph_list:
        outer_p = ph.find(f"{{{COLLADA_NS}}}p")
        if outer_p is not None and (outer_p.text or "").strip():
            row_data = list(map(int, outer_p.text.split()))
            n_verts  = len(row_data) // n_inp if n_inp else 0
            rows     = [row_data[i * n_inp : (i + 1) * n_inp] for i in range(n_verts)]
            if n_verts >= 3:
                for i in range(1, n_verts - 1):
                    new_flat.extend(rows[0])
                    new_flat.extend(rows[i])
                    new_flat.extend(rows[i + 1])
                    new_tri_count += 1
        el.remove(ph)

    # Remove <vcount> if present
    if vcount_el is not None:
        el.remove(vcount_el)

    # Add single merged flat <p>
    p_new      = etree.SubElement(el, f"{{{COLLADA_NS}}}p")
    p_new.text = " ".join(map(str, new_flat))

    el.tag = f"{{{COLLADA_NS}}}triangles"
    el.set("count", str(new_tri_count))
    return (old_count, new_tri_count)


# ---------------------------------------------------------------------------
# Main conversion
# ---------------------------------------------------------------------------

def convert_dae(input_path: str, output_path: str) -> int:
    """
    Parse input_path, triangulate all polylist/polygons primitives,
    write result to output_path.

    Returns the number of primitive elements converted.
    """
    print(f"Parsing  : {input_path}")

    try:
        parser = etree.XMLParser(remove_comments=False, recover=True)
        tree   = etree.parse(input_path, parser)
    except OSError as exc:
        print(f"ERROR: Cannot open input file: {exc}")
        sys.exit(1)
    except etree.XMLSyntaxError as exc:
        print(f"ERROR: XML syntax error in input file: {exc}")
        sys.exit(1)

    root = tree.getroot()

    # Collect ALL polylist / polygons elements anywhere in the document
    primitives = []
    for tag in PRIMITIVE_TAGS:
        primitives.extend(root.iter(tag))

    if not primitives:
        print("NOTE  : No <polylist> or <polygons> elements found in this file.")
        print("        The file may already use only <triangles> primitives.")
        _write_tree(tree, output_path)
        return 0

    total_converted  = 0
    total_old_faces  = 0
    total_new_tris   = 0
    total_skipped    = 0

    for prim_el in primitives:
        short_tag = prim_el.tag.split("}")[-1]      # "polylist" or "polygons"
        mat       = prim_el.get("material", "<no material>")

        # Walk up to find the geometry name for diagnostic output
        geom_name = _find_geom_name(prim_el)

        print(f"  <{short_tag}>  geometry='{geom_name}'  material='{mat}'")

        if short_tag == "polylist":
            result = _convert_polylist(prim_el)
        else:
            result = _convert_polygons(prim_el)

        if result is None:
            print("    [WARN] Skipped — could not determine face topology (malformed element).")
            total_skipped += 1
            continue

        old_faces, new_tris = result
        note = " (already all triangles — retagged only)" if old_faces == new_tris else ""
        print(f"    {old_faces} faces  ->  {new_tris} triangles{note}")

        total_old_faces += old_faces
        total_new_tris  += new_tris
        total_converted += 1

    _write_tree(tree, output_path)

    print()
    print("=" * 62)
    print(f"  Primitives converted : {total_converted}")
    if total_skipped:
        print(f"  Primitives skipped   : {total_skipped}  (malformed — see warnings)")
    print(f"  Total input faces    : {total_old_faces}")
    print(f"  Total output tris    : {total_new_tris}")
    print(f"  Output written to    : {output_path}")
    print("=" * 62)

    return total_converted


def _find_geom_name(el: etree._Element) -> str:
    """Walk up the element tree to find the nearest geometry id/name."""
    node = el.getparent()
    while node is not None:
        tag = node.tag.split("}")[-1] if "}" in node.tag else node.tag
        if tag == "geometry":
            return node.get("name") or node.get("id") or "(unnamed)"
        node = node.getparent()
    return "(unknown)"


def _write_tree(tree: etree._ElementTree, output_path: str) -> None:
    """Serialise the lxml ElementTree, preserving the XML declaration."""
    print(f"Writing  : {output_path}")
    try:
        tree.write(
            output_path,
            xml_declaration=True,
            encoding="utf-8",
            pretty_print=True,
        )
    except OSError as exc:
        print(f"ERROR: Cannot write output file: {exc}")
        sys.exit(1)


# ---------------------------------------------------------------------------
# CLI
# ---------------------------------------------------------------------------

def build_parser() -> argparse.ArgumentParser:
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


def main() -> None:
    parser = build_parser()
    args   = parser.parse_args()

    input_path  = os.path.abspath(args.input)
    output_path = os.path.abspath(args.output)

    if not os.path.isfile(input_path):
        print(f"ERROR: Input file not found: {input_path}")
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