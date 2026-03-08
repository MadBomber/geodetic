# Geodetic::Coordinates::LLA

Latitude, Longitude, Altitude -- the most common geodetic coordinate system. Represents a position on (or above/below) the Earth's surface using angular degrees and a height in meters above the WGS84 reference ellipsoid.

- A negative latitude is in the Southern hemisphere.
- A negative longitude is in the Western hemisphere.
- Altitude is in decimal meters above the ellipsoid.

LLA is the **hub class** in the Geodetic library. It can convert directly to all other coordinate systems (ECEF, UTM, ENU, NED), making it the central interchange format.

## Constructor

```ruby
Geodetic::Coordinates::LLA.new(lat: 0.0, lng: 0.0, alt: 0.0)
```

| Parameter | Type  | Default | Description                                |
|-----------|-------|---------|--------------------------------------------|
| `lat`     | Float | `0.0`   | Latitude in decimal degrees (-90..90)      |
| `lng`     | Float | `0.0`   | Longitude in decimal degrees (-180..180)   |
| `alt`     | Float | `0.0`   | Altitude in meters above the WGS84 ellipsoid |

All values are coerced to `Float` via `.to_f`.

### Validation

The constructor raises `ArgumentError` if:

- `lat` is outside the range `-90..90`
- `lng` is outside the range `-180..180`

## Attributes

| Attribute   | Alias       | Access          |
|-------------|-------------|-----------------|
| `lat`       | `latitude`  | read/write      |
| `lng`       | `longitude` | read/write      |
| `alt`       | `altitude`  | read/write      |

Setters validate ranges and coerce to `Float`. Setting `lat` outside `-90..90` or `lng` outside `-180..180` raises `ArgumentError`. The `alt` setter has no range constraint.

## Conversions

All conversion methods accept an optional `datum` parameter (defaults to `Geodetic::WGS84`).

### to_ecef(datum = WGS84)

Converts to Earth-Centered, Earth-Fixed Cartesian coordinates.

```ruby
lla = Geodetic::Coordinates::LLA.new(lat: 38.8977, lng: -77.0365, alt: 17.0)
ecef = lla.to_ecef
# => Geodetic::Coordinates::ECEF
```

### LLA.from_ecef(ecef, datum = WGS84)

Creates an LLA from an ECEF instance. Raises `ArgumentError` if the argument is not an `ECEF`.

### to_utm(datum = WGS84)

Converts to Universal Transverse Mercator coordinates. The UTM zone and hemisphere are computed automatically from the longitude and latitude.

```ruby
utm = lla.to_utm
# => Geodetic::Coordinates::UTM
```

### LLA.from_utm(utm, datum = WGS84)

Creates an LLA from a UTM instance. Raises `ArgumentError` if the argument is not a `UTM`.

### to_enu(reference_lla)

Converts to East-North-Up local tangent plane coordinates relative to a reference LLA position.

```ruby
origin = Geodetic::Coordinates::LLA.new(lat: 38.8977, lng: -77.0365, alt: 17.0)
point  = Geodetic::Coordinates::LLA.new(lat: 38.8987, lng: -77.0355, alt: 20.0)
enu = point.to_enu(origin)
# => Geodetic::Coordinates::ENU
```

Raises `ArgumentError` if `reference_lla` is not an `LLA`.

### LLA.from_enu(enu, reference_lla)

Creates an LLA from an ENU instance and a reference LLA origin. Raises `ArgumentError` if the arguments are not the expected types.

### to_ned(reference_lla)

Converts to North-East-Down local tangent plane coordinates relative to a reference LLA position.

```ruby
ned = point.to_ned(origin)
# => Geodetic::Coordinates::NED
```

Raises `ArgumentError` if `reference_lla` is not an `LLA`.

### LLA.from_ned(ned, reference_lla)

Creates an LLA from a NED instance and a reference LLA origin. Raises `ArgumentError` if the arguments are not the expected types.

## Serialization

### to_s

Returns a comma-separated string of `lat, lng, alt`.

```ruby
lla = Geodetic::Coordinates::LLA.new(lat: 38.8977, lng: -77.0365, alt: 17.0)
lla.to_s
# => "38.8977, -77.0365, 17.0"
```

### to_a

Returns a three-element array `[lat, lng, alt]`.

```ruby
lla.to_a
# => [38.8977, -77.0365, 17.0]
```

### LLA.from_string(string)

Parses a comma-separated string into an LLA.

```ruby
lla = Geodetic::Coordinates::LLA.from_string("38.8977, -77.0365, 17.0")
```

### LLA.from_array(array)

Creates an LLA from a three-element array `[lat, lng, alt]`.

```ruby
lla = Geodetic::Coordinates::LLA.from_array([38.8977, -77.0365, 17.0])
```

### to_dms

Converts to a Degrees-Minutes-Seconds string with hemisphere indicators and altitude.

```ruby
lla = Geodetic::Coordinates::LLA.new(lat: 38.8977, lng: -77.0365, alt: 17.0)
lla.to_dms
# => "38° 53' 51.72\" N, 77° 2' 11.40\" W, 17.00 m"
```

### LLA.from_dms(dms_str)

Parses a DMS-formatted string back into an LLA. The expected format is:

```
DD° MM' SS.ss" N/S, DDD° MM' SS.ss" E/W[, altitude m]
```

The altitude portion is optional and defaults to `0.0`.

```ruby
lla = Geodetic::Coordinates::LLA.from_dms("38° 53' 51.72\" N, 77° 2' 11.40\" W, 17.0 m")
```

Raises `ArgumentError` if the string does not match the expected format.

## Additional Methods

### ==(other)

Compares two LLA instances for approximate equality. Returns `true` if:

- `|lat difference| <= 1e-10`
- `|lng difference| <= 1e-10`
- `|alt difference| <= 1e-6`

Returns `false` if `other` is not an `LLA`.

```ruby
a = Geodetic::Coordinates::LLA.new(lat: 38.8977, lng: -77.0365, alt: 17.0)
b = Geodetic::Coordinates::LLA.new(lat: 38.8977, lng: -77.0365, alt: 17.0)
a == b
# => true
```

### to_gh36(precision: 10)

Converts to Geohash-36 coordinates with configurable precision.

```ruby
gh36 = lla.to_gh36
gh36 = lla.to_gh36(precision: 5)    # coarser precision
# => Geodetic::Coordinates::GH36
```

### LLA.from_gh36(gh36_coord, datum = WGS84)

Creates an LLA from a GH36 instance. Returns the midpoint of the geohash cell.

```ruby
lla = Geodetic::Coordinates::LLA.from_gh36(gh36)
```

## GeoidHeightSupport Mixin

LLA includes the `Geodetic::GeoidHeightSupport` module, which provides methods for working with geoid heights and vertical datum conversions.

### geoid_height(geoid_model = 'EGM2008')

Returns the geoid undulation (in meters) at the coordinate's lat/lng for the specified geoid model.

```ruby
lla = Geodetic::Coordinates::LLA.new(lat: 38.8977, lng: -77.0365, alt: 17.0)
lla.geoid_height
# => Float (geoid undulation in meters)
```

Supported models: `'EGM96'`, `'EGM2008'`, `'GEOID18'`, `'GEOID12B'`.

### orthometric_height(geoid_model = 'EGM2008')

Returns the orthometric height (height above the geoid / mean sea level) by subtracting the geoid undulation from the ellipsoidal altitude.

```ruby
lla.orthometric_height
# => Float (meters above geoid)
```

### convert_height_datum(from_datum, to_datum, geoid_model = 'EGM2008')

Converts the altitude between vertical datums and returns a new LLA with the adjusted height. The original instance is not modified.

```ruby
lla_navd88 = lla.convert_height_datum('HAE', 'NAVD88')
```

Supported vertical datums: `'NAVD88'`, `'NGVD29'`, `'MSL'`, `'HAE'`.

### Class Method: LLA.with_geoid_height(geoid_model = 'EGM2008')

Sets the default geoid model for the class. Returns the class for chaining.

```ruby
Geodetic::Coordinates::LLA.with_geoid_height('EGM96')
```

## Code Examples

### Round-trip conversion

```ruby
require 'geodetic'

# Create an LLA coordinate
lla = Geodetic::Coordinates::LLA.new(lat: 40.7128, lng: -74.0060, alt: 10.0)

# Convert to ECEF and back
ecef = lla.to_ecef
lla_roundtrip = ecef.to_lla
lla == lla_roundtrip
# => true

# Convert to UTM and back
utm = lla.to_utm
lla_roundtrip = utm.to_lla
```

### Local tangent plane

```ruby
origin = Geodetic::Coordinates::LLA.new(lat: 40.7128, lng: -74.0060, alt: 10.0)
target = Geodetic::Coordinates::LLA.new(lat: 40.7138, lng: -74.0050, alt: 15.0)

enu = target.to_enu(origin)
ned = target.to_ned(origin)
```

### DMS formatting

```ruby
lla = Geodetic::Coordinates::LLA.new(lat: -33.8688, lng: 151.2093, alt: 58.0)
puts lla.to_dms
# => "33° 52' 7.68" S, 151° 12' 33.48" E, 58.00 m"

restored = Geodetic::Coordinates::LLA.from_dms(lla.to_dms)
```

### Geoid height operations

```ruby
lla = Geodetic::Coordinates::LLA.new(lat: 38.8977, lng: -77.0365, alt: 50.0)

# Get geoid undulation at this location
puts lla.geoid_height           # EGM2008 (default)
puts lla.geoid_height('EGM96')  # EGM96

# Get height above mean sea level
puts lla.orthometric_height

# Convert from ellipsoidal height to NAVD88
lla_navd88 = lla.convert_height_datum('HAE', 'NAVD88')
puts lla_navd88.alt
```
