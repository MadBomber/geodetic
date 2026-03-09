# Geodetic::Coordinate::HAM

## Maidenhead Locator System

The Maidenhead Locator System (also called QTH Locator or grid square) is a hierarchical geocoding system used worldwide in amateur radio. It encodes latitude/longitude into a compact string of alternating letter and digit pairs.

The system uses a false coordinate origin that shifts longitude by +180 and latitude by +90, making all values positive before encoding. Four levels of subdivision produce strings of 2, 4, 6, or 8 characters:

| Level | Name | Characters | Grid Size | Divisions |
|-------|------|-----------|-----------|-----------|
| 1 | Field | 2 letters (A-R) | 20 x 10 | 18 x 18 |
| 2 | Square | 2 digits (0-9) | 2 x 1 | 10 x 10 |
| 3 | Subsquare | 2 letters (a-x) | 5' x 2.5' | 24 x 24 |
| 4 | Extended | 2 digits (0-9) | 30" x 15" | 10 x 10 |

Convention: Field letters are uppercase, subsquare letters are lowercase (e.g., `FN31pr`).

HAM is a **2D coordinate system** (no altitude). Conversions to/from other systems go through LLA as the intermediary. Each locator string represents a rectangular cell; the coordinate's point value is the cell's midpoint.

## Constructor

```ruby
# From a Maidenhead locator string
coord = Geodetic::Coordinate::HAM.new("FN31pr")

# From any coordinate (converts via LLA)
coord = Geodetic::Coordinate::HAM.new(lla_coord)
coord = Geodetic::Coordinate::HAM.new(utm_coord, precision: 8)
```

| Parameter   | Type              | Default | Description                                    |
|-------------|-------------------|---------|------------------------------------------------|
| `source`    | String or Coord   | —       | A Maidenhead string or any coordinate object   |
| `precision` | Integer           | 6       | Locator length: 2, 4, 6, or 8 (must be even)  |

Raises `ArgumentError` if the source string is empty, has odd length, exceeds 8 characters, or contains invalid characters for any level. String input normalizes Field to uppercase, Subsquare to lowercase.

## Attributes

| Attribute  | Type   | Access    | Description                        |
|------------|--------|-----------|------------------------------------|
| `locator`  | String | read-only | The Maidenhead locator string      |

HAM is **immutable** — there are no setter methods.

## Precision

The precision (locator length) determines the size of the grid square:

| Length | Level | Approximate Cell Size |
|--------|-------|----------------------|
| 2      | Field | 1,113 km x 2,226 km |
| 4      | Square | 111 km x 222 km |
| 6      | Subsquare | 4.6 km x 9.3 km |
| 8      | Extended | 463 m x 926 m |

```ruby
coord.precision              # => 6 (locator length)
coord.precision_in_meters    # => { lat: 4631.0, lng: 9260.0 }
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
coord.to_olc
```

### Class Methods

```ruby
HAM.from_lla(lla_coord)
HAM.from_ecef(ecef_coord)
HAM.from_utm(utm_coord)
HAM.from_web_mercator(wm_coord)
HAM.from_gh(gh_coord)
HAM.from_gh36(gh36_coord)
HAM.from_olc(olc_coord)
# ... and all other coordinate systems
```

### LLA Convenience Methods

```ruby
lla = Geodetic::Coordinate::LLA.new(lat: 40.689167, lng: -74.044444)
ham = lla.to_ham                    # default precision 6
ham = lla.to_ham(precision: 8)      # extended precision

lla = Geodetic::Coordinate::LLA.from_ham(ham)
```

## Serialization

### `to_s(truncate_to = nil)`

Returns the locator string. An optional integer truncates to that length (rounded down to even, minimum 2).

```ruby
coord = HAM.new("FN31pr45")
coord.to_s       # => "FN31pr45"
coord.to_s(6)    # => "FN31pr"
coord.to_s(4)    # => "FN31"
```

### `to_a`

Returns `[lat, lng]` of the cell midpoint.

```ruby
coord.to_a    # => [41.729..., -73.958...]
```

### `from_string` / `from_array`

```ruby
HAM.from_string("FN31pr")              # from locator string
HAM.from_array([40.689, -74.044])       # from [lat, lng]
```

## Neighbors

Returns all 8 adjacent grid squares as HAM instances.

```ruby
coord = HAM.new("FN31pr")
neighbors = coord.neighbors
# => { N: HAM, S: HAM, E: HAM, W: HAM, NE: HAM, NW: HAM, SE: HAM, SW: HAM }

neighbors[:N].to_lla.lat > coord.to_lla.lat   # => true
neighbors[:E].to_lla.lng > coord.to_lla.lng   # => true
```

Neighbors preserve the same precision as the original locator. Latitude is clamped to valid range near the poles; longitude wraps at the antimeridian.

## Area

The `to_area` method returns the grid square as a `Geodetic::Areas::BoundingBox`.

```ruby
area = coord.to_area
# => Geodetic::Areas::BoundingBox

area.includes?(coord.to_lla)    # => true (midpoint is inside the cell)
area.nw                         # => LLA (northwest corner)
area.se                         # => LLA (southeast corner)
```

## Equality

Two HAM instances are equal if their locator strings match exactly.

```ruby
HAM.new("FN31pr") == HAM.new("FN31pr")   # => true
HAM.new("FN31pr") == HAM.new("FN31ps")   # => false
```

## `valid?`

Returns `true` if the locator has valid characters at each level and an even length.

```ruby
coord.valid?    # => true
```

## Universal Distance and Bearing Methods

HAM supports all universal distance and bearing methods via the `DistanceMethods` and `BearingMethods` mixins:

```ruby
a = HAM.new("FN31pr")
b = HAM.new("IO91wm")

a.distance_to(b)                # => Distance (~5,570 km)
a.straight_line_distance_to(b)  # => Distance
a.bearing_to(b)                 # => Bearing (~51)
a.elevation_to(b)               # => Float (degrees)
```

## Well-Known Locators

| Location | Locator |
|----------|---------|
| New York City | FN30 |
| London | IO91 |
| Tokyo | PM95 |
| Sydney | QF56 |
| Origin (0, 0) | JJ00 |
