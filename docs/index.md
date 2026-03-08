# Geodetic

<table>
<tr>
<td width="50%" align="center" valign="top">
<img src="assets/images/geodetic.jpg" alt="Geodetic"><br>
<em>"Convert coordinates. Map the world."</em>
</td>
<td width="50%" valign="top">
<h2>Key Features</h2>
<lu>
<li><strong>15 Coordinate Systems</strong> - LLA, ECEF, UTM, ENU, NED, MGRS, USNG, Web Mercator, UPS, State Plane, BNG, GH36, GH, HAM, OLC<br>
<li><strong>Full Bidirectional Conversions</strong> - Every system converts to and from every other system<br>
<li><strong>Distance Calculations</strong> - Vincenty great-circle and straight-line with unit tracking<br>
<li><strong>Bearing Calculations</strong> - Forward azimuth, back azimuth, compass directions, elevation angles<br>
<li><strong>Geoid Height Support</strong> - EGM96, EGM2008, GEOID18, GEOID12B models<br>
<li><strong>Geographic Areas</strong> - Circle, Polygon, and Rectangle with point-in-area tests<br>
<li><strong>Validated Setters</strong> - Type coercion and range validation on all coordinate attributes<br>
<li><strong>Serialization</strong> - to_s(precision), to_a, from_string, from_array, DMS format<br>
<li><strong>Multiple Datums</strong> - WGS84, Clarke 1866, GRS 1980, Airy 1830, and more<br>
<li><strong>Immutable Value Types</strong> - Distance and Bearing with arithmetic and comparison
</lu>
</td>
</tr>
</table>

Geodetic is a Ruby gem for converting between geodetic coordinate systems. It provides a clean, consistent API for working with 15 coordinate systems, 16 geodetic datums, geoid height calculations, and geographic area computations.

## Coordinate Systems

Geodetic supports full bidirectional conversion between all 15 coordinate systems:

| System | Class | Description |
|--------|-------|-------------|
| **LLA** | `Geodetic::Coordinate::LLA` | Latitude, Longitude, Altitude |
| **ECEF** | `Geodetic::Coordinate::ECEF` | Earth-Centered, Earth-Fixed (X, Y, Z) |
| **UTM** | `Geodetic::Coordinate::UTM` | Universal Transverse Mercator |
| **ENU** | `Geodetic::Coordinate::ENU` | East, North, Up (local tangent plane) |
| **NED** | `Geodetic::Coordinate::NED` | North, East, Down (local tangent plane) |
| **MGRS** | `Geodetic::Coordinate::MGRS` | Military Grid Reference System |
| **USNG** | `Geodetic::Coordinate::USNG` | United States National Grid |
| **WebMercator** | `Geodetic::Coordinate::WebMercator` | Web Mercator projection (EPSG:3857) |
| **UPS** | `Geodetic::Coordinate::UPS` | Universal Polar Stereographic |
| **StatePlane** | `Geodetic::Coordinate::StatePlane` | State Plane Coordinate System |
| **BNG** | `Geodetic::Coordinate::BNG` | British National Grid |
| **GH36** | `Geodetic::Coordinate::GH36` | Geohash-36 (spatial hash, URL-friendly) |
| **GH** | `Geodetic::Coordinate::GH` | Geohash base-32 (standard geohash, widely supported) |
| **HAM** | `Geodetic::Coordinate::HAM` | Maidenhead Locator System (amateur radio grid squares) |
| **OLC** | `Geodetic::Coordinate::OLC` | Open Location Code / Plus Codes (Google's location encoding) |

## Additional Features

- **16 geodetic datums** -- WGS84, GRS 1980, Clarke 1866, Airy 1830, Bessel 1841, and more. All conversion methods accept an optional datum parameter, defaulting to WGS84.
- **Geoid height calculations** -- Convert between ellipsoidal and orthometric heights using models such as EGM96, EGM2008, GEOID18, and GEOID12B.
- **Geographic areas** -- `Geodetic::Areas::Circle`, `Geodetic::Areas::Polygon`, and `Geodetic::Areas::Rectangle` for point-in-area testing.

## Design Principles

- All constructors use **keyword arguments** for clarity.
- Every coordinate system supports **serialization** via `to_s` and `to_a`, and **deserialization** via `from_string` and `from_array`.
- Conversions are available as instance methods (`to_ecef`, `to_utm`, etc.) and class-level factory methods (`from_ecef`, `from_utm`, etc.).

## Quick Example

```ruby
require "geodetic"

# Create an LLA coordinate (Seattle Space Needle)
lla = Geodetic::Coordinate::LLA.new(lat: 47.6205, lng: -122.3493, alt: 184.0)

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
