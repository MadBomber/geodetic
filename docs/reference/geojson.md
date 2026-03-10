# GeoJSON Export Reference

`Geodetic::GeoJSON` builds a [GeoJSON](https://datatracker.ietf.org/doc/html/rfc7946) FeatureCollection from any combination of Geodetic objects. It provides an accumulator pattern for collecting geometry, then exporting as a Hash, JSON string, or file.

Every geometry type also gains a `to_geojson` instance method that returns a GeoJSON-compatible Ruby Hash.

---

## GeoJSON Class

### Constructor

```ruby
gj = Geodetic::GeoJSON.new                       # empty collection
gj = Geodetic::GeoJSON.new(seattle, portland)     # initialize with objects
gj = Geodetic::GeoJSON.new([seattle, portland])   # also accepts an array
```

### Accumulating Objects

Use `<<` to add a single object or an array of objects. Returns `self` for chaining.

```ruby
gj = Geodetic::GeoJSON.new

gj << seattle                          # single coordinate
gj << [portland, sf, la]               # array of coordinates
gj << Geodetic::Segment.new(a, b)     # segment
gj << route                           # path
gj << polygon                         # area
gj << circle                          # circle (approximated)
gj << bbox                            # bounding box
gj << feature                         # feature (preserves properties)
```

Any Geodetic object with a `to_geojson` method can be added. Non-Feature objects are auto-wrapped as GeoJSON Features with empty `properties`. Feature objects carry their `label` and `metadata` into the GeoJSON output.

### Query

| Method   | Returns | Description |
|----------|---------|-------------|
| `size`   | Integer | Number of collected objects |
| `length` | Integer | Alias for `size` |
| `empty?` | Boolean | True if no objects collected |
| `each`   | Enumerator | Iterate over collected objects |

`GeoJSON` includes `Enumerable`, so `map`, `select`, `reject`, `count`, `to_a`, and all other Enumerable methods are available.

```ruby
gj.size                      # => 5
gj.empty?                    # => false
gj.map { |obj| obj.class }  # => [LLA, LLA, Path, ...]
```

### Removing Objects

| Method        | Description |
|---------------|-------------|
| `delete(obj)` | Remove a specific object from the collection |
| `clear`       | Remove all objects |

Both return `self` for chaining.

```ruby
gj.delete(portland)
gj.clear
```

### Export

| Method                     | Returns | Description |
|----------------------------|---------|-------------|
| `to_h`                     | Hash    | GeoJSON FeatureCollection as a Ruby Hash |
| `to_json`                  | String  | Compact JSON string |
| `to_json(pretty: true)`    | String  | Pretty-printed JSON string |
| `save(path)`               | nil     | Write compact JSON to file |
| `save(path, pretty: true)` | nil     | Write pretty-printed JSON to file |

```ruby
gj.to_h
# => {"type" => "FeatureCollection", "features" => [...]}

gj.to_json
# => '{"type":"FeatureCollection","features":[...]}'

gj.to_json(pretty: true)
# => formatted JSON with indentation

gj.save("my_map.geojson")
gj.save("my_map.geojson", pretty: true)
```

The `to_json` and `save` methods use Ruby's built-in `json` library (a default gem, always available). No external dependencies are required.

### Display

```ruby
gj.to_s     # => "GeoJSON::FeatureCollection(5 features)"
gj.inspect  # => "#<Geodetic::GeoJSON size=5>"
```

### Import

| Method | Returns | Description |
|--------|---------|-------------|
| `GeoJSON.load(path)` | Array | Read a GeoJSON file and return an Array of Geodetic objects |
| `GeoJSON.parse(hash)` | Array | Parse a GeoJSON Hash and return an Array of Geodetic objects |

```ruby
objects = Geodetic::GeoJSON.load("west_coast.geojson")
# => [Feature("Seattle", LLA), Feature("Portland", LLA), Segment, Polygon, ...]
```

`parse` accepts a Ruby Hash (useful when you already have parsed JSON):

```ruby
data = JSON.parse(File.read("west_coast.geojson"))
objects = Geodetic::GeoJSON.parse(data)
```

**GeoJSON → Geodetic type mapping:**

| GeoJSON type | Geodetic type |
|--------------|---------------|
| Point | `Coordinate::LLA` |
| LineString (2 points) | `Segment` |
| LineString (3+ points) | `Path` |
| Polygon | `Areas::Polygon` (outer ring only; holes are dropped) |
| MultiPoint | Multiple `Coordinate::LLA` |
| MultiLineString | Multiple `Segment` or `Path` |
| MultiPolygon | Multiple `Areas::Polygon` |
| GeometryCollection | Flattened into individual geometries |

**Feature handling:**

- A GeoJSON Feature with a `"name"` property or any non-empty properties becomes a `Geodetic::Feature`. The `"name"` property maps to `label`, and remaining properties become `metadata` with symbol keys.
- A GeoJSON Feature with empty properties (`{}`) returns the raw geometry with no Feature wrapper.

This means a save/load roundtrip preserves Feature labels, metadata, and geometry types:

```ruby
# Save
gj = Geodetic::GeoJSON.new
gj << Geodetic::Feature.new(label: "Seattle", geometry: seattle, metadata: { state: "WA" })
gj << portland  # raw coordinate, no Feature
gj.save("cities.geojson")

# Load
objects = Geodetic::GeoJSON.load("cities.geojson")
objects[0]          # => Feature (label: "Seattle", metadata: {state: "WA"})
objects[0].label    # => "Seattle"
objects[0].metadata # => {state: "WA"}
objects[1]          # => LLA (raw coordinate, no Feature wrapper)
```

---

## Geometry Mapping

Each Geodetic geometry type maps to a specific GeoJSON geometry type:

| Geodetic Type | GeoJSON Type | Notes |
|---------------|-------------|-------|
| Any coordinate (LLA, UTM, ECEF, ...) | Point | Converts through LLA |
| `Segment` | LineString | 2 positions |
| `Path` | LineString | N positions (default) |
| `Path` (with `as: :polygon`) | Polygon | Auto-closes the ring |
| `Areas::Polygon` (and subclasses) | Polygon | Boundary ring already closed |
| `Areas::Circle` | Polygon | Approximated as N-gon (default 32) |
| `Areas::BoundingBox` | Polygon | 4 corners, closed |
| `Feature` | Feature | Geometry + properties |

---

## Individual `to_geojson` Methods

### Coordinates

All 18 coordinate classes gain a `to_geojson` method. It converts the coordinate to LLA and returns a GeoJSON Point.

```ruby
seattle = Geodetic::Coordinate::LLA.new(lat: 47.6205, lng: -122.3493, alt: 0.0)
seattle.to_geojson
# => {"type" => "Point", "coordinates" => [-122.3493, 47.6205]}
```

**Altitude handling:** The GeoJSON position array is `[lng, lat]` when altitude is zero, and `[lng, lat, alt]` when altitude is non-zero.

```ruby
Geodetic::Coordinate::LLA.new(lat: 47.62, lng: -122.35, alt: 184.0).to_geojson
# => {"type" => "Point", "coordinates" => [-122.35, 47.62, 184.0]}
```

**Cross-system:** Any coordinate type works — UTM, ECEF, MGRS, GH, etc. are converted to LLA internally.

```ruby
seattle.to_utm.to_geojson       # => {"type" => "Point", ...}
seattle.to_mgrs.to_geojson      # => {"type" => "Point", ...}
```

**ENU and NED:** These are relative coordinate systems with no absolute position. Calling `to_geojson` raises `ArgumentError` with a message explaining that conversion to an absolute system is required first.

```ruby
enu = Geodetic::Coordinate::ENU.new(e: 100, n: 200, u: 10)
enu.to_geojson  # => ArgumentError
```

---

### Segment

Returns a GeoJSON LineString with two positions.

```ruby
seg = Geodetic::Segment.new(seattle, portland)
seg.to_geojson
# => {"type" => "LineString", "coordinates" => [[-122.3493, 47.6205], [-122.6784, 45.5152]]}
```

---

### Path

Returns a GeoJSON LineString by default. Requires at least 2 coordinates.

```ruby
route = Geodetic::Path.new(coordinates: [seattle, portland, sf])
route.to_geojson
# => {"type" => "LineString", "coordinates" => [[...], [...], [...]]}
```

**As polygon:** Pass `as: :polygon` to export as a closed GeoJSON Polygon. Requires at least 3 coordinates. The ring is auto-closed if the first and last coordinates differ.

```ruby
route.to_geojson(as: :polygon)
# => {"type" => "Polygon", "coordinates" => [[[...], [...], [...], [...]]]}
```

**Edge cases:**

| Condition | Behavior |
|-----------|----------|
| Empty path | Raises `ArgumentError` |
| 1 coordinate (line_string) | Raises `ArgumentError` |
| 2 coordinates (polygon) | Raises `ArgumentError` |

---

### Areas::Polygon

Returns a GeoJSON Polygon. The boundary ring is already closed by `Polygon#initialize`.

```ruby
poly = Geodetic::Areas::Polygon.new(boundary: [a, b, c])
poly.to_geojson
# => {"type" => "Polygon", "coordinates" => [[[...], [...], [...], [...]]]}
```

All Polygon subclasses (`Triangle`, `Rectangle`, `Pentagon`, `Hexagon`, `Octagon`) inherit this method.

---

### Areas::Circle

Returns a GeoJSON Polygon approximating the circle as a regular N-gon. Default is 32 segments.

```ruby
circle = Geodetic::Areas::Circle.new(centroid: seattle, radius: 10_000)

circle.to_geojson                # => 32-gon (33 positions including closing)
circle.to_geojson(segments: 64)  # => 64-gon (65 positions including closing)
circle.to_geojson(segments: 8)   # => 8-gon (9 positions including closing)
```

The vertices are computed using `Geodetic::Vector#destination_from` (Vincenty direct), so the approximation is geodetically accurate.

---

### Areas::BoundingBox

Returns a GeoJSON Polygon with 4 corners plus the closing point (5 positions total). Ring order follows the GeoJSON right-hand rule: NW → NE → SE → SW → NW.

```ruby
bbox = Geodetic::Areas::BoundingBox.new(
  nw: Geodetic::Coordinate::LLA.new(lat: 48.0, lng: -123.0, alt: 0),
  se: Geodetic::Coordinate::LLA.new(lat: 46.0, lng: -121.0, alt: 0)
)
bbox.to_geojson
# => {"type" => "Polygon", "coordinates" => [[[-123.0, 48.0], [-121.0, 48.0], [-121.0, 46.0], [-123.0, 46.0], [-123.0, 48.0]]]}
```

---

### Feature

Returns a GeoJSON Feature. The `label` is mapped to the `"name"` property. The `metadata` hash is merged into `properties` with keys converted to strings.

```ruby
f = Geodetic::Feature.new(
  label: "Seattle",
  geometry: seattle,
  metadata: { state: "WA", population: 750_000 }
)
f.to_geojson
# => {
#   "type" => "Feature",
#   "geometry" => {"type" => "Point", "coordinates" => [-122.3493, 47.6205]},
#   "properties" => {"name" => "Seattle", "state" => "WA", "population" => 750000}
# }
```

| Feature field | GeoJSON mapping |
|---------------|-----------------|
| `label`       | `properties["name"]` (omitted if `nil`) |
| `metadata`    | Merged into `properties` (symbol keys stringified) |
| `geometry`    | Delegates to the geometry's `to_geojson` |

The geometry can be any type: coordinate, segment, path, polygon, circle, or bounding box.

```ruby
# Feature wrapping a Path
route_feature = Geodetic::Feature.new(
  label: "West Coast Route",
  geometry: route,
  metadata: { mode: "driving" }
)
route_feature.to_geojson
# => {"type" => "Feature", "geometry" => {"type" => "LineString", ...}, "properties" => {...}}
```

---

## Complete Example

```ruby
require "geodetic"

seattle  = Geodetic::Coordinate::LLA.new(lat: 47.6205, lng: -122.3493, alt: 0)
portland = Geodetic::Coordinate::LLA.new(lat: 45.5152, lng: -122.6784, alt: 0)
sf       = Geodetic::Coordinate::LLA.new(lat: 37.7749, lng: -122.4194, alt: 0)

# Build a collection
gj = Geodetic::GeoJSON.new

# Add cities as features with metadata
gj << Geodetic::Feature.new(label: "Seattle", geometry: seattle, metadata: { pop: 750_000 })
gj << Geodetic::Feature.new(label: "Portland", geometry: portland, metadata: { pop: 650_000 })
gj << Geodetic::Feature.new(label: "San Francisco", geometry: sf, metadata: { pop: 870_000 })

# Add the route connecting them
route = Geodetic::Path.new(coordinates: [seattle, portland, sf])
gj << Geodetic::Feature.new(label: "West Coast Route", geometry: route)

# Add a 50km radius around Seattle
gj << Geodetic::Feature.new(
  label: "Seattle Metro",
  geometry: Geodetic::Areas::Circle.new(centroid: seattle, radius: 50_000)
)

# Export
gj.save("west_coast.geojson", pretty: true)
```

The output file can be opened directly in [geojson.io](https://geojson.io), QGIS, Mapbox, Leaflet, or any other GeoJSON-compatible tool.

---

## GeoJSON Specification Notes

- **Coordinate order** is `[longitude, latitude]` (not `[lat, lng]`), per [RFC 7946 Section 3.1.1](https://datatracker.ietf.org/doc/html/rfc7946#section-3.1.1).
- **Altitude** is optional. Included as the third element when non-zero.
- **Polygon rings** follow the right-hand rule: exterior rings are counterclockwise. BoundingBox uses NW → NE → SE → SW → NW.
- **String keys** are used throughout (`"type"`, `"coordinates"`, `"properties"`, etc.) per JSON convention.

---

## Visualizing GeoJSON

The easiest way to verify your exported GeoJSON is [geojson.io](https://geojson.io). It renders points, lines, and polygons on an interactive map with property inspection.

To use it:

1. Export your collection: `gj.save("my_map.geojson", pretty: true)`
2. Open [geojson.io](https://geojson.io) in a browser
3. Drag and drop the `.geojson` file onto the map, or paste the JSON into the editor panel

Feature properties (name, metadata) appear in popups when you click on a rendered geometry. This makes it a quick way to confirm that coordinates, shapes, and metadata are correct before integrating with QGIS, Mapbox, Leaflet, or other GIS tools.
- Output is a Ruby Hash. Call `.to_json` or `JSON.generate(hash)` to produce a JSON string.
