# Geodetic

A Ruby gem for converting between geodetic coordinate systems. Supports 11 coordinate systems with full bidirectional conversions, plus geoid height calculations and geographic area operations.

## Coordinate Systems

| Class | Description |
|-------|-------------|
| `Coordinates::LLA` | Latitude, Longitude, Altitude (degrees/meters) |
| `Coordinates::ECEF` | Earth-Centered, Earth-Fixed (meters) |
| `Coordinates::UTM` | Universal Transverse Mercator |
| `Coordinates::ENU` | East, North, Up (local tangent plane) |
| `Coordinates::NED` | North, East, Down (local tangent plane) |
| `Coordinates::MGRS` | Military Grid Reference System |
| `Coordinates::USNG` | US National Grid |
| `Coordinates::WebMercator` | Web Mercator / EPSG:3857 |
| `Coordinates::UPS` | Universal Polar Stereographic |
| `Coordinates::StatePlane` | US State Plane Coordinate System |
| `Coordinates::BNG` | British National Grid |

## Installation

Add to your Gemfile:

```ruby
gem "geodetic"
```

Or install directly:

```bash
gem install geodetic
```

## Usage

### Basic Coordinate Creation

All constructors use keyword arguments:

```ruby
require "geodetic"

include Geodetic

lla = Coordinates::LLA.new(lat: 47.6205, lng: -122.3493, alt: 184.0)
ecef = Coordinates::ECEF.new(x: -2304643.57, y: -3638650.07, z: 4688674.43)
utm = Coordinates::UTM.new(easting: 548894.0, northing: 5272748.0, altitude: 184.0, zone: 10, hemisphere: "N")
enu = Coordinates::ENU.new(e: 100.0, n: 200.0, u: 50.0)
ned = Coordinates::NED.new(n: 200.0, e: 100.0, d: -50.0)
```

### Coordinate Conversions

Every coordinate system can convert to and from every other system:

```ruby
lla = Coordinates::LLA.new(lat: 47.6205, lng: -122.3493, alt: 184.0)

# LLA to other systems
ecef = lla.to_ecef
utm  = lla.to_utm
wm   = Coordinates::WebMercator.from_lla(lla)
mgrs = Coordinates::MGRS.from_lla(lla)

# Convert back
lla_roundtrip = ecef.to_lla

# Local coordinate systems require a reference point
reference = Coordinates::LLA.new(lat: 47.62, lng: -122.35, alt: 0.0)
enu = lla.to_enu(reference)
ned = lla.to_ned(reference)
```

### Serialization

All coordinate classes support `to_s`, `to_a`, `from_string`, and `from_array`:

```ruby
lla = Coordinates::LLA.new(lat: 47.6205, lng: -122.3493, alt: 184.0)

lla.to_s                            # => "47.6205, -122.3493, 184.0"
lla.to_a                            # => [47.6205, -122.3493, 184.0]

Coordinates::LLA.from_string("47.6205, -122.3493, 184.0")
Coordinates::LLA.from_array([47.6205, -122.3493, 184.0])
```

### DMS (Degrees, Minutes, Seconds)

```ruby
lla = Coordinates::LLA.new(lat: 37.7749, lng: -122.4192, alt: 15.0)
lla.to_dms    # => "37° 46' 29.64\" N, 122° 25' 9.12\" W, 15.00 m"

Coordinates::LLA.from_dms("37° 46' 29.64\" N, 122° 25' 9.12\" W, 15.00 m")
```

### String-Based Coordinate Systems

MGRS and USNG use string representations:

```ruby
mgrs = Coordinates::MGRS.new(mgrs_string: "18SUJ2337006519")
mgrs = Coordinates::MGRS.from_string("18SUJ2337006519")
mgrs.to_s    # => "18SUJ2337006519"

usng = Coordinates::USNG.new(usng_string: "18T WL 12345 67890")
usng = Coordinates::USNG.from_string("18T WL 12345 67890")
usng.to_s    # => "18T WL 12345 67890"
```

### Distance and Bearing

```ruby
p1 = Coordinates::ENU.new(e: 0.0, n: 0.0, u: 0.0)
p2 = Coordinates::ENU.new(e: 300.0, n: 400.0, u: 0.0)

p1.distance_to(p2)             # => 500.0
p1.horizontal_distance_to(p2)  # => 500.0
p1.bearing_to(p2)              # => 36.87 (degrees from north)
```

### Datums

```ruby
wgs84 = Datum.new(name: "WGS84")
wgs84.a     # => 6378137.0 (semi-major axis)
wgs84.e2    # => 0.00669437999014132 (eccentricity squared)

# Use a different datum for conversions
nad27 = Datum.new(name: "CLARKE_1866")
ecef = lla.to_ecef(nad27)

# List available datums
Datum.list
```

### Geoid Height

```ruby
geoid = GeoidHeight.new(geoid_model: "EGM2008")

# Get geoid height at a location
geoid.geoid_height_at(47.6205, -122.3493)

# Convert between height datums
geoid.ellipsoidal_to_orthometric(47.6205, -122.3493, 184.0)
geoid.orthometric_to_ellipsoidal(47.6205, -122.3493, 150.0)

# Convert between vertical datums
geoid.convert_vertical_datum(47.6205, -122.3493, 184.0, "HAE", "NAVD88")
```

The `GeoidHeightSupport` module is mixed into LLA for convenience:

```ruby
lla = Coordinates::LLA.new(lat: 47.6205, lng: -122.3493, alt: 184.0)
lla.geoid_height              # => geoid undulation in meters
lla.orthometric_height        # => height above mean sea level
```

### Geographic Areas

```ruby
# Circle area
center = Coordinates::LLA.new(lat: 47.6205, lng: -122.3493, alt: 0.0)
circle = Areas::Circle.new(centroid: center, radius: 1000.0)  # 1km radius

# Polygon area
points = [
  Coordinates::LLA.new(lat: 47.60, lng: -122.35, alt: 0.0),
  Coordinates::LLA.new(lat: 47.63, lng: -122.35, alt: 0.0),
  Coordinates::LLA.new(lat: 47.63, lng: -122.33, alt: 0.0),
  Coordinates::LLA.new(lat: 47.60, lng: -122.33, alt: 0.0),
]
polygon = Areas::Polygon.new(boundary: points)
polygon.centroid    # => computed centroid as LLA
```

### Web Mercator Tile Coordinates

```ruby
wm = Coordinates::WebMercator.from_lla(lla)
wm.to_tile_coordinates(15)     # => [x_tile, y_tile, zoom]
wm.to_pixel_coordinates(15)    # => [x_pixel, y_pixel, zoom]

Coordinates::WebMercator.from_tile_coordinates(5241, 11438, 15)
```

## Available Datums

Airy 1830, Modified Airy, Australian National, Bessel 1841, Clarke 1866, Clarke 1880, Everest (India 1830), Everest (Brunei & E.Malaysia), Everest (W.Malaysia & Singapore), GRS 1980, Helmert 1906, Hough 1960, International 1924, South American 1969, WGS72, WGS84

## Development

```bash
bin/setup          # Install dependencies
rake test          # Run tests
bin/console        # Interactive console
```

## License

Available as open source under the [MIT License](https://opensource.org/licenses/MIT).
