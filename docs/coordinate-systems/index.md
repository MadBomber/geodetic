# Coordinate Systems Overview

The Geodetic gem supports 13 coordinate systems organized into six categories. All coordinate classes live under `Geodetic::Coordinates`.

## Global Systems

| System | Class | Description |
|--------|-------|-------------|
| **LLA** | `Geodetic::Coordinates::LLA` | Latitude, Longitude, Altitude. The most common geographic coordinate system, expressing positions in decimal degrees with altitude in meters. Negative longitude is the Western hemisphere; negative latitude is the Southern hemisphere. |
| **ECEF** | `Geodetic::Coordinates::ECEF` | Earth-Centered, Earth-Fixed. A Cartesian coordinate system with the origin at the Earth's center of mass. Positions are expressed as X, Y, Z in meters. Commonly used in satellite navigation and aerospace applications. |
| **UTM** | `Geodetic::Coordinates::UTM` | Universal Transverse Mercator. Divides the Earth into 60 zones (each 6 degrees of longitude), projecting positions as easting/northing in meters within a zone and hemisphere. Covers latitudes 80S to 84N. |

## Local Tangent Plane Systems

| System | Class | Description |
|--------|-------|-------------|
| **ENU** | `Geodetic::Coordinates::ENU` | East, North, Up. A local tangent plane coordinate system centered on a reference point. Axes point East, North, and Up relative to the reference. Distances are in meters. Used in robotics, surveying, and local navigation. |
| **NED** | `Geodetic::Coordinates::NED` | North, East, Down. A local tangent plane coordinate system centered on a reference point. Axes point North, East, and Down. Used extensively in aerospace and aviation applications. Mathematically related to ENU by axis reordering and sign inversion. |

## Military and Grid Systems

| System | Class | Description |
|--------|-------|-------------|
| **MGRS** | `Geodetic::Coordinates::MGRS` | Military Grid Reference System. An alphanumeric system based on UTM that identifies positions using grid zone designator, 100km square identifier, and numeric easting/northing. Variable precision from 10km down to 1m. |
| **USNG** | `Geodetic::Coordinates::USNG` | United States National Grid. Based on MGRS but formatted with spaces for readability. Used primarily within the United States for emergency services and land management. |

## Web Mapping

| System | Class | Description |
|--------|-------|-------------|
| **WebMercator** | `Geodetic::Coordinates::WebMercator` | Web Mercator (EPSG:3857). Also known as Pseudo-Mercator or Spherical Mercator. The projection used by Google Maps, OpenStreetMap, and Bing Maps. Positions are X/Y in meters. Latitude is clamped to approximately +/-85.05 degrees. Includes tile and pixel coordinate methods for web mapping applications. |

## Polar

| System | Class | Description |
|--------|-------|-------------|
| **UPS** | `Geodetic::Coordinates::UPS` | Universal Polar Stereographic. Covers the polar regions not handled by UTM (north of 84N and south of 80S). Uses a stereographic projection centered on each pole with zones Y/Z (north) and A/B (south). |

## Spatial Hashing

| System | Class | Description |
|--------|-------|-------------|
| **GH36** | `Geodetic::Coordinates::GH36` | Geohash-36. A hierarchical spatial hashing algorithm that encodes latitude/longitude into a compact, URL-friendly string using a case-sensitive 36-character alphabet (radix-36). Each hash represents a rectangular cell; the coordinate value is the cell midpoint. Supports neighbor lookup, area extraction via `to_area`, and configurable precision (default 10 characters for sub-meter resolution). |
| **GH** | `Geodetic::Coordinates::GH` | Geohash (base-32). The standard geohash algorithm by Gustavo Niemeyer using a 32-character alphabet (`0-9, b-z` excluding `a, i, l, o`). The de facto standard for spatial hashing, natively supported by Elasticsearch, Redis, PostGIS, and many geocoding services. Supports neighbor lookup, area extraction, and configurable precision (default 12 characters for sub-centimeter resolution). |

## Regional Systems

| System | Class | Description |
|--------|-------|-------------|
| **StatePlane** | `Geodetic::Coordinates::StatePlane` | State Plane Coordinate System. US state-based coordinate systems using Lambert Conformal Conic or Transverse Mercator projections. Each state has one or more zones with specific parameters. Coordinates are typically in US Survey Feet. |
| **BNG** | `Geodetic::Coordinates::BNG` | British National Grid. The official coordinate system for Great Britain, based on the OSGB36 datum with the Airy 1830 ellipsoid. Uses a Transverse Mercator projection and an alphanumeric grid reference system (e.g., "TQ 30 80"). |

---

## Conversion Matrix

Every coordinate system can convert to every other coordinate system. The table below confirms full interoperability:

| From \ To | LLA | ECEF | UTM | ENU | NED | MGRS | USNG | WebMercator | UPS | StatePlane | BNG | GH36 | GH |
|-----------|-----|------|-----|-----|-----|------|------|-------------|-----|------------|-----|------|----|
| **LLA**        | --  | Y | Y | Y | Y | Y | Y | Y | Y | Y | Y | Y | Y |
| **ECEF**       | Y | --  | Y | Y | Y | Y | Y | Y | Y | Y | Y | Y | Y |
| **UTM**        | Y | Y | --  | Y | Y | Y | Y | Y | Y | Y | Y | Y | Y |
| **ENU**        | Y | Y | Y | --  | Y | Y | Y | Y | Y | Y | Y | Y | Y |
| **NED**        | Y | Y | Y | Y | --  | Y | Y | Y | Y | Y | Y | Y | Y |
| **MGRS**       | Y | Y | Y | Y | Y | --  | Y | Y | Y | Y | Y | Y | Y |
| **USNG**       | Y | Y | Y | Y | Y | Y | --  | Y | Y | Y | Y | Y | Y |
| **WebMercator**| Y | Y | Y | Y | Y | Y | Y | --  | Y | Y | Y | Y | Y |
| **UPS**        | Y | Y | Y | Y | Y | Y | Y | Y | --  | Y | Y | Y | Y |
| **StatePlane** | Y | Y | Y | Y | Y | Y | Y | Y | Y | --  | Y | Y | Y |
| **BNG**        | Y | Y | Y | Y | Y | Y | Y | Y | Y | Y | --  | Y | Y |
| **GH36**       | Y | Y | Y | Y | Y | Y | Y | Y | Y | Y | Y | --  | Y |
| **GH**         | Y | Y | Y | Y | Y | Y | Y | Y | Y | Y | Y | Y | -- |

## Universal Distance and Bearing Calculations

All coordinate systems support universal distance calculations via `distance_to` (Vincenty great-circle) and `straight_line_distance_to` (ECEF Euclidean). These methods work across different coordinate types -- for example, computing the distance from a UTM coordinate to an MGRS coordinate. Class-level methods `GCS.distance_between` and `GCS.straight_line_distance_between` compute consecutive chain distances across a sequence of coordinates.

All coordinate systems also support universal bearing calculations via `bearing_to` (great-circle forward azimuth) and `elevation_to` (vertical look angle). These return `Bearing` and `Float` objects respectively. The class-level method `GCS.bearing_between` computes consecutive chain bearings.

See the [Conversions Reference](../reference/conversions.md#distance-calculations) for details on distances and [Bearing Calculations](../reference/conversions.md#bearing-calculations) for bearings.

> **Note:** ENU and NED are relative systems and must be converted to an absolute system (e.g., LLA) before using universal distance and bearing methods. They retain `local_bearing_to` and `horizontal_distance_to` for tangent-plane operations. NED additionally provides `local_elevation_angle_to`.

## Conversion Paths

Conversions typically route through **LLA** or **ECEF** as intermediate steps:

- **LLA** serves as the universal hub. Most systems convert to LLA first, then from LLA to the target system.
- **ECEF** is the intermediate for local tangent plane systems (ENU, NED), since the rotation from global Cartesian to local frames is straightforward in ECEF.
- **ENU and NED** convert between each other directly by reordering axes and inverting the vertical component.
- **MGRS and USNG** route through UTM, which in turn routes through LLA.
- **WebMercator, UPS, BNG, StatePlane, GH36, and GH** all convert through LLA.

For example, converting from BNG to NED follows the chain: `BNG -> LLA -> ECEF -> ENU -> NED`. The gem handles this automatically when you call a conversion method.
