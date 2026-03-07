# Geodetic::Coordinates::UTM

Universal Transverse Mercator -- a projected coordinate system that divides the Earth into 60 longitudinal zones (each 6 degrees wide) and two hemispheres (North and South). Positions within each zone are expressed as easting and northing distances in meters from the zone's origin. UTM is widely used in military, engineering, and surveying applications because it provides a flat, metric grid that minimizes distortion within each zone.

## Constructor

```ruby
Geodetic::Coordinates::UTM.new(easting: 0.0, northing: 0.0, altitude: 0.0, zone: 1, hemisphere: 'N')
```

| Parameter    | Type    | Default | Description                                 |
|--------------|---------|---------|---------------------------------------------|
| `easting`    | Float   | `0.0`   | Easting in meters (must be >= 0)            |
| `northing`   | Float   | `0.0`   | Northing in meters (must be >= 0)           |
| `altitude`   | Float   | `0.0`   | Altitude in meters above the ellipsoid      |
| `zone`       | Integer | `1`     | UTM zone number (1..60)                     |
| `hemisphere` | String  | `'N'`   | Hemisphere: `'N'` (North) or `'S'` (South) |

Numeric values are coerced via `.to_f` / `.to_i`. The hemisphere string is uppercased automatically.

### Validation

The constructor raises `ArgumentError` if:

- `zone` is outside the range `1..60`
- `hemisphere` is not `'N'` or `'S'`
- `easting` is negative
- `northing` is negative

## Attributes

| Attribute    | Alias | Access     |
|--------------|-------|------------|
| `easting`    | `x`   | read/write |
| `northing`   | `y`   | read/write |
| `altitude`   | `z`   | read/write |
| `zone`       | --    | read/write |
| `hemisphere` | --    | read/write |

## Conversions

All conversion methods accept an optional `datum` parameter (defaults to `Geodetic::WGS84`).

### to_lla(datum = WGS84)

Converts to geodetic Latitude, Longitude, Altitude coordinates. Uses a series expansion for the inverse UTM projection.

```ruby
utm = Geodetic::Coordinates::UTM.new(easting: 580000.0, northing: 4510000.0, zone: 18, hemisphere: 'N')
lla = utm.to_lla
# => Geodetic::Coordinates::LLA
```

### UTM.from_lla(lla, datum = WGS84)

Creates a UTM from an LLA instance. The zone and hemisphere are computed automatically. Raises `ArgumentError` if the argument is not an `LLA`.

```ruby
utm = Geodetic::Coordinates::UTM.from_lla(lla)
```

### to_ecef(datum = WGS84)

Converts to Earth-Centered, Earth-Fixed Cartesian coordinates. Internally converts to LLA first, then to ECEF.

```ruby
ecef = utm.to_ecef
# => Geodetic::Coordinates::ECEF
```

### UTM.from_ecef(ecef, datum = WGS84)

Creates a UTM from an ECEF instance. Raises `ArgumentError` if the argument is not an `ECEF`.

### to_enu(reference_lla, datum = WGS84)

Converts to East-North-Up local tangent plane coordinates relative to a reference LLA position.

```ruby
origin = Geodetic::Coordinates::LLA.new(lat: 40.7128, lng: -74.0060, alt: 10.0)
enu = utm.to_enu(origin)
# => Geodetic::Coordinates::ENU
```

Raises `ArgumentError` if `reference_lla` is not an `LLA`.

### UTM.from_enu(enu, reference_lla, datum = WGS84)

Creates a UTM from an ENU instance and a reference LLA origin. Raises `ArgumentError` if the arguments are not the expected types.

### to_ned(reference_lla, datum = WGS84)

Converts to North-East-Down local tangent plane coordinates relative to a reference LLA position.

```ruby
ned = utm.to_ned(origin)
# => Geodetic::Coordinates::NED
```

Raises `ArgumentError` if `reference_lla` is not an `LLA`.

### UTM.from_ned(ned, reference_lla, datum = WGS84)

Creates a UTM from a NED instance and a reference LLA origin. Raises `ArgumentError` if the arguments are not the expected types.

## Serialization

### to_s

Returns a comma-separated string of `easting, northing, altitude, zone, hemisphere`.

```ruby
utm = Geodetic::Coordinates::UTM.new(easting: 580000.0, northing: 4510000.0, altitude: 10.0, zone: 18, hemisphere: 'N')
utm.to_s
# => "580000.0, 4510000.0, 10.0, 18, N"
```

### to_a

Returns a five-element array `[easting, northing, altitude, zone, hemisphere]`.

```ruby
utm.to_a
# => [580000.0, 4510000.0, 10.0, 18, "N"]
```

### UTM.from_string(string)

Parses a comma-separated string into a UTM.

```ruby
utm = Geodetic::Coordinates::UTM.from_string("580000.0, 4510000.0, 10.0, 18, N")
```

### UTM.from_array(array)

Creates a UTM from a five-element array `[easting, northing, altitude, zone, hemisphere]`.

```ruby
utm = Geodetic::Coordinates::UTM.from_array([580000.0, 4510000.0, 10.0, 18, "N"])
```

## Additional Methods

### ==(other)

Compares two UTM instances for approximate equality. Returns `true` if:

- `|easting difference| <= 1e-6`
- `|northing difference| <= 1e-6`
- `|altitude difference| <= 1e-6`
- `zone` values are equal
- `hemisphere` values are equal

Returns `false` if `other` is not a `UTM`.

```ruby
a = Geodetic::Coordinates::UTM.new(easting: 580000.0, northing: 4510000.0, zone: 18, hemisphere: 'N')
b = Geodetic::Coordinates::UTM.new(easting: 580000.0, northing: 4510000.0, zone: 18, hemisphere: 'N')
a == b
# => true
```

### distance_to(other, *others)

Computes the Vincenty great-circle distance to one or more other coordinates. Works across UTM zones and across different coordinate types (coordinates are converted to LLA internally). Returns a `Distance` for a single target or an Array of `Distance` objects for multiple targets (radial distances from the receiver).

```ruby
a = Geodetic::Coordinates::UTM.new(easting: 580000.0, northing: 4510000.0, altitude: 10.0, zone: 18, hemisphere: 'N')
b = Geodetic::Coordinates::UTM.new(easting: 580100.0, northing: 4510200.0, altitude: 15.0, zone: 18, hemisphere: 'N')
a.distance_to(b)
# => Distance (meters, great-circle distance)
```

### straight_line_distance_to(other, *others)

Computes the Euclidean (straight-line) distance between two points in ECEF space. Accepts any coordinate type. Returns a `Distance` for a single target or an Array of `Distance` objects for multiple targets.

```ruby
a.straight_line_distance_to(b)
# => Distance (meters)
```

### same_zone?(other)

Returns `true` if both UTM instances share the same zone number and hemisphere.

```ruby
a = Geodetic::Coordinates::UTM.new(easting: 580000.0, northing: 4510000.0, zone: 18, hemisphere: 'N')
b = Geodetic::Coordinates::UTM.new(easting: 590000.0, northing: 4520000.0, zone: 18, hemisphere: 'N')
a.same_zone?(b)
# => true
```

Raises `ArgumentError` if `other` is not a `UTM`.

### central_meridian

Returns the central meridian longitude (in degrees) for the UTM zone.

```ruby
utm = Geodetic::Coordinates::UTM.new(zone: 18, hemisphere: 'N')
utm.central_meridian
# => -75
```

The formula is: `(zone - 1) * 6 - 180 + 3`.

## Code Examples

### Round-trip conversion

```ruby
require 'geodetic'

# Start with an LLA and convert to UTM
lla = Geodetic::Coordinates::LLA.new(lat: 40.7128, lng: -74.0060, alt: 10.0)
utm = lla.to_utm
puts utm.to_s
# zone and hemisphere are determined automatically

# Convert back to LLA
lla_roundtrip = utm.to_lla
```

### Distance calculations

```ruby
point_a = Geodetic::Coordinates::UTM.new(
  easting: 583960.0, northing: 4507523.0,
  altitude: 10.0, zone: 18, hemisphere: 'N'
)
point_b = Geodetic::Coordinates::UTM.new(
  easting: 584060.0, northing: 4507623.0,
  altitude: 15.0, zone: 18, hemisphere: 'N'
)

# Great-circle distance (works across zones and coordinate types)
puts "Distance:    #{point_a.distance_to(point_b).meters} m"

# Straight-line (Euclidean) distance
puts "Straight:    #{point_a.straight_line_distance_to(point_b).meters} m"

puts "Same zone?   #{point_a.same_zone?(point_b)}"
```

### Working with zones

```ruby
# Check which zone a location falls in
lla = Geodetic::Coordinates::LLA.new(lat: 48.8566, lng: 2.3522, alt: 35.0)  # Paris
utm = lla.to_utm
puts "Zone: #{utm.zone}#{utm.hemisphere}"       # => "31N"
puts "Central meridian: #{utm.central_meridian}" # => 3
```
