# Geodetic::Coordinate::GEOREF

## World Geographic Reference System

GEOREF is a grid-based geocode developed by the US military and adopted by ICAO for air navigation and air defense reporting. It encodes latitude/longitude into a compact alphanumeric string using a false coordinate system that shifts longitude by +180 and latitude by +90 to make all values positive.

The encoding reads longitude first, then latitude at each level:

| Level | Characters | Description | Resolution |
|-------|-----------|-------------|------------|
| **Tile** | 1-2 | 15-degree grid (24 lng x 12 lat letters) | 15 degrees |
| **Degree** | 3-4 | 1-degree subdivision within tile (15 letters each) | 1 degree |
| **Minutes** | 5+ | Numeric digit pairs (lng digits, then lat digits) | Variable |

The character set uses 24 letters (A-Z, omitting I and O) for tiles, and 15 letters (A-Q, omitting I and O) for degree subdivisions. Minute pairs are decimal digits.

Valid code lengths: 2, 4, 8, 10, 12, 14 characters (not 6 -- minimum numeric portion is 2 digits per axis).

GEOREF is a **2D coordinate system** (no altitude). Conversions to/from other systems go through LLA as the intermediary. Each code represents a rectangular cell; the coordinate's point value is the cell's midpoint.

## Constructor

```ruby
# From a GEOREF string
coord = Geodetic::Coordinate::GEOREF.new("GJPJ3417")

# From any coordinate (converts via LLA)
coord = Geodetic::Coordinate::GEOREF.new(lla_coord)
coord = Geodetic::Coordinate::GEOREF.new(utm_coord, precision: 10)
```

| Parameter   | Type              | Default | Description                                    |
|-------------|-------------------|---------|------------------------------------------------|
| `source`    | String or Coord   | --      | A GEOREF string or any coordinate object       |
| `precision` | Integer           | 8       | Code length: 2, 4, 8, 10, 12, or 14           |

Raises `ArgumentError` if the source string is empty, has an invalid length (including 6), or contains invalid characters. String input is case-insensitive (normalized to uppercase).

## Attributes

| Attribute | Type   | Access    | Description              |
|-----------|--------|-----------|--------------------------|
| `code`    | String | read-only | The GEOREF code string   |

GEOREF is **immutable** -- there are no setter methods.

## Precision

The precision (code length) determines the size of the encoded cell:

| Length | Resolution | Approximate Cell Size |
|--------|-----------|----------------------|
| 2      | 15 degrees | ~1,668 km x 1,668 km |
| 4      | 1 degree   | ~111 km x 111 km |
| 8      | 1 minute   | ~1.85 km x 1.85 km |
| 10     | 0.1 minute | ~185 m x 185 m |
| 12     | 0.01 minute | ~18.5 m x 18.5 m |
| 14     | 0.001 minute | ~1.85 m x 1.85 m |

```ruby
coord.precision              # => 8 (code length)
coord.precision_in_meters    # => { lat: ~1850, lng: ~1850 }
```

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
coord.to_gh
coord.to_ham
coord.to_olc
coord.to_gars
```

### Class Methods

```ruby
GEOREF.from_lla(lla_coord)
GEOREF.from_ecef(ecef_coord)
GEOREF.from_utm(utm_coord)
GEOREF.from_web_mercator(wm_coord)
GEOREF.from_gh(gh_coord)
GEOREF.from_gars(gars_coord)
# ... and all other coordinate systems
```

### LLA Convenience Methods

```ruby
lla = Geodetic::Coordinate::LLA.new(lat: 40.7128, lng: -74.0060)
georef = lla.to_georef                    # default precision 8
georef = lla.to_georef(precision: 10)     # 0.1-minute precision

lla = Geodetic::Coordinate::LLA.from_georef(georef)
```

## Serialization

### `to_s(truncate_to = nil)`

Returns the GEOREF string. An optional integer truncates to that precision (re-encodes from decoded coordinates).

```ruby
coord = GEOREF.new("GJPJ3417")
coord.to_s       # => "GJPJ3417"
coord.to_s(4)    # => "GJPJ"
coord.to_s(2)    # => "GJ"
```

### `to_a`

Returns `[lat, lng]` of the cell midpoint.

```ruby
coord.to_a    # => [38.286..., -76.411...]
```

### `from_string` / `from_array`

```ruby
GEOREF.from_string("GJPJ3417")           # from GEOREF string
GEOREF.from_array([38.0, -76.0])         # from [lat, lng]
```

## Neighbors

Returns all 8 adjacent cells as GEOREF instances.

```ruby
coord = GEOREF.new("GJPJ3417")
neighbors = coord.neighbors
# => { N: GEOREF, S: GEOREF, E: GEOREF, W: GEOREF, NE: GEOREF, NW: GEOREF, SE: GEOREF, SW: GEOREF }

neighbors[:N].to_lla.lat > coord.to_lla.lat   # => true
neighbors[:E].to_lla.lng > coord.to_lla.lng   # => true
```

Neighbors preserve the same precision as the original code. Latitude is clamped to valid range near the poles; longitude wraps at the antimeridian.

## Area

The `to_area` method returns the GEOREF cell as a `Geodetic::Areas::Rectangle`.

```ruby
area = coord.to_area
# => Geodetic::Areas::Rectangle

area.includes?(coord.to_lla)    # => true (midpoint is inside the cell)
area.nw                         # => LLA (northwest corner)
area.se                         # => LLA (southeast corner)
```

## Equality

Two GEOREF instances are equal if their code strings match exactly.

```ruby
GEOREF.new("GJPJ3417") == GEOREF.new("GJPJ3417")   # => true
GEOREF.new("GJPJ3417") == GEOREF.new("GJPJ3418")   # => false
```

## `valid?`

Returns `true` if the code has a valid length (2, 4, 8, 10, 12, or 14), valid tile letters, valid degree letters, and properly formatted minute digits.

```ruby
coord.valid?    # => true
```

## Universal Distance and Bearing Methods

GEOREF supports all universal distance and bearing methods via the `DistanceMethods` and `BearingMethods` mixins:

```ruby
a = GEOREF.new("GJPJ3417")
b = GEOREF.new("HJAL4243")

a.distance_to(b)                # => Distance
a.straight_line_distance_to(b)  # => Distance
a.bearing_to(b)                 # => Bearing
a.elevation_to(b)               # => Float (degrees)
```

## Character Sets

**Tile longitude** (24 letters): `A B C D E F G H J K L M N P Q R S T U V W X Y Z`

**Tile latitude** (12 letters): `A B C D E F G H J K L M`

**Degree subdivision** (15 letters): `A B C D E F G H J K L M N P Q`

All sets omit `I` and `O` to avoid confusion with digits `1` and `0`.

## Code Structure Examples

| Code | Meaning |
|------|---------|
| `GJ` | 15-degree tile (tile only) |
| `GJPJ` | 1-degree cell within tile |
| `GJPJ3417` | 1-minute cell (lng 34', lat 17') |
| `GJPJ342171` | 0.1-minute cell |
| `GJPJ34211712` | 0.01-minute cell |
