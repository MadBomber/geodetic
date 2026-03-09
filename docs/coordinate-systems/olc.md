# Geodetic::Coordinate::OLC

## Open Location Code (Plus Codes)

Open Location Code (OLC), also known as Plus Codes, is Google's open system for encoding locations into short, URL-friendly codes like `849VCWC8+R9`. It uses a 20-character alphabet (`23456789CFGHJMPQRVWX`) that excludes vowels and visually ambiguous characters to avoid spelling words or confusing similar-looking characters.

The encoding uses a false coordinate origin that shifts longitude by +180 and latitude by +90, making all values positive before encoding. Two encoding modes produce codes of varying precision:

| Mode | Characters | Encoding | Resolution per Level |
|------|-----------|----------|---------------------|
| **Paired** | 1-10 (5 pairs) | Base-20 lat/lng pairs | 20, 1, 0.05, 0.0025, 0.000125 degrees |
| **Grid** | 11-15 | 5x4 grid refinement | Each character subdivides the remaining cell |

All codes include a `+` separator after the 8th character position. Codes shorter than 8 significant characters are padded with `0`. For example, precision 2 produces `84000000+`.

OLC is a **2D coordinate system** (no altitude). Conversions to/from other systems go through LLA as the intermediary. Each code represents a rectangular cell; the coordinate's point value is the cell's midpoint.

## Constructor

```ruby
# From a plus code string
coord = Geodetic::Coordinate::OLC.new("849VCWC8+R9")

# From any coordinate (converts via LLA)
coord = Geodetic::Coordinate::OLC.new(lla_coord)
coord = Geodetic::Coordinate::OLC.new(utm_coord, precision: 11)
```

| Parameter   | Type              | Default | Description                                    |
|-------------|-------------------|---------|------------------------------------------------|
| `source`    | String or Coord   | —       | A plus code string or any coordinate object    |
| `precision` | Integer           | 10      | Code length: 2, 4, 6, 8, 10, 11, 12, 13, 14, or 15 |

Raises `ArgumentError` if the source string is empty, lacks a `+` separator at position 8, contains invalid characters, has odd padding positions, or has characters after `+` when padded. String input is case-insensitive (normalized to uppercase).

## Attributes

| Attribute | Type   | Access    | Description               |
|-----------|--------|-----------|---------------------------|
| `code`    | String | read-only | The plus code string      |

OLC is **immutable** — there are no setter methods.

## Precision

The precision (code length) determines the size of the encoded cell:

| Length | Mode | Approximate Cell Size |
|--------|------|----------------------|
| 2      | Paired | ~2,220 km x 2,220 km |
| 4      | Paired | ~111 km x 111 km |
| 6      | Paired | ~5.5 km x 5.5 km |
| 8      | Paired | ~275 m x 275 m |
| 10     | Paired | ~14 m x 14 m |
| 11     | Grid   | ~3 m x 3.5 m |
| 12     | Grid   | ~0.6 m x 0.9 m |
| 13     | Grid   | ~0.1 m x 0.2 m |
| 14     | Grid   | ~0.02 m x 0.05 m |
| 15     | Grid   | ~0.005 m x 0.01 m |

```ruby
coord.precision              # => 10 (number of significant characters)
coord.precision_in_meters    # => { lat: ~13.9, lng: ~13.9 }
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
```

### Class Methods

```ruby
OLC.from_lla(lla_coord)
OLC.from_ecef(ecef_coord)
OLC.from_utm(utm_coord)
OLC.from_web_mercator(wm_coord)
OLC.from_gh(gh_coord)
OLC.from_gh36(gh36_coord)
OLC.from_ham(ham_coord)
# ... and all other coordinate systems
```

### LLA Convenience Methods

```ruby
lla = Geodetic::Coordinate::LLA.new(lat: 37.4220, lng: -122.0841)
olc = lla.to_olc                    # default precision 10
olc = lla.to_olc(precision: 11)     # grid refinement precision

lla = Geodetic::Coordinate::LLA.from_olc(olc)
```

## Serialization

### `to_s(truncate_to = nil)`

Returns the plus code string. An optional integer truncates to that precision (re-encodes from decoded coordinates).

```ruby
coord = OLC.new("849VCWC8+R9")
coord.to_s       # => "849VCWC8+R9"
coord.to_s(10)   # => "849VCWC8+R9" (already 11 chars, truncated to 10)
coord.to_s(8)    # => "849VCWC8+"
coord.to_s(4)    # => "84900000+"
```

### `to_a`

Returns `[lat, lng]` of the cell midpoint.

```ruby
coord.to_a    # => [37.4220..., -122.0841...]
```

### `from_string` / `from_array`

```ruby
OLC.from_string("849VCWC8+R9")           # from plus code string
OLC.from_array([37.4220, -122.0841])      # from [lat, lng]
```

## Neighbors

Returns all 8 adjacent cells as OLC instances.

```ruby
coord = OLC.new("849VCWC8+R9")
neighbors = coord.neighbors
# => { N: OLC, S: OLC, E: OLC, W: OLC, NE: OLC, NW: OLC, SE: OLC, SW: OLC }

neighbors[:N].to_lla.lat > coord.to_lla.lat   # => true
neighbors[:E].to_lla.lng > coord.to_lla.lng   # => true
```

Neighbors preserve the same precision as the original code. Latitude is clamped to valid range near the poles; longitude wraps at the antimeridian.

## Area

The `to_area` method returns the plus code cell as a `Geodetic::Areas::Rectangle`.

```ruby
area = coord.to_area
# => Geodetic::Areas::Rectangle

area.includes?(coord.to_lla)    # => true (midpoint is inside the cell)
area.nw                         # => LLA (northwest corner)
area.se                         # => LLA (southeast corner)
```

## Equality

Two OLC instances are equal if their code strings match exactly.

```ruby
OLC.new("849VCWC8+R9") == OLC.new("849VCWC8+R9")   # => true
OLC.new("849VCWC8+R9") == OLC.new("849VCWC8+R8")   # => false
```

## `valid?`

Returns `true` if the code has a `+` separator at position 8, valid characters, and correct padding.

```ruby
coord.valid?    # => true
```

## Universal Distance and Bearing Methods

OLC supports all universal distance and bearing methods via the `DistanceMethods` and `BearingMethods` mixins:

```ruby
a = OLC.new("849VCWC8+R9")
b = OLC.new("87G8Q2JM+QV")

a.distance_to(b)                # => Distance
a.straight_line_distance_to(b)  # => Distance
a.bearing_to(b)                 # => Bearing
a.elevation_to(b)               # => Float (degrees)
```

## Well-Known Plus Codes

| Location | Plus Code |
|----------|-----------|
| Google HQ (Mountain View) | 849VCWC8+R9 |
| Statue of Liberty | 87G8Q2JM+QV |
| Eiffel Tower | 8FW4V75V+8Q |
| Sydney Opera House | 4RRH46R6+PJ |
| Null Island (0, 0) | 6FG22222+22 |

## Alphabet

The 20-character OLC alphabet: `2 3 4 5 6 7 8 9 C F G H J M P Q R V W X`

Characters were chosen to avoid:
- Vowels (no words can be spelled)
- Visually ambiguous characters (no 0/O, 1/I/L)
- Characters easily confused in handwriting
