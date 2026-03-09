# Changelog

> [!CAUTION]
> This gem is under active development. APIs and features may change without notice.

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]


## [0.3.1] - 2026-03-09

### Added

- **`Geodetic::Path` class** — directed, ordered sequence of unique coordinates for modeling routes, trails, and boundaries
  - **Navigation**: `first`, `last`, `next`, `prev`, `segments`, `size`, `empty?`
  - **Membership**: `include?`/`includes?` (waypoint check), `contains?`/`inside?` (on-segment check with configurable tolerance)
  - **Spatial**: `nearest_waypoint`, `closest_coordinate_to`, `distance_to`, `bearing_to` using geometric projection onto segments
  - **Closest points**: `closest_points_to` for Path-to-Path, Path-to-Polygon, Path-to-Rectangle, and Path-to-Circle
  - **Computed**: `total_distance`, `segment_distances`, `segment_bearings`, `reverse`
  - **Subpath/split**: `between(from, to)` extracts a subpath; `split_at(coord)` divides into two paths sharing the split point
  - **Interpolation**: `at_distance(distance)` finds the coordinate at a given distance along the path
  - **Bounding box**: `bounds` returns an `Areas::Rectangle`
  - **Polygon conversion**: `to_polygon` closes the path (validates no self-intersection)
  - **Intersection**: `intersects?(other_path)` detects crossing segments
  - **Equality**: `==` compares coordinates in order
  - **Enumerable**: includes `Enumerable` via `each` — supports `map`, `select`, `any?`, `to_a`, etc.
  - **Non-mutating operators**: `+` and `-` accept both coordinates and paths
  - **Mutating operators**: `<<`, `>>`, `prepend`, `insert(after:/before:)`, `delete`/`remove` — all accept paths as well as coordinates
- **`Geodetic::Feature` class** — wraps any coordinate, area, or path geometry with a `label` and `metadata` hash; delegates `distance_to` and `bearing_to` to the underlying geometry
- **Map rendering example** (`examples/05_map_rendering/`) — renders NYC landmarks on a raster map using [libgd-gis](https://rubygems.org/gems/libgd-gis), demonstrating Feature objects, polygon overlays, bearing arrows, icon compositing, and light/dark theme support
- **Path operations example** (`examples/06_path_operations.rb`) — 19-section demo covering all Path capabilities with a Manhattan walking route
- `examples/README.md` describing all six example scripts
- Documentation: `docs/reference/path.md` (Path reference), `docs/reference/feature.md` (Feature reference), and `docs/reference/map-rendering.md` (libgd-gis integration guide)

### Changed

- Updated README, `docs/index.md`, and mkdocs nav to include Path class, Feature class, and map rendering example

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
