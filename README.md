# KML + COLLADA Utilities

This folder contains small utilities and sample KML/DAE assets for placing 3D models in Google Earth.

## Contents
- [triangulation.py](triangulation.py): Converts COLLADA `<polylist>` meshes to `<triangles>` for Google Earth compatibility.
- [3dmodel.kml](3dmodel.kml) : Sample KML files that reference a `.dae` model and define placement, orientation, and scale.
- [dae_files/model.dae](dae_files/model.dae): Example COLLADA model used by the KML references.
- [3dmodel_pyr.kmz](3dmodel_pyr.kmz) and [3dmodel.kml](3dmodel.kml): Sample KML/KMZ artifacts.
- [model_opaq_red.kmz](model_opaq_red.kmz), [model_opaq_white.kmz](model_opaq_white.kmz), [model_transperant_red.kmz](model_transperant_red.kmz): Example variants for appearance testing.

## Usage
Triangulate a DAE file for Google Earth:

```bash
python triangulation.py input.dae output.dae