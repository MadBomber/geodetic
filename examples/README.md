# Geodetic Examples

Runnable demo scripts showing progressive usage of the Geodetic library. Run any single-file example from the project root:

```bash
ruby -Ilib examples/01_basic_conversions.rb
```

## 01 - Basic Conversions

Converts a single point between LLA, ECEF, UTM, ENU, and NED coordinate systems. Demonstrates roundtrip accuracy and local coordinate frames with a reference point.

## 02 - All Coordinate Systems

Walks through all 18 coordinate systems with cross-system conversion chains. Covers spatial hashes (GH, GH36, HAM, OLC, GEOREF, GARS, H3), areas, and neighbor lookups.

## 03 - Distance Calculations

Demonstrates the `Distance` class: great-circle and straight-line distances, unit conversions (km, mi, ft, nmi), arithmetic, comparison, and cross-system distance calculations.

## 04 - Bearing Calculations

Demonstrates the `Bearing` class: forward azimuth, back azimuth, compass directions (4/8/16-point), elevation angles, chain bearings, and cross-system bearing calculations.

## 05 - Map Rendering

Renders geodetic data on a raster map using the [libgd-gis](https://rubygems.org/gems/libgd-gis) gem. Showcases `Geodetic::Feature` for wrapping coordinates and areas with labels and metadata.

Features demonstrated:

- **Feature objects** with point and polygon geometries
- **Landmark icons** scaled and composited onto the map
- **Polygon rendering** of Central Park's boundary
- **Bearing arrows** with degree labels between landmarks
- **Distance and bearing delegation** through Feature objects
- **UTM conversion** output for each landmark
- **Light/dark theme** switching with macOS system detection

Prerequisites:

```bash
gem install libgd-gis
brew install gd   # macOS
```

Run from the project root:

```bash
ruby -Ilib examples/05_map_rendering/demo.rb
```

CLI flags:

```
--light / --dark       Select basemap theme (default: macOS system setting)
--central-park         Show Central Park polygon (default)
--no-central-park      Hide Central Park polygon
--icon-scale=N         Scale landmark icons (default: 0.5)
-h, --help             Show help
```

Output: `examples/05_map_rendering/nyc_landmarks.png`

## 06 - Path Operations

Demonstrates the `Geodetic::Path` class with a walking route through Manhattan. Covers:

- **Construction** from arrays and incremental building with `<<` and `>>`
- **Navigation** with `first`, `last`, `next`, `prev`
- **Segment analysis** with distances and bearings for each leg
- **Mutation** with `insert`, `delete`, `+`, `-`
- **Path arithmetic** combining paths with `+`, `<<`, `>>` and removing with `-`
- **Closest approach** using geometric projection to find the nearest point on the path to an off-path target
- **Containment testing** with `includes?` (waypoint check) and `contains?` (on-segment check)
- **Enumerable** iteration with `map`, `select`, `max_by`
- **Equality** comparing paths by coordinates and order
- **Subpath extraction** with `between` and **splitting** with `split_at`
- **Interpolation** finding coordinates at a given distance along the path with `at_distance`
- **Bounding box** with `bounds` returning an `Areas::BoundingBox`
- **Polygon conversion** with `to_polygon` (validates no self-intersection)
- **Path intersection** detection with `intersects?`
- **Path-to-Path closest points** finding the nearest pair between two paths
- **Path-to-Area closest points** for Circle and Polygon areas
- **Reverse** to create the return route
- **Feature integration** wrapping a Path with label and metadata

## 07 - Segments and Shapes

Demonstrates `Geodetic::Segment` and the polygon subclasses (`Triangle`, `Rectangle`, `Pentagon`, `Hexagon`, `Octagon`) using landmarks around the National Mall in Washington DC. Covers:

- **Segment properties** including `length`/`distance`, `bearing`, `midpoint`/`centroid`
- **Segment operations** with `interpolate`, `project`, `reverse`
- **Membership testing** with `includes?` (vertex check) and `contains?` (on-segment check)
- **Intersection detection** between crossing and parallel segments
- **Triangle construction** in four modes: isosceles, equilateral by side, equilateral by radius, arbitrary vertices
- **Triangle predicates** with `equilateral?`, `isosceles?`, `scalene?`, and `side_lengths`
- **Rectangle construction** from a `Segment` centerline (or two-point array) plus width
- **Rectangle properties** with `centerline`, `center`, `height`, `bearing`, `square?`
- **Regular polygons** (Pentagon, Hexagon, Octagon) from center and radius
- **Polygon segments** accessing edges as `Segment` objects
- **Bounding boxes** via `to_bounding_box` on any polygon subclass
- **Containment testing** with `includes?` across different shapes
- **Feature integration** wrapping Segment and area geometries with labels and metadata

## 08 - Geodetic Arithmetic

Demonstrates the operator-based geometry system and the `Geodetic::Vector` class using West Coast cities. Covers:

- **Building Segments with +** combining two coordinates, including cross-system (LLA + UTM)
- **Chaining + into Paths** with Coordinate + Coordinate + Coordinate, Coordinate + Segment, and Segment + Segment
- **Coordinate + Distance → Circle** with commutative Distance + Coordinate
- **Vector construction** from distance/bearing, from a Segment (`to_vector`), and from north/east components
- **Vector arithmetic** with addition, subtraction, scalar multiplication, reverse, zero cancellation, dot product, and cross product
- **Coordinate + Vector → Segment** solving the Vincenty direct problem, and Vector + Coordinate for the reverse
- **Extending geometry with Vectors** using Segment + Vector, Vector + Segment, and Path + Vector
- **Translation with \*** shifting Coordinates, Segments, Paths, Circles, and Polygons by a Vector (also available as `.translate`)
- **Key distinction: + vs \*** where `P + V` returns a Segment (the journey) and `P * V` returns a Coordinate (the destination)
- **Path corridors** with `to_corridor(width:)` converting a path into a polygon, and translating the corridor
- **Composing operations** chaining arithmetic, vector math, and corridors in single expressions

## 09 - GeoJSON Export

Demonstrates the `Geodetic::GeoJSON` class for building and exporting GeoJSON FeatureCollections. Covers:

- **Coordinate → Point** with `to_geojson` on any coordinate system, including altitude handling
- **Segment → LineString** exporting two-point directed segments
- **Path → LineString** and optional `to_geojson(as: :polygon)` for closed paths
- **Areas → Polygon** for `Polygon`, `Circle` (32-gon approximation with configurable `segments:`), and `BoundingBox`
- **Feature → GeoJSON Feature** with `label` mapped to `"name"` and `metadata` merged into `properties`
- **FeatureCollection building** with `GeoJSON.new`, `<<` for single objects and arrays, and `GeoJSON.new(obj, ...)` initialization
- **Delete and clear** removing individual objects or emptying the collection
- **Enumerable** iteration over collected objects
- **Export** via `to_h` (Ruby Hash), `to_json`/`to_json(pretty: true)` (JSON string), and `save(path, pretty:)` (file output)

## 10 - WKT Serialization

Demonstrates `Geodetic::WKT` for Well-Known Text export and import, the standard geometry format used by PostGIS, RGeo, and most GIS tools. Covers:

- **Coordinate → POINT** with `to_wkt` on any coordinate system, including altitude (Z suffix)
- **Segment → LINESTRING** exporting two-point directed segments
- **Path → LINESTRING** and optional `to_wkt(as: :polygon)` for closed paths
- **Areas → POLYGON** for `Polygon`, `Circle` (N-gon approximation with configurable `segments:`), and `BoundingBox`
- **Feature → delegates to geometry** (WKT has no properties concept)
- **SRID / EWKT** with `to_wkt(srid: 4326)` producing PostGIS-compatible Extended WKT
- **Z-dimension consistency** where any non-zero altitude triggers Z on all points in the geometry
- **Parsing** with `WKT.parse` (returns Geodetic objects) and `WKT.parse_with_srid` (returns object + SRID)
- **Roundtrip** verification showing export → parse → re-export produces identical WKT strings
- **File I/O** with `WKT.save` writing one WKT per line and `WKT.load` reading them back, including SRID support and full file roundtrip verification

## 11 - WKB Serialization

Demonstrates `Geodetic::WKB` for Well-Known Binary export and import, the binary counterpart to WKT used by PostGIS, GEOS, RGeo, and Shapely for efficient geometry storage. Covers:

- **Coordinate → POINT** with `to_wkb` and `to_wkb_hex` on any coordinate system, including altitude (Z type code)
- **Segment → LINESTRING** exporting two-point directed segments
- **Path → LINESTRING** and optional `to_wkb(as: :polygon)` for closed paths
- **Areas → POLYGON** for `Polygon`, `Circle` (N-gon approximation with configurable `segments:`), and `BoundingBox`
- **Feature → delegates to geometry** (WKB has no properties concept)
- **SRID / EWKB** with `to_wkb_hex(srid: 4326)` producing PostGIS-compatible Extended WKB
- **Z-dimension consistency** where any non-zero altitude triggers Z on all points in the geometry
- **Parsing** with `WKB.parse` (auto-detects binary vs hex) and `WKB.parse_with_srid` (returns object + SRID)
- **Roundtrip** verification showing export → parse → re-export produces identical hex strings
- **File I/O** with `WKB.save!`/`WKB.load` for binary format and `WKB.save_hex!`/`WKB.load_hex` for hex format, including fixture file loading and full roundtrip verification

## 12 - GEOS Benchmark

Benchmarks pure Ruby spatial operations against GEOS-accelerated versions. Requires `libgeos_c` installed (`brew install geos` on macOS). Uses the `GEODETIC_GEOS_DISABLE` environment variable to toggle between Ruby and GEOS within the same run. Covers:

- **Polygon validation** comparing Ruby's O(n^2) pairwise segment test against GEOS's O(n log n) spatial index at 50, 100, and 500 vertices
- **Point-in-polygon** comparing Ruby's winding-number algorithm against GEOS's contains test, showing the crossover threshold at 15 vertices
- **Path intersection** comparing Ruby's O(n*m) brute-force segment checks against GEOS's spatial indexing for non-intersecting paths with overlapping bounds
- **Batch containment** with `PreparedGeometry` testing 1,000 random points against a 100-vertex polygon, comparing Ruby, GEOS one-shot, and GEOS prepared (spatial index built once)
- **Single segment intersection** demonstrating where Ruby wins due to FFI overhead exceeding the computation cost
- **GEOS-only operations** benchmarking `intersection`, `difference`, `symmetric_difference`, `convex_hull`, `simplify`, `is_valid?`, `area`, and `nearest_points` — capabilities with no pure Ruby equivalent
- **Summary table** with side-by-side timings and speedup ratios

Prerequisites:

```bash
brew install geos   # macOS
```

Run:

```bash
ruby -Ilib examples/12_geos_benchmark.rb
```

## 13 - GEOS Operations

Demonstrates GEOS-only operations — capabilities provided by the GEOS C library that have no pure Ruby equivalent in Geodetic. Uses two overlapping rectangles around Manhattan as the primary test geometries. Covers:

- **Boolean operations** with `intersection` (area of overlap), `difference` (A minus B), `symmetric_difference` (XOR), and `union` (dissolve internal boundaries)
- **Buffering** with `buffer` (create polygon zones around points and paths) and `buffer_with_style` (flat caps, mitre joins)
- **Convex hull** computing the smallest convex polygon enclosing a set of NYC landmarks
- **Simplification** using the Douglas-Peucker algorithm at multiple tolerance levels (50 vertices reduced to 16, 8, or 4)
- **Validity checking** with `is_valid?` and `is_valid_reason` on valid and self-intersecting (bowtie) polygons
- **Geometry repair** with `make_valid` splitting a self-intersecting bowtie into two valid triangles
- **Planar measurements** with `area`, `length`, `distance` in coordinate units
- **Nearest points** finding the closest point pair between two separated polygons
- **PreparedGeometry** batch spatial indexing for O(log n) `contains?` and `intersects?` queries
- **Chaining operations** combining GEOS results with other GEOS calls and Geodetic methods
- **Serialization** exporting GEOS results to GeoJSON and WKT

Prerequisites:

```bash
brew install geos   # macOS
```

Run:

```bash
ruby -Ilib examples/13_geos_operations.rb
```
