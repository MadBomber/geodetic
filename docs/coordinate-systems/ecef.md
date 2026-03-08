# Geodetic::Coordinate::ECEF

Earth-Centered, Earth-Fixed -- a Cartesian coordinate system with its origin at the center of mass of the Earth. The X axis points toward the intersection of the Prime Meridian and the Equator, the Y axis points toward 90 degrees East longitude on the Equator, and the Z axis points toward the North Pole. All values are in meters.

ECEF is useful for satellite positioning, radar tracking, and any application requiring a simple Cartesian frame tied to the rotating Earth.

## Constructor

```ruby
Geodetic::Coordinate::ECEF.new(x: 0.0, y: 0.0, z: 0.0)
```

| Parameter | Type  | Default | Description                     |
|-----------|-------|---------|---------------------------------|
| `x`       | Float | `0.0`   | X coordinate in meters          |
| `y`       | Float | `0.0`   | Y coordinate in meters          |
| `z`       | Float | `0.0`   | Z coordinate in meters          |

All values are coerced to `Float` via `.to_f`. There is no range validation -- any real-valued triple is accepted.

## Attributes

| Attribute | Access     |
|-----------|------------|
| `x`       | read/write |
| `y`       | read/write |
| `z`       | read/write |

## Conversions

All conversion methods accept an optional `datum` parameter (defaults to `Geodetic::WGS84`).

### to_lla(datum = WGS84)

Converts to geodetic Latitude, Longitude, Altitude coordinates using an iterative algorithm. The iteration converges when both latitude and altitude changes are below `1e-12`, with a maximum of 100 iterations.

```ruby
ecef = Geodetic::Coordinate::ECEF.new(x: 1130730.0, y: -4828583.0, z: 3991570.0)
lla = ecef.to_lla
# => Geodetic::Coordinate::LLA
```

### ECEF.from_lla(lla, datum = WGS84)

Creates an ECEF from an LLA instance. Raises `ArgumentError` if the argument is not an `LLA`.

```ruby
ecef = Geodetic::Coordinate::ECEF.from_lla(lla)
```

### to_utm(datum = WGS84)

Converts to Universal Transverse Mercator coordinates. Internally converts to LLA first, then to UTM.

```ruby
utm = ecef.to_utm
# => Geodetic::Coordinate::UTM
```

### ECEF.from_utm(utm, datum = WGS84)

Creates an ECEF from a UTM instance. Raises `ArgumentError` if the argument is not a `UTM`.

### to_enu(reference_ecef, reference_lla = nil)

Converts to East-North-Up local tangent plane coordinates relative to a reference ECEF position. If `reference_lla` is not provided, it is computed from `reference_ecef` via `to_lla`.

```ruby
ref_ecef = Geodetic::Coordinate::ECEF.new(x: 1130730.0, y: -4828583.0, z: 3991570.0)
point_ecef = Geodetic::Coordinate::ECEF.new(x: 1130740.0, y: -4828573.0, z: 3991580.0)
enu = point_ecef.to_enu(ref_ecef)
# => Geodetic::Coordinate::ENU
```

Raises `ArgumentError` if `reference_ecef` is not an `ECEF`.

### ECEF.from_enu(enu, reference_ecef, reference_lla = nil)

Creates an ECEF from an ENU instance and a reference ECEF origin. Raises `ArgumentError` if the arguments are not the expected types.

### to_ned(reference_ecef, reference_lla = nil)

Converts to North-East-Down local tangent plane coordinates. Internally converts to ENU first, then swaps axes to NED.

```ruby
ned = point_ecef.to_ned(ref_ecef)
# => Geodetic::Coordinate::NED
```

### ECEF.from_ned(ned, reference_ecef, reference_lla = nil)

Creates an ECEF from a NED instance and a reference ECEF origin. Raises `ArgumentError` if the arguments are not the expected types.

## Serialization

### to_s

Returns a comma-separated string of `x, y, z`.

```ruby
ecef = Geodetic::Coordinate::ECEF.new(x: 1130730.0, y: -4828583.0, z: 3991570.0)
ecef.to_s
# => "1130730.0, -4828583.0, 3991570.0"
```

### to_a

Returns a three-element array `[x, y, z]`.

```ruby
ecef.to_a
# => [1130730.0, -4828583.0, 3991570.0]
```

### ECEF.from_string(string)

Parses a comma-separated string into an ECEF.

```ruby
ecef = Geodetic::Coordinate::ECEF.from_string("1130730.0, -4828583.0, 3991570.0")
```

### ECEF.from_array(array)

Creates an ECEF from a three-element array `[x, y, z]`.

```ruby
ecef = Geodetic::Coordinate::ECEF.from_array([1130730.0, -4828583.0, 3991570.0])
```

## Additional Methods

### ==(other)

Compares two ECEF instances for approximate equality. Returns `true` if the absolute difference for each of `x`, `y`, and `z` is `<= 1e-6` meters. Returns `false` if `other` is not an `ECEF`.

```ruby
a = Geodetic::Coordinate::ECEF.new(x: 1130730.0, y: -4828583.0, z: 3991570.0)
b = Geodetic::Coordinate::ECEF.new(x: 1130730.0, y: -4828583.0, z: 3991570.0)
a == b
# => true
```

### distance_to(other, *others)

Computes the Vincenty great-circle distance to one or more other coordinates. Accepts any coordinate type (coordinates are converted to LLA internally). Returns a `Distance` for a single target or an Array of `Distance` objects for multiple targets (radial distances from the receiver).

```ruby
a = Geodetic::Coordinate::ECEF.new(x: 1130730.0, y: -4828583.0, z: 3991570.0)
b = Geodetic::Coordinate::ECEF.new(x: 1130740.0, y: -4828573.0, z: 3991580.0)
a.distance_to(b)
# => Distance (meters, great-circle distance)
```

### straight_line_distance_to(other, *others)

Computes the Euclidean (straight-line) distance between two points in ECEF space. Accepts any coordinate type (coordinates are converted to ECEF internally). Returns a `Distance` for a single target or an Array of `Distance` objects for multiple targets.

```ruby
a.straight_line_distance_to(b)
# => Distance (17.320508075688775 m)
```

## Code Examples

### Round-trip conversion

```ruby
require 'geodetic'

# Create an ECEF coordinate
ecef = Geodetic::Coordinate::ECEF.new(x: 1130730.0, y: -4828583.0, z: 3991570.0)

# Convert to LLA and back
lla = ecef.to_lla
ecef_roundtrip = lla.to_ecef
ecef == ecef_roundtrip
# => true
```

### Distance between two points

```ruby
station_a = Geodetic::Coordinate::ECEF.new(x: 1130730.0, y: -4828583.0, z: 3991570.0)
station_b = Geodetic::Coordinate::ECEF.new(x: 1131000.0, y: -4828300.0, z: 3991800.0)

# Great-circle distance (Vincenty)
distance = station_a.distance_to(station_b)
puts "Great-circle distance: #{distance.meters} meters"

# Straight-line (Euclidean) distance
straight = station_a.straight_line_distance_to(station_b)
puts "Straight-line distance: #{straight.meters} meters"
```

### Local tangent plane from ECEF

```ruby
origin = Geodetic::Coordinate::ECEF.new(x: 1130730.0, y: -4828583.0, z: 3991570.0)
target = Geodetic::Coordinate::ECEF.new(x: 1130740.0, y: -4828573.0, z: 3991580.0)

# Provide reference LLA to avoid recomputing it
ref_lla = origin.to_lla

enu = target.to_enu(origin, ref_lla)
ned = target.to_ned(origin, ref_lla)
```

### Using a non-default datum

```ruby
clarke66 = Geodetic::Datum.new(name: 'CLARKE_1866')
ecef = Geodetic::Coordinate::ECEF.new(x: 1130730.0, y: -4828583.0, z: 3991570.0)
lla = ecef.to_lla(clarke66)
```
