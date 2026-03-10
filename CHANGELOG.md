# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]


## [0.7.0] - 2026-03-10

### Added

- **`Geodetic::Geos` module** — optional GEOS C library integration via `fiddle` for accelerated spatial operations
  - **Library binding**: auto-discovers `libgeos_c` on macOS and Linux; uses reentrant `_r` API for thread safety
  - **Predicates**: `Geos.contains?(a, b)`, `Geos.intersects?(a, b)`, `Geos.is_valid?(geom)`, `Geos.is_valid_reason(geom)`
  - **Boolean operations**: `Geos.intersection(a, b)`, `Geos.difference(a, b)`, `Geos.symmetric_difference(a, b)`, `Geos.union(geom)`
  - **Geometry construction**: `Geos.buffer(geom, distance)`, `Geos.buffer_with_style(geom, distance, ...)`, `Geos.convex_hull(geom)`, `Geos.simplify(geom, tolerance)`, `Geos.make_valid(geom)`
  - **Measurements**: `Geos.area(geom)`, `Geos.length(geom)`, `Geos.distance(a, b)`, `Geos.nearest_points(a, b)`
  - **`PreparedGeometry`**: `Geos.prepare(polygon)` builds a spatial index for O(log n) batch `contains?`/`intersects?` queries
  - **Graceful degradation**: `Geos.available?` returns false when `libgeos_c` is not installed; all operations fall back to pure Ruby
  - **`GEODETIC_GEOS_DISABLE` env var**: forces pure Ruby for all operations even when GEOS is installed
  - **`LIBGEOS_PATH` env var**: specify a custom `libgeos_c` library path
  - All GEOS operations accept any Geodetic geometry type and return standard Geodetic objects (Polygon, Path, LLA, etc.)
- **GEOS-accelerated polygon validation** — `Polygon.new` delegates self-intersection validation to GEOS when available, using O(n log n) spatial indexing vs Ruby's O(n^2) pairwise test
- **GEOS-accelerated point-in-polygon** — `polygon.includes?(point)` uses GEOS for polygons with 15+ vertices (`Polygon::GEOS_INCLUDES_THRESHOLD`); below threshold, Ruby's winding-number algorithm is faster
- **GEOS-accelerated path intersection** — `path.intersects?(other_path)` uses GEOS when available (wins at all tested sizes vs Ruby's O(n*m) brute-force)
- **Improved Ruby polygon validation** — added `validate_distinct_vertices!` and `validate_noncollinear!` checks so pure Ruby matches GEOS accuracy for degenerate polygons
- GEOS benchmark example (`examples/12_geos_benchmark.rb`) — compares Ruby vs GEOS performance across polygon validation, point-in-polygon, path intersection, PreparedGeometry batch containment, single segment (Ruby wins), and GEOS-only operations
- GEOS operations example (`examples/13_geos_operations.rb`) — 11-section demo covering boolean overlay, buffering, convex hull, simplification, validity checking, geometry repair, planar measurements, nearest points, PreparedGeometry, operation chaining, and GeoJSON/WKT export of results
- 27 GEOS tests covering all operations, predicates, PreparedGeometry, and error handling
- 3 new polygon validation tests: collinear boundary, insufficient distinct vertices, all-same-point
- Documentation: `docs/reference/geos-acceleration.md` (installation, automatic dispatch, performance expectations, API reference)

### Changed

- Updated README with GEOS Acceleration feature, optional dependency section, and examples 12-13 in the examples table
- Updated `examples/README.md` with example 12 and 13 descriptions
- Updated `examples/sample_geometries.wkb.hex` to use valid (non-degenerate) triangles in polygon entries

### Fixed

- WKB test data used collinear triangle `(1,2)-(3,4)-(5,6)` which is now correctly rejected; updated to valid triangle `(1,2)-(3,4)-(5,2)`
- Polygon validation error message regex in tests updated to match both Ruby and GEOS formats

## [0.6.0] - 2026-03-10

### Added

- **`Geodetic::WKT` module** — Well-Known Text serialization for all geometry types
  - **`to_wkt(precision: 6, srid: nil)`** instance method on all 18 coordinate classes, Segment, Path, Areas::Polygon (and subclasses), Areas::Circle, Areas::BoundingBox, and Feature
  - **Coordinate order**: longitude latitude (OGC Simple Features standard)
  - **Z suffix**: automatically added when any point in the geometry has non-zero altitude; Z-dimensionality is uniform within each geometry
  - **EWKT**: `srid:` option prepends `SRID=N;` for PostGIS compatibility
  - **`WKT.parse(string)`** — parse WKT/EWKT into Geodetic objects (Point → LLA, LineString → Segment/Path, Polygon → Areas::Polygon, Multi*/GeometryCollection → Array)
  - **`WKT.parse_with_srid(string)`** — returns `[object, srid]` tuple
  - **`WKT.save!(path, *objects, srid:, precision:)`** — write one WKT per line
  - **`WKT.load(path)`** — read WKT file into Array of Geodetic objects
  - ENU/NED raise `ArgumentError` (relative systems cannot be exported)
- **`Geodetic::WKB` module** — Well-Known Binary serialization for all geometry types
  - **`to_wkb(srid: nil)`** and **`to_wkb_hex(srid: nil)`** instance methods on all 18 coordinate classes, Segment, Path, Areas::Polygon (and subclasses), Areas::Circle, Areas::BoundingBox, and Feature
  - **Byte order**: output is always little-endian (NDR), matching PostGIS, GEOS, RGeo, and Shapely; parser supports both LE and BE input
  - **ISO WKB Z**: type code + 1000 (Point Z = 1001, LineString Z = 1002, Polygon Z = 1003) when any point has non-zero altitude
  - **EWKB**: `srid:` option embeds SRID via `0x20000000` flag for PostGIS compatibility
  - **`WKB.parse(input)`** — parse WKB from binary or hex string (auto-detects encoding)
  - **`WKB.parse_with_srid(input)`** — returns `[object, srid]` tuple
  - **Binary file I/O**: `WKB.save!(path, *objects, srid:)` / `WKB.load(path)` — framed format (4-byte LE count + size-prefixed WKB)
  - **Hex file I/O**: `WKB.save_hex!(path, *objects, srid:)` / `WKB.load_hex(path)` — one hex string per line, supports `#` comments
  - Supports all WKB types: Point, LineString, Polygon, MultiPoint, MultiLineString, MultiPolygon, GeometryCollection
  - ENU/NED raise `ArgumentError` (relative systems cannot be exported)
- WKT example (`examples/10_wkt_serialization.rb`) — 10-section demo covering export, SRID/EWKT, Z-dimension, parsing, roundtrip, and file I/O
- WKB example (`examples/11_wkb_serialization.rb`) — 10-section demo covering export, EWKB/SRID, Z-dimension, parsing, roundtrip, and binary/hex file I/O
- WKB fixture files: `examples/sample_geometries.wkb` (9 geometries) and `examples/sample_geometries.wkb.hex` (15 geometries with comments)
- 53 WKT tests (134 assertions) and 54 WKB tests (144 assertions)
- Documentation: `docs/reference/wkt.md` and `docs/reference/wkb.md`

### Changed

- Updated README with WKT and WKB sections, key features, and examples 10-11 in the examples table
- Updated `docs/index.md` with WKT and WKB in key features and reference links
- Updated `examples/README.md` with example 10 and 11 descriptions
- Updated `mkdocs.yml` nav with WKT and WKB reference pages
- Added `require_relative "geodetic/wkt"` and `require_relative "geodetic/wkb"` to `lib/geodetic.rb`

## [0.5.2] - 2026-03-10

### Added

- **`Geodetic::GeoJSON.load(path)`** — read a GeoJSON file and return an Array of Geodetic objects
- **`Geodetic::GeoJSON.parse(hash)`** — same as `load` but accepts an already-parsed Ruby Hash
- Roundtrip-safe import: Features with `"name"` or non-empty properties restore as `Geodetic::Feature` (label from `"name"`, remaining properties as `metadata` with symbol keys); Features with empty properties restore as raw geometry
- GeoJSON → Geodetic type mapping:
  - Point → `Coordinate::LLA` (altitude preserved when present)
  - LineString (2 points) → `Segment`
  - LineString (3+ points) → `Path`
  - Polygon → `Areas::Polygon` (outer ring; holes dropped)
  - MultiPoint, MultiLineString, MultiPolygon → flattened into multiple objects
  - GeometryCollection → flattened into individual geometries
- 17 new tests covering load, parse, roundtrip, multi-geometries, and edge cases

### Changed

- Updated README with `GeoJSON.load` usage example
- Updated `docs/reference/geojson.md` with Import section, type mapping table, and roundtrip example
- Updated `mkdocs.yml` nav to include all 7 missing coordinate systems (GH36, GH, HAM, OLC, GEOREF, GARS, H3) and 3 missing reference pages (Vector, Arithmetic, GeoJSON Export)
- GeoJSON demo (`examples/09_geojson_export.rb`) now saves output to `examples/` directory instead of system temp

## [0.5.1] - 2026-03-10

### Added

- **`Geodetic::GeoJSON` class** — build GeoJSON FeatureCollections from any mix of Geodetic objects
  - **Constructor**: `GeoJSON.new`, `GeoJSON.new(obj, ...)`, `GeoJSON.new([array])`
  - **Accumulate**: `<<` accepts single objects or arrays; returns `self` for chaining
  - **Query**: `size`/`length`, `empty?`, `each`, and all `Enumerable` methods
  - **Remove**: `delete(obj)`, `clear`
  - **Export**: `to_h` (Ruby Hash), `to_json`/`to_json(pretty: true)` (JSON string), `save(path, pretty: false)` (file output)
  - Non-Feature objects auto-wrapped as GeoJSON Features with empty properties
  - Feature objects carry `label` → `"name"` and `metadata` → `properties`
- **`to_geojson` instance method** on all geometry types:
  - All 18 coordinate classes → GeoJSON Point (via LLA; altitude included when non-zero)
  - `Segment` → GeoJSON LineString (2 positions)
  - `Path` → GeoJSON LineString (default) or Polygon (`as: :polygon`, auto-closes ring)
  - `Areas::Polygon` and subclasses → GeoJSON Polygon
  - `Areas::Circle` → GeoJSON Polygon (N-gon approximation, default 32 segments, configurable via `segments:`)
  - `Areas::BoundingBox` → GeoJSON Polygon (4 corners, right-hand rule ring order)
  - `Feature` → GeoJSON Feature with geometry and properties
  - ENU/NED raise `ArgumentError` (relative systems require conversion first)
- GeoJSON export example (`examples/09_geojson_export.rb`) — 10-section demo covering `to_geojson` on all geometry types, FeatureCollection building, delete/clear, Enumerable, and file export
- Documentation: `docs/reference/geojson.md` (GeoJSON Export reference)

### Fixed

- Corrected stale numeric values in documentation:
  - Seattle→Portland distance: 235393.17 → 235385.71 m (README, `docs/reference/conversions.md`)
  - Seattle→Portland bearing: 188.2° → 186.25° (README, `docs/reference/conversions.md`, `docs/reference/arithmetic.md`)
  - Seattle→Portland miles: 146.28 → 146.26 (README)
  - Liberty→Empire bearing: 36.99° → 36.95° (README, `docs/reference/feature.md`)
- Fixed `docs/index.md` Key Features list to include all 18 coordinate systems (was missing GEOREF, GARS, H3)

### Changed

- Updated README with GeoJSON Export section, key features bullet, and example 09 in the examples table
- Updated `docs/index.md` with GeoJSON Export in key features and reference links
- Updated `examples/README.md` with example 09 description

## [0.5.0] - 2026-03-10

### Added

- **`Geodetic::Vector` class** — geodetic displacement pairing a Distance (magnitude) with a Bearing (direction)
  - **Construction**: `Vector.new(distance:, bearing:)` with automatic coercion from numeric values
  - **Components**: `north`, `east` — decomposed meters; `magnitude` — distance in meters
  - **Factory methods**: `Vector.from_components(north:, east:)`, `Vector.from_segment(segment)`
  - **Vincenty direct**: `destination_from(origin)` solves the direct geodetic problem on the WGS84 ellipsoid
  - **Arithmetic**: `+`, `-` (component-wise), `*`, `/` (scalar), `-@` (unary minus); `Numeric * Vector` via coerce
  - **Products**: `dot(other)`, `cross(other)`, `angle_between(other)`
  - **Properties**: `zero?`, `normalize`, `reverse`/`inverse`
  - **Comparable**: ordered by distance (magnitude)
  - Near-zero results (< 1e-9 m) snap to clean zero vector
- **Geodetic arithmetic with `+` operator** — build geometry from coordinates, vectors, and distances:
  - `Coordinate + Coordinate` → Segment
  - `Coordinate + Coordinate + Coordinate` → Path (via Segment + Coordinate → Path)
  - `Coordinate + Segment` → Path
  - `Segment + Coordinate` → Path
  - `Segment + Segment` → Path
  - `Coordinate + Distance` → Circle
  - `Distance + Coordinate` → Circle (commutative)
  - `Coordinate + Vector` → Segment (Vincenty direct)
  - `Vector + Coordinate` → Segment (reverse start to coordinate)
  - `Segment + Vector` → Path (extend from endpoint)
  - `Vector + Segment` → Path (prepend via reverse)
  - `Path + Vector` → Path (extend from last point)
- **Translation with `*` operator and `translate` method** — uniform displacement across all geometric types:
  - `Coordinate * Vector` → Coordinate (translated point)
  - `Segment * Vector` → Segment (translated endpoints)
  - `Path * Vector` → Path (translated waypoints)
  - `Circle * Vector` → Circle (translated centroid, preserved radius)
  - `Polygon * Vector` → Polygon (translated vertices)
- **`Segment#to_vector`** — extract a Vector from a Segment's length and bearing
- **`Path#to_corridor(width:)`** — convert a path into a Polygon corridor of a given width; uses mean bearing at interior waypoints to avoid self-intersection; accepts meters or a Distance object
- **Geodetic arithmetic example** (`examples/08_geodetic_arithmetic.rb`) — 11-section demo covering all arithmetic operators, Vector class, translation, corridors, and composed operations
- Documentation: `docs/reference/vector.md` (Vector reference), `docs/reference/arithmetic.md` (Geodetic Arithmetic reference)

### Changed

- Updated README with Vector, Geodetic Arithmetic, and Corridors sections; added to key features list
- Updated `examples/README.md` with example 08 description

## [0.4.0] - 2026-03-10

### Added

- **`Geodetic::Segment` class** — directed two-point line segment, the fundamental geometric primitive underlying Path and Polygon
  - **Properties**: `length`/`distance` (returns Distance), `length_meters`, `bearing` (returns Bearing), `midpoint`/`centroid` (returns LLA) — all lazily computed and cached
  - **Projection**: `project(point)` returns the closest point on the segment and perpendicular distance
  - **Interpolation**: `interpolate(fraction)` returns the LLA at any fraction along the segment
  - **Membership**: `includes?(point)` (vertex-only check), `contains?(point, tolerance:)` (on-segment check), `excludes?`
  - **Intersection**: `intersects?(other_segment)` using cross-product orientation tests
  - **Conversion**: `reverse`, `to_path`, `to_a`, `==`, `to_s`, `inspect`
- **`Geodetic::Areas::Triangle`** — polygon subclass with four construction modes
  - Isosceles: `Triangle.new(center:, width:, height:, bearing:)`
  - Equilateral by circumradius: `Triangle.new(center:, radius:, bearing:)`
  - Equilateral by side length: `Triangle.new(center:, side:, bearing:)`
  - Arbitrary vertices: `Triangle.new(vertices: [p1, p2, p3])`
  - Predicates: `equilateral?`, `isosceles?`, `scalene?` based on actual side lengths (5m tolerance)
  - Methods: `vertices`, `side_lengths`, `base`, `to_bounding_box`
- **`Geodetic::Areas::Rectangle`** — polygon subclass defined by a centerline Segment and perpendicular width
  - `Rectangle.new(segment:, width:)` — accepts a Segment object or a two-element array of coordinates
  - `width:` accepts numeric (meters) or a Distance instance
  - Derived properties: `center`, `height`, `bearing` from the centerline; `corners`, `square?`, `to_bounding_box`
- **`Geodetic::Areas::Pentagon`**, **`Hexagon`**, **`Octagon`** — regular polygon subclasses from center + radius + bearing
- **Polygon self-intersection validation** — `Polygon.new` validates that no edge crosses another; pass `validate: false` to skip (used by subclasses with generated geometry)
- **Polygon `segments` method** — returns `Array<Segment>` for each edge; `edges` and `border` are aliases
- **Segments and shapes example** (`examples/07_segments_and_shapes.rb`) — 10-section demo covering Segment operations, Triangle/Rectangle construction and predicates, regular polygons, containment, bounding boxes, and Feature integration
- Documentation: `docs/reference/segment.md` (Segment reference with Great Circle Arcs section), updated `docs/reference/areas.md` with all polygon subclasses

### Changed

- **Refactored `Path`** to use Segment objects — removed ~140 lines of private segment methods (`project_onto_segment`, `on_segment?`, `segments_intersect?`, `cross_sign`, `on_collinear?`, `to_flat`); all segment operations now delegate to Segment
- **Refactored `Polygon`** — `segments` is now the primary method (was `edges`); `edges` and `border` are aliases
- **Updated `Feature`** to support Segment as a geometry type via `centroid` (alias for `midpoint`)
- Updated README, `docs/index.md`, `docs/reference/areas.md`, `docs/reference/segment.md`, `examples/README.md`, and mkdocs nav

### Removed

- `Areas::Rectangle = Areas::BoundingBox` alias — Rectangle is now its own class (Polygon subclass)

## [0.3.2] - 2026-03-09

### Added

- **`Geodetic::Path` class** — directed, ordered sequence of unique coordinates for modeling routes, trails, and boundaries
  - **Navigation**: `first`, `last`, `next`, `prev`, `segments`, `size`, `empty?`
  - **Membership**: `include?`/`includes?` (waypoint check), `contains?`/`inside?` (on-segment check with configurable tolerance)
  - **Spatial**: `nearest_waypoint`, `closest_coordinate_to`, `distance_to`, `bearing_to` using geometric projection onto segments
  - **Closest points**: `closest_points_to` for Path-to-Path, Path-to-Polygon, Path-to-BoundingBox, and Path-to-Circle
  - **Computed**: `total_distance`, `segment_distances`, `segment_bearings`, `reverse`
  - **Subpath/split**: `between(from, to)` extracts a subpath; `split_at(coord)` divides into two paths sharing the split point
  - **Interpolation**: `at_distance(distance)` finds the coordinate at a given distance along the path
  - **Bounding box**: `bounds` returns an `Areas::BoundingBox`
  - **Polygon conversion**: `to_polygon` closes the path (validates no self-intersection)
  - **Intersection**: `intersects?(other_path)` detects crossing segments
  - **Equality**: `==` compares coordinates in order
  - **Enumerable**: includes `Enumerable` via `each` — supports `map`, `select`, `any?`, `to_a`, etc.
  - **Non-mutating operators**: `+` and `-` accept both coordinates and paths
  - **Mutating operators**: `<<`, `>>`, `prepend`, `insert(after:/before:)`, `delete`/`remove` — all accept paths as well as coordinates
- **Path operations example** (`examples/06_path_operations.rb`) — 19-section demo covering all Path capabilities with a Manhattan walking route
- Documentation: `docs/reference/path.md` (Path reference)

### Changed

- Updated `Geodetic::Feature` to support Path as a geometry type — delegates `distance_to` and `bearing_to` using geometric projection
- Updated README, `docs/index.md`, `docs/reference/feature.md`, `examples/README.md`, and mkdocs nav to include Path class

## [0.3.1] - 2026-03-09

### Added

- **`Geodetic::Feature` class** — wraps any coordinate or area geometry with a `label` and `metadata` hash; delegates `distance_to` and `bearing_to` to the underlying geometry, using the centroid for area geometries
- **Map rendering example** (`examples/05_map_rendering/`) — renders NYC landmarks on a raster map using [libgd-gis](https://rubygems.org/gems/libgd-gis), demonstrating Feature objects, polygon overlays, bearing arrows, icon compositing, and light/dark theme support
- `examples/README.md` describing all five example scripts
- Documentation: `docs/reference/feature.md` (Feature reference) and `docs/reference/map-rendering.md` (libgd-gis integration guide)

### Changed

- Updated README, `docs/index.md`, and mkdocs nav to include Feature class and map rendering example

## [0.3.0] - 2026-03-08

### Added

- **H3 Hexagonal Hierarchical Index** (`Geodetic::Coordinate::H3`) — Uber's spatial indexing system, bringing total to 18 coordinate systems (324 conversion paths)
- H3 uses Ruby's `fiddle` to call the H3 v4 C API directly — no gem dependency beyond `fiddle`
- H3-specific features: `grid_disk(k)`, `parent(res)`, `children(res)`, `pentagon?`, `cell_area`, `h3_index`, `resolution` (0-15)
- H3 `to_area` returns `Areas::Polygon` (6 vertices for hexagons, 5 for pentagons) instead of `Areas::Rectangle`
- H3 `neighbors` returns Array of 6 cells instead of directional Hash with 8 cardinal keys
- Graceful degradation: H3 raises clear error with installation instructions if `libh3` is not found; all other coordinate systems work normally
- `H3.available?` class method to check for libh3 at runtime
- Documentation page: `docs/coordinate-systems/h3.md`

### Changed

- Updated all documentation to reflect 18 coordinate systems (README, docs, gemspec, CLAUDE.md)

## [0.2.0] - 2026-03-08

### Added

- **2 new coordinate systems** bringing the total from 15 to 17:
  - `Geodetic::Coordinate::GEOREF` — World Geographic Reference System (aviation/military geocode with variable precision from 15-degree tiles to 0.001-minute resolution)
  - `Geodetic::Coordinate::GARS` — Global Area Reference System (NGA standard with 30-minute cells, 15-minute quadrants, and 5-minute keypads)
- Full cross-system conversions for GEOREF and GARS — all 17 coordinate systems convert to/from every other system (289 conversion paths)
- Spatial hash features for GEOREF and GARS: `neighbors`, `to_area`, `precision_in_meters`, `to_slug`, configurable precision
- Documentation pages: `docs/coordinate-systems/georef.md` and `docs/coordinate-systems/gars.md`

### Changed

- **Namespace renamed**: `Geodetic::Coordinates` is now `Geodetic::Coordinate` (singular)
- **SpatialHash base class** (`lib/geodetic/coordinate/spatial_hash.rb`) — GH36, GH, HAM, OLC, GEOREF, and GARS now inherit from a shared base class that provides common behavior (neighbors, to_area, precision_in_meters, serialization, encoding/decoding contract)
- **Auto-generated hash conversions** — `SpatialHash.generate_hash_conversions_for` replaces 232 lines of hand-written boilerplate `to_gh`/`from_gh`/`to_ham`/`from_ham`/etc. methods across 7 coordinate classes
- **Self-registration** — each coordinate class calls `Coordinate.register_class(self)` at load time; `ALL_COORD_CLASSES` is populated from the registry instead of a manual list

## [0.1.0] - 2026-03-08

### Added

- **4 new coordinate systems** bringing the total from 11 to 15:
  - `Geodetic::Coordinate::GH36` — Geohash-36 (radix-36 spatial hash, URL-friendly)
  - `Geodetic::Coordinate::GH` — Geohash base-32 (standard geohash, supported by Elasticsearch, Redis, PostGIS)
  - `Geodetic::Coordinate::HAM` — Maidenhead Locator System (amateur radio grid squares)
  - `Geodetic::Coordinate::OLC` — Open Location Code / Plus Codes (Google's location encoding)
- **Full cross-system conversions** — all 15 coordinate systems convert to/from every other system (225 conversion paths)
- **Spatial hash features** for GH36, GH, HAM, and OLC:
  - `neighbors` — returns all 8 adjacent grid cells
  - `to_area` — returns the cell as a `Geodetic::Areas::Rectangle`
  - `precision_in_meters` — cell size in meters as `{ lat:, lng: }`
  - `to_slug` — URL-friendly string representation
  - Configurable precision on construction
- **Geographic areas** — `Geodetic::Areas::Circle`, `Geodetic::Areas::Polygon`, and `Geodetic::Areas::Rectangle` for point-in-area testing
- **Bearing calculations** — universal `bearing_to` and `elevation_to` methods on all coordinate classes via `BearingMethods` mixin
- **`Geodetic::Bearing` class** — immutable value type with compass directions, reciprocal, radians, arithmetic, and `Comparable`
- **Validated setters** with type coercion and range validation on all mutable coordinate classes
- **`to_s(precision)`** on all coordinate classes, `Distance`, and `Bearing` with class-specific defaults
- **ENU and NED local methods** — `local_bearing_to` and `local_elevation_angle_to` for tangent-plane operations; NED adds `horizontal_distance_to`
- **GitHub Pages documentation** site with MkDocs

### Changed

- Coordinate classes use `attr_reader` with validated setter methods instead of `attr_accessor`
- ENU/NED bearing methods renamed: `bearing_to` → `local_bearing_to`, `elevation_angle_to` → `local_elevation_angle_to` (universal `bearing_to`/`elevation_to` now come from the mixin)

### Fixed

- ENU/NED argument mismatch in 8 coordinate classes — `to_enu`/`to_ned` passed extra `datum` arg that `LLA#to_enu`/`LLA#to_ned` does not accept
- StatePlane `lambert_conformal_conic_to_lla` double `DEG_PER_RAD` conversion producing incorrect results
- OLC floating-point encoding error — pre-computed `PAIR_RESOLUTIONS` with epsilon correction prevents truncation (e.g., Google HQ encoding "849VCWC8+R9")

## [0.0.1] - 2026-03-07

Initial update from an old archived project.
