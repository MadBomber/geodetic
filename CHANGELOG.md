# Changelog

> [!CAUTION]
> This gem is under active development. APIs and features may change without notice.

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

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
