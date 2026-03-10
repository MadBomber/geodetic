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
