# Map Rendering

Geodetic provides a map adapter pattern (`Geodetic::Map`) for rendering coordinates, paths, areas, and features on maps. The adapter abstracts the rendering backend so the same Geodetic objects work with different map engines.

## Architecture

```
Geodetic::Map::Base          # Abstract adapter interface
├── Geodetic::Map::LibGdGis  # Raster PNG output via libgd-gis
├── (future) Leaflet         # Interactive HTML/JS maps
├── (future) GoogleMaps      # Google Maps HTML or Static API
└── (future) KML             # KML XML output
```

`MapMethods` is a mixin applied to all coordinates, areas, paths, segments, and features, providing `add_to_map(map, **style)`.

## Usage

### Adding objects to a map

Two equivalent APIs — use whichever reads better:

```ruby
# Map-centric
map = Geodetic::Map::LibGdGis.new(bbox: bbox, zoom: 12, basemap: :carto_dark)
map.add(polygon, fill: [0, 200, 120, 170], stroke: [0, 200, 120, 30], width: 2)
map.add(path, color: [255, 220, 50], width: 3)
map.add(coordinate, color: [255, 0, 0], label: "Marker")

# Object-centric (via MapMethods mixin)
polygon.add_to_map(map, fill: [0, 200, 120, 170])
path.add_to_map(map, color: [255, 220, 50], width: 3)
coordinate.add_to_map(map, color: [255, 0, 0], label: "Marker")
```

The `add` method auto-detects the object type and dispatches to the appropriate handler. Supported types:

| Object | Layer type | Notes |
|--------|-----------|-------|
| Any coordinate (18 systems) | `:point` | Converts to LLA automatically |
| `Path` | `:line` | Renders all waypoints as a line |
| `Segment` | `:line` | Two-point line |
| `Polygon` (and subclasses) | `:polygon` | Includes Triangle, Rectangle, Hexagon, etc. |
| `Circle` | `:polygon` | Approximated as N-gon (default 32 segments) |
| `BoundingBox` | `:polygon` | Four corners as a rectangle |
| `Feature` | delegates | Extracts geometry; merges label into style |
| `ENU` / `NED` | rejected | Raises `ArgumentError` (relative systems) |

### Rendering

```ruby
# Simple render to file
map.render("output.png")

# Render with custom drawing block (LibGdGis-specific)
map.render("output.png") do |gd_map|
  img = gd_map.image
  # Use GD::Image primitives for custom markers, labels, arrows, etc.
end

# Render without saving (returns GD::GIS::Map)
gd_map = map.render
```

### Bounding box

The LibGdGis adapter accepts bounding boxes as either:

```ruby
# Geodetic BoundingBox object
bbox = Geodetic::Areas::BoundingBox.new(nw: nw_point, se: se_point)
map = Geodetic::Map::LibGdGis.new(bbox: bbox, zoom: 12)

# Raw [west, south, east, north] array
map = Geodetic::Map::LibGdGis.new(bbox: [-74.05, 40.65, -73.75, 40.82], zoom: 12)
```

## LibGdGis Adapter

### Color format

Colors are `[r, g, b]` or `[r, g, b, alpha]` arrays. The alpha channel follows libgd convention:

- `0` = fully opaque
- `255` = fully transparent

### Style options

| Option | Point | Line | Polygon |
|--------|:-----:|:----:|:-------:|
| `color` | marker color | stroke color | — |
| `stroke` | — | stroke color | outline color |
| `fill` | — | — | fill color |
| `width` | — | line width (px) | outline width (px) |
| `label` | text label | — | — |
| `icon` | image path | — | — |
| `font` | font path | — | — |
| `size` | font size | — | — |
| `font_color` | label color | — | — |
| `symbol` | marker style | — | — |
| `segments` | — | — | circle approximation (default 32) |

### Prerequisites

```bash
gem install libgd-gis
brew install gd   # macOS
# apt install libgd-dev   # Linux
```

## Feature Class

`Geodetic::Feature` wraps a geometry (any coordinate or area) with a label and a metadata hash. It delegates `distance_to` and `bearing_to` to its geometry, using the centroid for area geometries. When added to a map, the label is automatically included in the style.

## Examples

- [`examples/05_map_rendering/demo.rb`](https://github.com/madbomber/geodetic/tree/main/examples/05_map_rendering) — NYC landmarks with icons, Central Park polygon, bearing arrows, light/dark themes
- [`examples/14_geos_map_rendering.rb`](https://github.com/madbomber/geodetic/tree/main/examples/14_geos_map_rendering.rb) — GEOS operations (intersection, difference, buffer, convex hull, simplification, nearest points, prepared geometry) all visualized on a single map with distinct colors
