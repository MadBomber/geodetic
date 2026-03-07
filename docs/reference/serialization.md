# Serialization Reference

All coordinate classes provide methods for converting to and from string and array representations. This enables storage, transmission, and reconstruction of coordinate objects.

---

## Common Serialization Methods

Every coordinate class implements these four methods:

| Method | Direction | Description |
|--------|-----------|-------------|
| `to_s` | Export | Returns a comma-separated string representation |
| `self.from_string(string)` | Import | Parses a comma-separated string into a new instance |
| `to_a` | Export | Returns an array of component values |
| `self.from_array(array)` | Import | Constructs a new instance from an array |

---

## Format Reference by Class

### LLA

```ruby
point = Geodetic::Coordinates::LLA.new(lat: 38.8977, lng: -77.0365, alt: 100.0)

point.to_s    # => "38.8977, -77.0365, 100.0"
point.to_a    # => [38.8977, -77.0365, 100.0]

Geodetic::Coordinates::LLA.from_string("38.8977, -77.0365, 100.0")
Geodetic::Coordinates::LLA.from_array([38.8977, -77.0365, 100.0])
```

**LLA-specific: DMS format**

LLA also supports degrees-minutes-seconds notation:

```ruby
point.to_dms
# => "38 53' 51.72\" N, 77 2' 11.40\" W, 100.00 m"

Geodetic::Coordinates::LLA.from_dms("38 53' 51.72\" N, 77 2' 11.40\" W, 100.0 m")
```

The DMS string format is: `DD MM' SS.ss" H, DDD MM' SS.ss" H, ALT m` where H is N/S for latitude and E/W for longitude. The altitude portion is optional in `from_dms` (defaults to 0.0).

### ECEF

```ruby
point = Geodetic::Coordinates::ECEF.new(x: 1130730.0, y: -4828583.0, z: 3991570.0)

point.to_s    # => "1130730.0, -4828583.0, 3991570.0"
point.to_a    # => [1130730.0, -4828583.0, 3991570.0]

Geodetic::Coordinates::ECEF.from_string("1130730.0, -4828583.0, 3991570.0")
Geodetic::Coordinates::ECEF.from_array([1130730.0, -4828583.0, 3991570.0])
```

### UTM

```ruby
point = Geodetic::Coordinates::UTM.new(easting: 323394.0, northing: 4307396.0, altitude: 100.0, zone: 18, hemisphere: 'N')

point.to_s    # => "323394.0, 4307396.0, 100.0, 18, N"
point.to_a    # => [323394.0, 4307396.0, 100.0, 18, "N"]

Geodetic::Coordinates::UTM.from_string("323394.0, 4307396.0, 100.0, 18, N")
Geodetic::Coordinates::UTM.from_array([323394.0, 4307396.0, 100.0, 18, "N"])
```

Note: The array and string formats include all five components: easting, northing, altitude, zone number, and hemisphere.

### ENU

```ruby
point = Geodetic::Coordinates::ENU.new(e: 100.0, n: 200.0, u: 50.0)

point.to_s    # => "100.0, 200.0, 50.0"
point.to_a    # => [100.0, 200.0, 50.0]

Geodetic::Coordinates::ENU.from_string("100.0, 200.0, 50.0")
Geodetic::Coordinates::ENU.from_array([100.0, 200.0, 50.0])
```

### NED

```ruby
point = Geodetic::Coordinates::NED.new(n: 200.0, e: 100.0, d: -50.0)

point.to_s    # => "200.0, 100.0, -50.0"
point.to_a    # => [200.0, 100.0, -50.0]

Geodetic::Coordinates::NED.from_string("200.0, 100.0, -50.0")
Geodetic::Coordinates::NED.from_array([200.0, 100.0, -50.0])
```

### WebMercator

```ruby
point = Geodetic::Coordinates::WebMercator.new(x: -8575605.0, y: 4707175.0)

point.to_s    # => "-8575605.0, 4707175.0"
point.to_a    # => [-8575605.0, 4707175.0]

Geodetic::Coordinates::WebMercator.from_string("-8575605.0, 4707175.0")
Geodetic::Coordinates::WebMercator.from_array([-8575605.0, 4707175.0])
```

### UPS

```ruby
point = Geodetic::Coordinates::UPS.new(easting: 2000000.0, northing: 2000000.0, hemisphere: 'N', zone: 'Y')

point.to_s    # => "2000000.0, 2000000.0, N, Y"
point.to_a    # => [2000000.0, 2000000.0, "N", "Y"]

Geodetic::Coordinates::UPS.from_string("2000000.0, 2000000.0, N, Y")
Geodetic::Coordinates::UPS.from_array([2000000.0, 2000000.0, "N", "Y"])
```

### BNG

```ruby
point = Geodetic::Coordinates::BNG.new(easting: 530000.0, northing: 180000.0)

point.to_s    # => "530000.0, 180000.0"
point.to_a    # => [530000.0, 180000.0]

Geodetic::Coordinates::BNG.from_string("530000.0, 180000.0")
Geodetic::Coordinates::BNG.from_array([530000.0, 180000.0])
```

BNG also supports grid reference notation via the constructor:

```ruby
point = Geodetic::Coordinates::BNG.new(grid_ref: "TQ 30 80")
point.to_grid_reference(6)  # => "TQ 300000 800000"
point.to_grid_reference(0)  # => "TQ" (grid square only)
```

### StatePlane

```ruby
point = Geodetic::Coordinates::StatePlane.new(easting: 2000000.0, northing: 500000.0, zone_code: 'CA_I')

point.to_s    # => "2000000.0, 500000.0, CA_I"
point.to_a    # => [2000000.0, 500000.0, "CA_I"]

Geodetic::Coordinates::StatePlane.from_string("2000000.0, 500000.0, CA_I")
Geodetic::Coordinates::StatePlane.from_array([2000000.0, 500000.0, "CA_I"])
```

---

## MGRS and USNG (String-Based Formats)

MGRS and USNG use alphanumeric grid references rather than numeric arrays. They support `to_s` and `from_string` but do not provide `to_a` / `from_array`.

### MGRS

```ruby
mgrs = Geodetic::Coordinates::MGRS.new(mgrs_string: "18SUJ2034706880")
mgrs.to_s    # => "18SUJ2034706880"

Geodetic::Coordinates::MGRS.from_string("18SUJ2034706880")
```

The MGRS string format is: `{zone_number}{zone_letter}{square_id}{easting}{northing}` with no spaces. Precision varies based on the number of coordinate digits (0 to 5 pairs).

### USNG

```ruby
usng = Geodetic::Coordinates::USNG.new(usng_string: "18S UJ 20347 06880")
usng.to_s    # => "18S UJ 20347 06880"

Geodetic::Coordinates::USNG.from_string("18S UJ 20347 06880")
```

USNG uses the same underlying format as MGRS but separates components with spaces for readability. Both spaced and non-spaced formats are accepted by `from_string`. USNG also provides:

```ruby
usng.to_full_format        # => "18S UJ 20347 06880"
usng.to_abbreviated_format # => "18S UJ 20347 6880"
```

---

## Roundtrip Examples

String and array serialization support full roundtrip fidelity:

```ruby
# LLA roundtrip via string
original = Geodetic::Coordinates::LLA.new(lat: 40.7128, lng: -74.0060, alt: 10.0)
restored = Geodetic::Coordinates::LLA.from_string(original.to_s)
original == restored  # => true

# ECEF roundtrip via array
original = Geodetic::Coordinates::ECEF.new(x: 1334000.0, y: -4654000.0, z: 4138000.0)
restored = Geodetic::Coordinates::ECEF.from_array(original.to_a)
original == restored  # => true

# UTM roundtrip via string
original = Geodetic::Coordinates::UTM.new(easting: 583960.0, northing: 4507523.0, altitude: 10.0, zone: 18, hemisphere: 'N')
restored = Geodetic::Coordinates::UTM.from_string(original.to_s)
original == restored  # => true

# LLA roundtrip via DMS
original = Geodetic::Coordinates::LLA.new(lat: 38.8977, lng: -77.0365, alt: 100.0)
dms_string = original.to_dms
restored = Geodetic::Coordinates::LLA.from_dms(dms_string)
# Note: DMS roundtrip has minor floating-point precision differences
```

---

## Summary Table

| Class | `to_s` Format | `to_a` Elements | Extra Formats |
|-------|--------------|-----------------|---------------|
| LLA | `lat, lng, alt` | `[lat, lng, alt]` | `to_dms` / `from_dms` |
| ECEF | `x, y, z` | `[x, y, z]` | -- |
| UTM | `easting, northing, alt, zone, hemisphere` | `[easting, northing, alt, zone, hemisphere]` | -- |
| ENU | `e, n, u` | `[e, n, u]` | -- |
| NED | `n, e, d` | `[n, e, d]` | -- |
| WebMercator | `x, y` | `[x, y]` | -- |
| UPS | `easting, northing, hemisphere, zone` | `[easting, northing, hemisphere, zone]` | -- |
| BNG | `easting, northing` | `[easting, northing]` | `to_grid_reference` / `grid_ref:` constructor |
| StatePlane | `easting, northing, zone_code` | `[easting, northing, zone_code]` | -- |
| MGRS | `grid_zone+square+coords` | (not available) | String-based only |
| USNG | `grid_zone square coords` | (not available) | `to_full_format`, `to_abbreviated_format` |
