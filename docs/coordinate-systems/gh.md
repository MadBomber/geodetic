# Geodetic::Coordinate::GH

## Geohash (Base-32)

The standard geohash algorithm by Gustavo Niemeyer that encodes latitude/longitude into a compact string using a 32-character alphabet. It uses interleaved longitude and latitude bits, with each 5-bit group mapped to a base-32 character.

Character set: `0123456789bcdefghjkmnpqrstuvwxyz`
(excludes `a`, `i`, `l`, `o` to avoid ambiguity)

This is the de facto standard for spatial hashing, natively supported by Elasticsearch, Redis, PostGIS, and many geocoding services.

GH is a **2D coordinate system** (no altitude). Conversions to/from other systems go through LLA as the intermediary. Each geohash string represents a rectangular cell; the coordinate's point value is the cell's midpoint.

## Constructor

```ruby
# From a geohash string
coord = Geodetic::Coordinate::GH.new("dr5ru7")

# From any coordinate (converts via LLA)
coord = Geodetic::Coordinate::GH.new(lla_coord)
coord = Geodetic::Coordinate::GH.new(utm_coord, precision: 8)
```

| Parameter   | Type              | Default | Description                                  |
|-------------|-------------------|---------|----------------------------------------------|
| `source`    | String or Coord   | —       | A geohash string or any coordinate object    |
| `precision` | Integer           | 12      | Hash length (ignored when source is a String) |

Raises `ArgumentError` if the source is an empty string, contains invalid characters, or is not a recognized coordinate type. String input is case-insensitive (automatically downcased).

## Attributes

| Attribute | Type   | Access    | Description                     |
|-----------|--------|-----------|---------------------------------|
| `geohash` | String | read-only | The geohash base-32 encoded string |

GH is **immutable** — there are no setter methods.

## Precision

The precision (hash length) determines the size of the cell:

| Length | Approximate Resolution |
|--------|----------------------|
| 1      | ~5,000 km            |
| 4      | ~20 km               |
| 6      | ~610 m               |
| 8      | ~19 m                |
| 12     | ~0.019 m (default)   |

```ruby
coord.precision              # => 12 (hash length)
coord.precision_in_meters    # => { lat: 0.019, lng: 0.019 }
```

Longer hashes yield finer precision.

## Conversions

All conversions chain through LLA. The datum parameter defaults to `Geodetic::WGS84`.

### Instance Methods

```ruby
coord.to_lla                    # => LLA (midpoint of the cell)
coord.to_ecef
coord.to_utm
coord.to_enu(reference_lla)
coord.to_ned(reference_lla)
coord.to_mgrs
coord.to_usng
coord.to_web_mercator
coord.to_ups
coord.to_state_plane(zone_code)
coord.to_bng
coord.to_gh36
```

### Class Methods

```ruby
GH.from_lla(lla_coord)
GH.from_ecef(ecef_coord)
GH.from_utm(utm_coord)
GH.from_web_mercator(wm_coord)
GH.from_gh36(gh36_coord)
# ... and all other coordinate systems
```

### LLA Convenience Methods

```ruby
lla = Geodetic::Coordinate::LLA.new(lat: 40.689167, lng: -74.044444)
gh = lla.to_gh                    # default precision 12
gh = lla.to_gh(precision: 6)      # custom precision

lla = Geodetic::Coordinate::LLA.from_gh(gh)
```

## Serialization

### `to_s(truncate_to = nil)`

Returns the geohash string. An optional integer truncates to that length.

```ruby
coord = GH.new("dr5ru7c5g200")
coord.to_s       # => "dr5ru7c5g200"
coord.to_s(6)    # => "dr5ru7"
```

### `to_a`

Returns `[lat, lng]` of the cell midpoint.

```ruby
coord.to_a    # => [40.689, -74.044]
```

### `from_string` / `from_array`

```ruby
GH.from_string("dr5ru7")              # from geohash string
GH.from_array([40.689, -74.044])       # from [lat, lng]
```

## Neighbors

Returns all 8 adjacent geohash cells as GH instances.

```ruby
coord = GH.new(LLA.new(lat: 40.0, lng: -74.0))
neighbors = coord.neighbors
# => { N: GH, S: GH, E: GH, W: GH, NE: GH, NW: GH, SE: GH, SW: GH }

neighbors[:N].to_lla.lat > coord.to_lla.lat   # => true
neighbors[:E].to_lla.lng > coord.to_lla.lng   # => true
```

Neighbors preserve the same precision as the original geohash. Longitude wraps correctly near the antimeridian (180/-180 boundary).

## Area

The `to_area` method returns the geohash cell as a `Geodetic::Areas::BoundingBox`.

```ruby
area = coord.to_area
# => Geodetic::Areas::BoundingBox

area.includes?(coord.to_lla)    # => true (midpoint is inside the cell)
area.nw                         # => LLA (northwest corner)
area.se                         # => LLA (southeast corner)
```

## Equality

Two GH instances are equal if their geohash strings match exactly.

```ruby
GH.new("dr5ru7") == GH.new("dr5ru7")   # => true
GH.new("dr5ru7") == GH.new("dr5ru8")   # => false
```

## `valid?`

Returns `true` if all characters are in the valid base-32 geohash alphabet.

```ruby
coord.valid?    # => true
```

## Universal Distance and Bearing Methods

GH supports all universal distance and bearing methods via the `DistanceMethods` and `BearingMethods` mixins:

```ruby
a = GH.new(LLA.new(lat: 40.689167, lng: -74.044444))
b = GH.new(LLA.new(lat: 51.504444, lng: -0.086666))

a.distance_to(b)                # => Distance (~5,570 km)
a.straight_line_distance_to(b)  # => Distance
a.bearing_to(b)                 # => Bearing (~51°)
a.elevation_to(b)               # => Float (degrees)
```

Cross-system distances work too:

```ruby
utm = seattle_lla.to_utm
gh = GH.new(portland_lla)
utm.distance_to(gh)    # => Distance
```

## GH vs GH36

GH (base-32) and GH36 (base-36) are both spatial hashing systems that encode latitude/longitude into compact strings. They differ in alphabet, encoding strategy, ecosystem support, and resolution characteristics.

### Design Differences

| Feature | GH (base-32) | GH36 (base-36) |
|---------|-------------|----------------|
| Algorithm | Bit-interleaved lat/lng, 5 bits per character | 6x6 matrix subdivision per character |
| Alphabet | 32 chars: `0-9, b-z` (excludes `a, i, l, o`) | 36 chars: `23456789bBCdDFgGhHjJKlLMnNPqQrRtTVWX` |
| Case sensitivity | Case-insensitive | Case-sensitive |
| Default precision | 12 characters | 10 characters |
| Information density | 5 bits/char (log2(32) = 5.0) | ~5.17 bits/char (log2(36) = 5.17) |

GH interleaves longitude and latitude bits — odd-numbered bits encode longitude, even-numbered bits encode latitude. Each group of 5 bits maps to one base-32 character. This means GH cells alternate between being wider-than-tall and taller-than-wide at each precision level.

GH36 subdivides the coordinate space using a 6x6 character matrix at each level. This yields slightly more information per character (5.17 vs 5.0 bits) but requires a case-sensitive alphabet.

### Precision Comparison

Cell dimensions at the equator for each hash length:

| Length | GH (base-32) | GH36 (base-36) |
|--------|-------------|----------------|
| 1 | 5,009 km x 4,628 km | 1,668 km x 3,335 km |
| 2 | 626 km x 1,251 km | 278 km x 556 km |
| 3 | 157 km x 157 km | 46 km x 93 km |
| 4 | 20 km x 39 km | 7.7 km x 15 km |
| 5 | 4.9 km x 4.9 km | 1.3 km x 2.6 km |
| 6 | 611 m x 1,223 m | 214 m x 429 m |
| 7 | 153 m x 153 m | 36 m x 71 m |
| 8 | 19 m x 38 m | 6.0 m x 11.9 m |
| 9 | 4.8 m x 4.8 m | 0.99 m x 1.99 m |
| 10 | 0.60 m x 1.19 m | 0.17 m x 0.33 m |
| 11 | 0.15 m x 0.15 m | — |
| 12 | 0.019 m x 0.037 m | — |

At their default precisions:

- **GH at 12 characters**: ~19 mm x 37 mm (sub-centimeter)
- **GH36 at 10 characters**: ~17 cm x 33 cm (sub-meter)

GH36 achieves better resolution per character due to its larger alphabet, but GH compensates by defaulting to a longer hash. At equal string lengths, GH36 cells are smaller. At their respective defaults, GH cells are roughly 9x smaller.

### Ecosystem Support

| System | GH (base-32) | GH36 (base-36) |
|--------|:------------:|:--------------:|
| Elasticsearch | Native `geo_point` type | — |
| Redis | `GEOADD`/`GEOSEARCH` commands | — |
| PostGIS | `ST_GeoHash()` function | — |
| MongoDB | `2dsphere` index | — |
| Google S2 | Compatible cell IDs | — |
| Geocoding APIs | Widely supported | — |

GH (base-32) is the de facto standard. Virtually all spatial databases and services that support geohashing use the base-32 algorithm. GH36 is a niche alternative designed for URL-friendly strings with no ambiguous characters.

### When to Use Which

**Choose GH (base-32) when:**
- Integrating with external services (Elasticsearch, Redis, PostGIS)
- Storing geohashes in databases that expect the standard format
- Performing proximity searches using prefix matching
- Interoperating with third-party geocoding or mapping APIs

**Choose GH36 (base-36) when:**
- You need a self-contained spatial hash with no external dependencies
- Case-sensitive storage is acceptable
- You want to avoid vowels and ambiguous characters in user-facing strings
- Slightly better resolution per character matters

### Converting Between GH and GH36

```ruby
gh = Geodetic::Coordinate::GH.new("dr5ru7")
gh36 = gh.to_gh36                    # => GH36 instance
gh_back = gh36.to_gh                 # => GH instance

# Both decode to the same approximate location
gh.to_lla.lat   # => 40.71...
gh36.to_lla.lat # => 40.71...
```

Note that roundtrip conversion is not lossless — each system quantizes coordinates to its own grid, so converting GH -> GH36 -> GH may produce a slightly different hash string that decodes to the same approximate location.
