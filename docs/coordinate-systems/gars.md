# Geodetic::Coordinate::GARS

## Global Area Reference System

GARS is a standardized geospatial reference system developed by the National Geospatial-Intelligence Agency (NGA). It divides the Earth into hierarchical grid cells at three precision levels, designed for military targeting, air defense, and joint operations.

The encoding uses a false coordinate origin that shifts longitude by +180 and latitude by +90. Cells are identified by a combination of numeric longitude bands, alphabetic latitude bands, and optional subdivision digits:

| Level | Characters | Size | Description |
|-------|-----------|------|-------------|
| **30-minute cell** | 5 (NNNll) | 30' x 30' | 3-digit lon band + 2-letter lat band |
| **Quadrant** | 6 (NNNllq) | 15' x 15' | + quadrant digit 1-4 |
| **Keypad** | 7 (NNNllqk) | 5' x 5' | + keypad digit 1-9 |

### Quadrant Layout

Within each 30-minute cell, quadrants are numbered:

```
+---+---+
| 1 | 2 |  (north)
+---+---+
| 3 | 4 |  (south)
+---+---+
```

### Keypad Layout

Within each quadrant, keypads follow telephone-style numbering:

```
+---+---+---+
| 1 | 2 | 3 |  (north)
+---+---+---+
| 4 | 5 | 6 |
+---+---+---+
| 7 | 8 | 9 |  (south)
+---+---+---+
```

GARS is a **2D coordinate system** (no altitude). Conversions to/from other systems go through LLA as the intermediary. Each code represents a rectangular cell; the coordinate's point value is the cell's midpoint.

## Constructor

```ruby
# From a GARS string
coord = Geodetic::Coordinate::GARS.new("006AG39")

# From any coordinate (converts via LLA)
coord = Geodetic::Coordinate::GARS.new(lla_coord)
coord = Geodetic::Coordinate::GARS.new(utm_coord, precision: 6)
```

| Parameter   | Type              | Default | Description                          |
|-------------|-------------------|---------|--------------------------------------|
| `source`    | String or Coord   | --      | A GARS string or any coordinate object |
| `precision` | Integer           | 7       | Code length: 5, 6, or 7             |

Raises `ArgumentError` if the source string is empty, has an invalid length, contains an out-of-range longitude band (must be 001-720), invalid latitude letters (I and O excluded), invalid quadrant digit (must be 1-4), or invalid keypad digit (must be 1-9). Letter input is case-insensitive (normalized to uppercase).

## Attributes

| Attribute | Type   | Access    | Description            |
|-----------|--------|-----------|------------------------|
| `code`    | String | read-only | The GARS code string   |

GARS is **immutable** -- there are no setter methods.

## Precision

The precision (code length) determines the size of the encoded cell:

| Length | Level | Approximate Cell Size |
|--------|-------|----------------------|
| 5      | 30-minute cell | ~55.6 km x 55.6 km |
| 6      | 15-minute quadrant | ~27.8 km x 27.8 km |
| 7      | 5-minute keypad | ~9.3 km x 9.3 km |

```ruby
coord.precision              # => 7 (code length)
coord.precision_in_meters    # => { lat: ~9260, lng: ~... }
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
coord.to_georef
```

### Class Methods

```ruby
GARS.from_lla(lla_coord)
GARS.from_ecef(ecef_coord)
GARS.from_utm(utm_coord)
GARS.from_web_mercator(wm_coord)
GARS.from_gh(gh_coord)
GARS.from_georef(georef_coord)
# ... and all other coordinate systems
```

### LLA Convenience Methods

```ruby
lla = Geodetic::Coordinate::LLA.new(lat: 40.7128, lng: -74.0060)
gars = lla.to_gars                    # default precision 7
gars = lla.to_gars(precision: 5)      # 30-minute cell only

lla = Geodetic::Coordinate::LLA.from_gars(gars)
```

## Serialization

### `to_s(truncate_to = nil)`

Returns the GARS string. An optional integer truncates to that precision (re-encodes from decoded coordinates).

```ruby
coord = GARS.new("006AG39")
coord.to_s       # => "006AG39"
coord.to_s(6)    # => "006AG3"
coord.to_s(5)    # => "006AG"
```

### `to_a`

Returns `[lat, lng]` of the cell midpoint.

```ruby
coord.to_a    # => [lat, lng]
```

### `from_string` / `from_array`

```ruby
GARS.from_string("006AG39")           # from GARS string
GARS.from_array([40.0, -74.0])        # from [lat, lng]
```

## Neighbors

Returns all 8 adjacent cells as GARS instances.

```ruby
coord = GARS.new("361HN35")
neighbors = coord.neighbors
# => { N: GARS, S: GARS, E: GARS, W: GARS, NE: GARS, NW: GARS, SE: GARS, SW: GARS }

neighbors[:N].to_lla.lat > coord.to_lla.lat   # => true
neighbors[:E].to_lla.lng > coord.to_lla.lng   # => true
```

Neighbors preserve the same precision as the original code. Latitude is clamped to valid range near the poles; longitude wraps at the antimeridian.

## Area

The `to_area` method returns the GARS cell as a `Geodetic::Areas::Rectangle`.

```ruby
area = coord.to_area
# => Geodetic::Areas::Rectangle

area.includes?(coord.to_lla)    # => true (midpoint is inside the cell)
area.nw                         # => LLA (northwest corner)
area.se                         # => LLA (southeast corner)
```

## Equality

Two GARS instances are equal if their code strings match exactly.

```ruby
GARS.new("006AG39") == GARS.new("006AG39")   # => true
GARS.new("006AG39") == GARS.new("006AG38")   # => false
```

## `valid?`

Returns `true` if the code has a valid length (5, 6, or 7), a longitude band between 001-720, valid latitude letters (A-Z excluding I and O), a valid quadrant digit (1-4), and a valid keypad digit (1-9).

```ruby
coord.valid?    # => true
```

## Universal Distance and Bearing Methods

GARS supports all universal distance and bearing methods via the `DistanceMethods` and `BearingMethods` mixins:

```ruby
a = GARS.new("361HN35")
b = GARS.new("212LX43")

a.distance_to(b)                # => Distance
a.straight_line_distance_to(b)  # => Distance
a.bearing_to(b)                 # => Bearing
a.elevation_to(b)               # => Float (degrees)
```

## Encoding Details

### Longitude Bands

720 bands of 0.5 degrees each, numbered 001-720 from west to east:
- Band 001: -180.0 to -179.5
- Band 361: 0.0 to 0.5
- Band 720: 179.5 to 180.0

### Latitude Bands

360 bands of 0.5 degrees each, encoded as 2-letter pairs (AA-QZ) from south to north:
- AA: -90.0 to -89.5
- HN: 0.0 to 0.5
- QZ: 89.5 to 90.0

The 24-letter alphabet (A-Z, excluding I and O) gives 24 x 15 = 360 valid combinations.

## Well-Known GARS Codes

| Location | GARS Code | Description |
|----------|-----------|-------------|
| Null Island (0, 0) | 361HN | 30-minute cell at equator/prime meridian |
| New York City | 212LX43 | 5-minute cell |
| Western boundary | 001xx | Longitude -180.0 |
