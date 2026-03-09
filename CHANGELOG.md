# Changelog

> [!CAUTION]
> This gem is under active development. APIs and features may change without notice.

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]


## [0.2.0] - 2026-03-08

### Added

- **3 new coordinate systems** bringing the total from 15 to 18:
  - `Geodetic::Coordinate::GEOREF` — World Geographic Reference System (aviation/military geocode with variable precision from 15-degree tiles to 0.001-minute resolution)
  - `Geodetic::Coordinate::GARS` — Global Area Reference System (NGA standard with 30-minute cells, 15-minute quadrants, and 5-minute keypads)
  - `Geodetic::Coordinate::H3` — Uber's H3 Hexagonal Hierarchical Index (16 resolution levels, hexagonal cells via `libh3` C library through `fiddle`)
- Full cross-system conversions for GEOREF, GARS, and H3 — all 18 coordinate systems convert to/from every other system (324 conversion paths)
- Spatial hash features for GEOREF, GARS, and H3: `neighbors`, `to_area`, `precision_in_meters`, `to_slug`, configurable precision
- H3-specific features: `grid_disk(k)`, `parent(res)`, `children(res)`, `pentagon?`, `cell_area`, `h3_index`, `resolution` (0-15)
- H3 `to_area` returns `Areas::Polygon` (6 vertices for hexagons, 5 for pentagons) instead of `Areas::Rectangle`
- H3 `neighbors` returns Array of 6 cells instead of directional Hash with 8 cardinal keys
- Graceful degradation: H3 raises clear error with installation instructions if `libh3` is not found; all other coordinate systems work normally
- Documentation pages: `docs/coordinate-systems/georef.md`, `docs/coordinate-systems/gars.md`, and `docs/coordinate-systems/h3.md`

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
