# Geodetic

Geodetic is a Ruby gem for converting between geodetic coordinate systems. It provides a clean, consistent API for working with 11 coordinate systems, 16 geodetic datums, geoid height calculations, and geographic area computations.

## Coordinate Systems

Geodetic supports full bidirectional conversion between all 11 coordinate systems:

| System | Class | Description |
|--------|-------|-------------|
| **LLA** | `Geodetic::Coordinates::LLA` | Latitude, Longitude, Altitude |
| **ECEF** | `Geodetic::Coordinates::ECEF` | Earth-Centered, Earth-Fixed (X, Y, Z) |
| **UTM** | `Geodetic::Coordinates::UTM` | Universal Transverse Mercator |
| **ENU** | `Geodetic::Coordinates::ENU` | East, North, Up (local tangent plane) |
| **NED** | `Geodetic::Coordinates::NED` | North, East, Down (local tangent plane) |
| **MGRS** | `Geodetic::Coordinates::MGRS` | Military Grid Reference System |
| **USNG** | `Geodetic::Coordinates::USNG` | United States National Grid |
| **WebMercator** | `Geodetic::Coordinates::WebMercator` | Web Mercator projection (EPSG:3857) |
| **UPS** | `Geodetic::Coordinates::UPS` | Universal Polar Stereographic |
| **StatePlane** | `Geodetic::Coordinates::StatePlane` | State Plane Coordinate System |
| **BNG** | `Geodetic::Coordinates::BNG` | British National Grid |

## Additional Features

- **16 geodetic datums** -- WGS84, GRS 1980, Clarke 1866, Airy 1830, Bessel 1841, and more. All conversion methods accept an optional datum parameter, defaulting to WGS84.
- **Geoid height calculations** -- Convert between ellipsoidal and orthometric heights using models such as EGM96, EGM2008, GEOID18, and GEOID12B.
- **Geographic areas** -- `Geodetic::Areas::Circle` and `Geodetic::Areas::Polygon` for point-in-area testing.

## Design Principles

- All constructors use **keyword arguments** for clarity.
- Every coordinate system supports **serialization** via `to_s` and `to_a`, and **deserialization** via `from_string` and `from_array`.
- Conversions are available as instance methods (`to_ecef`, `to_utm`, etc.) and class-level factory methods (`from_ecef`, `from_utm`, etc.).

## Quick Example

```ruby
require "geodetic"

# Create an LLA coordinate (Seattle Space Needle)
lla = Geodetic::Coordinates::LLA.new(lat: 47.6205, lng: -122.3493, alt: 184.0)

# Convert to ECEF
ecef = lla.to_ecef
puts ecef.to_s
#=> "-2689653.22..., -4251180.82..., 4696587.81..."

# Convert back to LLA
lla_again = ecef.to_lla
puts lla_again.to_s
#=> "47.6205, -122.3493, 184.0"
```

## Documentation

- [Getting Started: Installation](getting-started/installation.md)
- [Getting Started: Quick Start](getting-started/quick-start.md)
