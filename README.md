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

### GCS Shorthand

`GCS` is a top-level alias for `Geodetic::Coordinates`, providing a concise way to create and work with coordinates:

```ruby
require "geodetic"

# Use GCS as a shorthand for Geodetic::Coordinates
seattle = GCS::LLA.new(lat: 47.6205, lng: -122.3493, alt: 184.0)
ecef = GCS::ECEF.new(x: -2304643.57, y: -3638650.07, z: 4688674.43)
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

All coordinate classes support `to_s`, `to_a`, `from_string`, and `from_array`. The `to_s` method accepts an optional precision parameter controlling the number of decimal places:

```ruby
lla = Coordinates::LLA.new(lat: 47.6205, lng: -122.3493, alt: 184.0)

lla.to_s                            # => "47.620500, -122.349300, 184.00"
lla.to_s(3)                         # => "47.620, -122.349, 184.00"
lla.to_s(0)                         # => "48, -122, 184"
lla.to_a                            # => [47.6205, -122.3493, 184.0]

Coordinates::LLA.from_string("47.6205, -122.3493, 184.0")
Coordinates::LLA.from_array([47.6205, -122.3493, 184.0])
```

Default precisions by class: LLA=6, Bearing=4, all others=2. Passing `0` returns integers.

### Validated Setters

All coordinate classes provide setter methods with type coercion and validation:

```ruby
lla = Coordinates::LLA.new(lat: 47.0, lng: -122.0, alt: 100.0)
lla.lat = 48.0                     # validates -90..90
lla.lng = -121.0                   # validates -180..180
lla.alt = 200.0                    # no range constraint
lla.lat = 91.0                     # => ArgumentError

utm = Coordinates::UTM.new(easting: 500000.0, northing: 5000000.0, zone: 10, hemisphere: 'N')
utm.zone = 15                      # validates 1..60
utm.hemisphere = 'S'               # validates 'N' or 'S'
utm.easting = -1.0                 # => ArgumentError

# UPS cross-validates hemisphere/zone combinations
ups = Coordinates::UPS.new(hemisphere: 'N', zone: 'Y')
ups.zone = 'Z'                     # valid for hemisphere 'N'
ups.zone = 'A'                     # => ArgumentError (rolls back)

# BNG auto-updates grid_ref when easting/northing change
bng = Coordinates::BNG.new(easting: 530000, northing: 180000)
bng.easting = 430000               # grid_ref automatically recalculated
```

ECEF, ENU, NED, and WebMercator setters coerce to float with no range constraints. MGRS, USNG, Distance, and Bearing are immutable.

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

### Distance Calculations

Universal distance methods work across all coordinate types and return `Distance` objects with unit tracking and conversion.

**Instance method `distance_to`** — Vincenty great-circle distance:

```ruby
seattle = GCS::LLA.new(lat: 47.6205, lng: -122.3493, alt: 0.0)
portland = GCS::LLA.new(lat: 45.5152, lng: -122.6784, alt: 0.0)
sf = GCS::LLA.new(lat: 37.7749, lng: -122.4194, alt: 0.0)

d = seattle.distance_to(portland)         # => Distance (meters)
d.meters                                  # => 235393.17
d.to_km.to_f                             # => 235.39
d.to_mi.to_f                             # => 146.28

seattle.distance_to(portland, sf)         # => [Distance, Distance] (radial)
seattle.distance_to([portland, sf])       # => [Distance, Distance] (radial)
```

**Class method `distance_between`** — consecutive chain distances:

```ruby
GCS.distance_between(seattle, portland)        # => Distance
GCS.distance_between(seattle, portland, sf)    # => [Distance, Distance] (chain)
GCS.distance_between([seattle, portland, sf])  # => [Distance, Distance] (chain)
```

**Straight-line (ECEF Euclidean) versions:**

```ruby
seattle.straight_line_distance_to(portland)              # => Distance
GCS.straight_line_distance_between(seattle, portland)    # => Distance
```

**Cross-system distances** — works between any coordinate types:

```ruby
utm = seattle.to_utm
mgrs = GCS::MGRS.from_lla(portland)
utm.distance_to(mgrs)    # => Distance
```

> **Note:** ENU and NED are relative coordinate systems and must be converted to an absolute system before distance and bearing calculations. They retain `local_bearing_to`, `horizontal_distance_to`, and other local methods for tangent-plane operations.

### Bearing Calculations

Universal bearing methods work across all coordinate types and return `Bearing` objects.

**Instance method `bearing_to`** — great-circle forward azimuth:

```ruby
seattle = GCS::LLA.new(lat: 47.6205, lng: -122.3493, alt: 0.0)
portland = GCS::LLA.new(lat: 45.5152, lng: -122.6784, alt: 0.0)

b = seattle.bearing_to(portland)   # => Bearing
b.degrees                          # => 188.2
b.to_radians                      # => 3.28...
b.to_compass                      # => "S"
b.to_compass(points: 8)           # => "S"
b.reverse                         # => Bearing (back azimuth)
b.to_s                            # => "188.2036°"
```

**Instance method `elevation_to`** — vertical look angle:

```ruby
a = GCS::LLA.new(lat: 47.62, lng: -122.35, alt: 0.0)
b = GCS::LLA.new(lat: 47.62, lng: -122.35, alt: 5000.0)

a.elevation_to(b)   # => 89.9... (degrees, nearly straight up)
```

**Class method `bearing_between`** — consecutive chain bearings:

```ruby
GCS.bearing_between(seattle, portland)        # => Bearing
GCS.bearing_between(seattle, portland, sf)    # => [Bearing, Bearing] (chain)
```

**Cross-system bearings** — works between any coordinate types:

```ruby
utm = seattle.to_utm
mgrs = GCS::MGRS.from_lla(portland)
utm.bearing_to(mgrs)    # => Bearing
```

### Bearing Class

`Bearing` wraps an azimuth angle (0-360°) with compass and radian conversions.

```ruby
b = Geodetic::Bearing.new(225)
b.degrees                   # => 225.0
b.to_radians                # => 3.926...
b.reverse                   # => Bearing (45°)
b.to_compass(points: 4)     # => "W"
b.to_compass(points: 8)     # => "SW"
b.to_compass(points: 16)    # => "SW"
b.to_s                      # => "225.0000°"
b.to_s(1)                   # => "225.0°"
b.to_s(0)                   # => "225°"

# Arithmetic
b + 10                       # => Bearing (235°)
b - 10                       # => Bearing (215°)
Bearing.new(90) - Bearing.new(45)  # => 45.0 (Float, angular difference)
```

### Distance Class

`Distance` tracks values internally in meters with a configurable display unit. All distance methods return `Distance` objects.

**Construction:**

```ruby
d = Geodetic::Distance.new(1000)          # 1000 meters
d = Geodetic::Distance.km(5)             # 5 kilometers
d = Geodetic::Distance.mi(3)             # 3 miles
d = Geodetic::Distance.ft(5280)          # 5280 feet
d = Geodetic::Distance.nmi(1)            # 1 nautical mile
```

**Unit conversions** — return a new `Distance` with the same meters, different display unit:

```ruby
d = Geodetic::Distance.new(1609.344)
d.to_km.to_f     # => 1.609344
d.to_mi.to_f     # => 1.0
d.to_ft.to_f     # => 5280.0
d.to_nmi.to_f    # => 0.869...
d.meters          # => 1609.344 (always available)
```

**Display and formatting:**

```ruby
d = Geodetic::Distance.new(5000).to_km
d.to_f     # => 5.0 (in display unit)
d.to_i     # => 5
d.to_s     # => "5.00 km"
d.to_s(1)  # => "5.0 km"
d.to_s(0)  # => "5 km"
d.inspect  # => "#<Geodetic::Distance 5.00 km (5000.0 m)>"
```

**Arithmetic** — results always in meters:

```ruby
d1 = Geodetic::Distance.km(5)
d2 = Geodetic::Distance.mi(3)

(d1 + d2).meters      # => 9828.032 (5km + 3mi in meters)
(d1 - d2).meters      # => 171.968
(d1 * 2).meters       # => 10000.0
(d1 / 2).meters       # => 2500.0
d1 / d2               # => 1.034... (Float ratio)

# Numeric constants use the display unit
d = Geodetic::Distance.new(5000).to_km   # 5 km
(d + 3).meters        # => 8000.0 (3 km added)
```

**Comparison:**

```ruby
Geodetic::Distance.km(1) == Geodetic::Distance.new(1000)  # => true
Geodetic::Distance.km(5) > Geodetic::Distance.mi(2)       # => true
```

**Supported units:** meters (m), kilometers (km), centimeters (cm), millimeters (mm), miles (mi), yards (yd), feet (ft), inches (in), nautical_miles (nmi)

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
