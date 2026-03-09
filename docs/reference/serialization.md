# Serialization Reference

All coordinate classes provide methods for converting to and from string and array representations. This enables storage, transmission, and reconstruction of coordinate objects.

---

## Common Serialization Methods

Every coordinate class implements these four methods:

| Method | Direction | Description |
|--------|-----------|-------------|
| `to_s(precision)` | Export | Returns a comma-separated string with controlled decimal places |
| `self.from_string(string)` | Import | Parses a comma-separated string into a new instance |
| `to_a` | Export | Returns an array of component values (full precision) |
| `self.from_array(array)` | Import | Constructs a new instance from an array |

### Precision Parameter

All `to_s` methods accept an optional `precision` parameter controlling the number of decimal places. Each class has a sensible default:

| Class | Default Precision | Notes |
|-------|------------------|-------|
| LLA | 6 | Altitude capped at min(precision, 2) |
| Bearing | 4 | |
| All others | 2 | Meters-based coordinates |

Passing `0` returns integer values (no decimal point). MGRS and USNG are string-based and do not accept a precision parameter.

```ruby
lla = Geodetic::Coordinate::LLA.new(lat: 47.6205, lng: -122.3493, alt: 184.0)
lla.to_s        # => "47.620500, -122.349300, 184.00"
lla.to_s(3)     # => "47.620, -122.349, 184.00"
lla.to_s(0)     # => "48, -122, 184"
```

---

## Format Reference by Class

### LLA

```ruby
point = Geodetic::Coordinate::LLA.new(lat: 38.8977, lng: -77.0365, alt: 100.0)

point.to_s    # => "38.897700, -77.036500, 100.00"
point.to_s(2) # => "38.90, -77.04, 100.00"
point.to_a    # => [38.8977, -77.0365, 100.0]

Geodetic::Coordinate::LLA.from_string("38.8977, -77.0365, 100.0")
Geodetic::Coordinate::LLA.from_array([38.8977, -77.0365, 100.0])
```

**LLA-specific: DMS format**

LLA also supports degrees-minutes-seconds notation:

```ruby
point.to_dms
# => "38 53' 51.72\" N, 77 2' 11.40\" W, 100.00 m"

Geodetic::Coordinate::LLA.from_dms("38 53' 51.72\" N, 77 2' 11.40\" W, 100.0 m")
```

The DMS string format is: `DD MM' SS.ss" H, DDD MM' SS.ss" H, ALT m` where H is N/S for latitude and E/W for longitude. The altitude portion is optional in `from_dms` (defaults to 0.0).

### ECEF

```ruby
point = Geodetic::Coordinate::ECEF.new(x: 1130730.0, y: -4828583.0, z: 3991570.0)

point.to_s    # => "1130730.00, -4828583.00, 3991570.00"
point.to_s(0) # => "1130730, -4828583, 3991570"
point.to_a    # => [1130730.0, -4828583.0, 3991570.0]

Geodetic::Coordinate::ECEF.from_string("1130730.0, -4828583.0, 3991570.0")
Geodetic::Coordinate::ECEF.from_array([1130730.0, -4828583.0, 3991570.0])
```

### UTM

```ruby
point = Geodetic::Coordinate::UTM.new(easting: 323394.0, northing: 4307396.0, altitude: 100.0, zone: 18, hemisphere: 'N')

point.to_s    # => "323394.00, 4307396.00, 100.00, 18, N"
point.to_a    # => [323394.0, 4307396.0, 100.0, 18, "N"]

Geodetic::Coordinate::UTM.from_string("323394.0, 4307396.0, 100.0, 18, N")
Geodetic::Coordinate::UTM.from_array([323394.0, 4307396.0, 100.0, 18, "N"])
```

Note: The array and string formats include all five components: easting, northing, altitude, zone number, and hemisphere.

### ENU

```ruby
point = Geodetic::Coordinate::ENU.new(e: 100.0, n: 200.0, u: 50.0)

point.to_s    # => "100.00, 200.00, 50.00"
point.to_a    # => [100.0, 200.0, 50.0]

Geodetic::Coordinate::ENU.from_string("100.0, 200.0, 50.0")
Geodetic::Coordinate::ENU.from_array([100.0, 200.0, 50.0])
```

### NED

```ruby
point = Geodetic::Coordinate::NED.new(n: 200.0, e: 100.0, d: -50.0)

point.to_s    # => "200.00, 100.00, -50.00"
point.to_a    # => [200.0, 100.0, -50.0]

Geodetic::Coordinate::NED.from_string("200.0, 100.0, -50.0")
Geodetic::Coordinate::NED.from_array([200.0, 100.0, -50.0])
```

### WebMercator

```ruby
point = Geodetic::Coordinate::WebMercator.new(x: -8575605.0, y: 4707175.0)

point.to_s    # => "-8575605.00, 4707175.00"
point.to_a    # => [-8575605.0, 4707175.0]

Geodetic::Coordinate::WebMercator.from_string("-8575605.0, 4707175.0")
Geodetic::Coordinate::WebMercator.from_array([-8575605.0, 4707175.0])
```

### UPS

```ruby
point = Geodetic::Coordinate::UPS.new(easting: 2000000.0, northing: 2000000.0, hemisphere: 'N', zone: 'Y')

point.to_s    # => "2000000.00, 2000000.00, N, Y"
point.to_a    # => [2000000.0, 2000000.0, "N", "Y"]

Geodetic::Coordinate::UPS.from_string("2000000.0, 2000000.0, N, Y")
Geodetic::Coordinate::UPS.from_array([2000000.0, 2000000.0, "N", "Y"])
```

### BNG

```ruby
point = Geodetic::Coordinate::BNG.new(easting: 530000.0, northing: 180000.0)

point.to_s    # => "530000.00, 180000.00"
point.to_a    # => [530000.0, 180000.0]

Geodetic::Coordinate::BNG.from_string("530000.0, 180000.0")
Geodetic::Coordinate::BNG.from_array([530000.0, 180000.0])
```

BNG also supports grid reference notation via the constructor:

```ruby
point = Geodetic::Coordinate::BNG.new(grid_ref: "TQ 30 80")
point.to_grid_reference(6)  # => "TQ 300000 800000"
point.to_grid_reference(0)  # => "TQ" (grid square only)
```

### StatePlane

```ruby
point = Geodetic::Coordinate::StatePlane.new(easting: 2000000.0, northing: 500000.0, zone_code: 'CA_I')

point.to_s    # => "2000000.00, 500000.00, CA_I"
point.to_a    # => [2000000.0, 500000.0, "CA_I"]

Geodetic::Coordinate::StatePlane.from_string("2000000.0, 500000.0, CA_I")
Geodetic::Coordinate::StatePlane.from_array([2000000.0, 500000.0, "CA_I"])
```

---

## MGRS and USNG (String-Based Formats)

MGRS and USNG use alphanumeric grid references rather than numeric arrays. They support all four serialization methods: `to_s`, `from_string`, `to_a`, and `from_array`.

### MGRS

```ruby
mgrs = Geodetic::Coordinate::MGRS.new(mgrs_string: "18SUJ2034706880")
mgrs.to_s    # => "18SUJ2034706880"
mgrs.to_a    # => ["18S", "UJ", 20347.0, 6880.0, 5]

Geodetic::Coordinate::MGRS.from_string("18SUJ2034706880")
Geodetic::Coordinate::MGRS.from_array(["18S", "UJ", 20347, 6880, 5])
```

The MGRS string format is: `{zone_number}{zone_letter}{square_id}{easting}{northing}` with no spaces. Precision varies based on the number of coordinate digits (0 to 5 pairs). The array format is `[grid_zone, square_id, easting, northing, precision]`.

### USNG

```ruby
usng = Geodetic::Coordinate::USNG.new(usng_string: "18S UJ 20347 06880")
usng.to_s    # => "18S UJ 20347 06880"
usng.to_a    # => ["18S", "UJ", 20347.0, 6880.0, 5]

Geodetic::Coordinate::USNG.from_string("18S UJ 20347 06880")
Geodetic::Coordinate::USNG.from_array(["18S", "UJ", 20347, 6880, 5])
```

USNG uses the same underlying format as MGRS but separates components with spaces for readability. Both spaced and non-spaced formats are accepted by `from_string`. The array format is `[grid_zone, square_id, easting, northing, precision]`. USNG also provides:

```ruby
usng.to_full_format        # => "18S UJ 20347 06880"
usng.to_abbreviated_format # => "18S UJ 20347 6880"
```

---

## Roundtrip Examples

String and array serialization support full roundtrip fidelity:

```ruby
# LLA roundtrip via string
original = Geodetic::Coordinate::LLA.new(lat: 40.7128, lng: -74.0060, alt: 10.0)
restored = Geodetic::Coordinate::LLA.from_string(original.to_s)
original == restored  # => true

# ECEF roundtrip via array
original = Geodetic::Coordinate::ECEF.new(x: 1334000.0, y: -4654000.0, z: 4138000.0)
restored = Geodetic::Coordinate::ECEF.from_array(original.to_a)
original == restored  # => true

# UTM roundtrip via string
original = Geodetic::Coordinate::UTM.new(easting: 583960.0, northing: 4507523.0, altitude: 10.0, zone: 18, hemisphere: 'N')
restored = Geodetic::Coordinate::UTM.from_string(original.to_s)
original == restored  # => true

# LLA roundtrip via DMS
original = Geodetic::Coordinate::LLA.new(lat: 38.8977, lng: -77.0365, alt: 100.0)
dms_string = original.to_dms
restored = Geodetic::Coordinate::LLA.from_dms(dms_string)
# Note: DMS roundtrip has minor floating-point precision differences
```

---

## Summary Table

| Class | `to_s` Format | Default Precision | `to_a` Elements | Extra Formats |
|-------|--------------|-------------------|-----------------|---------------|
| LLA | `lat, lng, alt` | 6 (alt: 2) | `[lat, lng, alt]` | `to_dms` / `from_dms` |
| ECEF | `x, y, z` | 2 | `[x, y, z]` | -- |
| UTM | `easting, northing, alt, zone, hemisphere` | 2 | `[easting, northing, alt, zone, hemisphere]` | -- |
| ENU | `e, n, u` | 2 | `[e, n, u]` | -- |
| NED | `n, e, d` | 2 | `[n, e, d]` | -- |
| WebMercator | `x, y` | 2 | `[x, y]` | -- |
| UPS | `easting, northing, hemisphere, zone` | 2 | `[easting, northing, hemisphere, zone]` | -- |
| BNG | `easting, northing` | 2 | `[easting, northing]` | `to_grid_reference` / `grid_ref:` constructor |
| StatePlane | `easting, northing, zone_code` | 2 | `[easting, northing, zone_code]` | -- |
| MGRS | `grid_zone+square+coords` | n/a | `[grid_zone, square_id, easting, northing, precision]` | String-based |
| USNG | `grid_zone square coords` | n/a | `[grid_zone, square_id, easting, northing, precision]` | `to_full_format`, `to_abbreviated_format` |
| GH36 | geohash string | n/a | `[lat, lng]` | `to_area`, `neighbors` |
| GH | geohash string | n/a | `[lat, lng]` | `to_area`, `neighbors` |
| HAM | locator string | n/a | `[lat, lng]` | `to_area`, `neighbors` |
| OLC | plus code string | n/a | `[lat, lng]` | `to_area`, `neighbors` |
