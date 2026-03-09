# Map Rendering with libgd-gis

Geodetic coordinates and areas can be rendered on raster maps using the [libgd-gis](https://rubygems.org/gems/libgd-gis) gem, which provides tile-based basemap rendering on top of [ruby-libgd](https://rubygems.org/gems/ruby-libgd).

## Overview

The `libgd-gis` gem downloads map tiles and stitches them into a single raster image for a given bounding box and zoom level. Geodetic's coordinate objects provide the geographic data, and `GD::GIS::Geometry.project` converts longitude/latitude pairs into pixel positions on the rendered map. From there, ruby-libgd primitives (lines, circles, polygons, text, image compositing) can draw overlays on top of the basemap.

This combination supports:

- **Point markers** for any Geodetic coordinate
- **Polygon overlays** from `Geodetic::Areas::Polygon` boundaries
- **Bearing arrows** computed with `Feature#bearing_to` and drawn as lines with arrowheads
- **Distance labels** using `Feature#distance_to` for annotation
- **Icon compositing** with scaled PNG images positioned at projected coordinates
- **Light and dark basemaps** via `:carto_light` and `:carto_dark`

## Feature Class

`Geodetic::Feature` wraps a geometry (any coordinate or area) with a label and a metadata hash. It delegates `distance_to` and `bearing_to` to its geometry, using the centroid for area geometries. This makes it straightforward to attach display properties like icon paths and categories alongside the spatial data.

## Prerequisites

```bash
gem install libgd-gis
brew install gd   # macOS
# apt install libgd-dev   # Linux
```

## Example

See [`examples/05_map_rendering/demo.rb`](https://github.com/madbomber/geodetic/tree/main/examples/05_map_rendering) for a complete working demo that renders NYC landmarks with icons, a Central Park polygon boundary, and bearing arrows between landmarks. The demo supports light/dark themes, icon scaling, and CLI flags for toggling features.
