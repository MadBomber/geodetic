# Areas Reference

The `Geodetic::Areas` module provides three geometric area classes for point-in-area testing: `Circle`, `Polygon`, and `Rectangle`. All operate on `Geodetic::Coordinates::LLA` points.

---

## Geodetic::Areas::Circle

Defines a circular area on the Earth's surface.

### Constructor

```ruby
center = Geodetic::Coordinates::LLA.new(lat: 38.8977, lng: -77.0365, alt: 0.0)

circle = Geodetic::Areas::Circle.new(
  centroid: center,   # LLA point at the center
  radius:   1000.0    # radius in meters
)
```

### Attributes

| Attribute | Type | Description |
|-----------|------|-------------|
| `centroid` | LLA  | The center point of the circle |
| `radius`   | Float | The radius in meters |

### Methods

#### `includes?(a_point)` / `include?(a_point)` / `inside?(a_point)`

Returns `true` if the given LLA point falls within (or on the boundary of) the circle. The distance from centroid to the point is compared against the radius.

```ruby
point = Geodetic::Coordinates::LLA.new(lat: 38.898, lng: -77.036, alt: 0.0)
circle.includes?(point)  # => true or false
```

#### `excludes?(a_point)` / `exclude?(a_point)` / `outside?(a_point)`

Returns `true` if the given LLA point falls outside the circle. The logical inverse of `includes?`.

```ruby
circle.excludes?(point)  # => true or false
```

### Alias Summary

| Primary Method | Aliases |
|---------------|---------|
| `includes?` | `include?`, `inside?` |
| `excludes?` | `exclude?`, `outside?` |

---

## Geodetic::Areas::Polygon

Defines an arbitrary polygon area on the Earth's surface.

### Constructor

```ruby
boundary = [
  Geodetic::Coordinates::LLA.new(lat: 38.90, lng: -77.04, alt: 0.0),
  Geodetic::Coordinates::LLA.new(lat: 38.90, lng: -77.03, alt: 0.0),
  Geodetic::Coordinates::LLA.new(lat: 38.89, lng: -77.03, alt: 0.0),
  Geodetic::Coordinates::LLA.new(lat: 38.89, lng: -77.04, alt: 0.0)
]

polygon = Geodetic::Areas::Polygon.new(boundary: boundary)
```

A minimum of 3 points is required. The constructor throws an error if fewer points are provided.

The polygon is automatically closed: if the first and last points in the boundary array are not equal, the first point is appended to close the polygon.

### Attributes

| Attribute | Type | Description |
|-----------|------|-------------|
| `boundary` | Array<LLA> | The ordered array of LLA points forming the polygon boundary (auto-closed) |
| `centroid` | LLA | The computed centroid of the polygon, calculated automatically during initialization |

### Centroid Calculation

The centroid is computed using the standard polygon centroid formula based on the signed area of the polygon in the latitude/longitude coordinate space. This is calculated automatically during initialization and stored in the `centroid` attribute.

### Methods

#### `includes?(a_point)` / `include?(a_point)` / `inside?(a_point)`

Returns `true` if the given LLA point falls within the polygon. Uses the winding angle algorithm: sums the turning angles from the test point to each consecutive pair of boundary vertices. If the absolute accumulated angle exceeds 180 degrees, the point is inside.

Also returns `true` if the point is exactly equal to any boundary vertex.

```ruby
point = Geodetic::Coordinates::LLA.new(lat: 38.895, lng: -77.035, alt: 0.0)
polygon.includes?(point)  # => true or false
```

#### `excludes?(a_point)` / `exclude?(a_point)` / `outside?(a_point)`

Returns `true` if the given LLA point falls outside the polygon. The logical inverse of `includes?`.

```ruby
polygon.excludes?(point)  # => true or false
```

### Alias Summary

| Primary Method | Aliases |
|---------------|---------|
| `includes?` | `include?`, `inside?` |
| `excludes?` | `exclude?`, `outside?` |

---

## Geodetic::Areas::Rectangle

Defines an axis-aligned rectangle by its northwest and southeast corners.

### Constructor

```ruby
nw = Geodetic::Coordinates::LLA.new(lat: 41.0, lng: -75.0)
se = Geodetic::Coordinates::LLA.new(lat: 40.0, lng: -74.0)

rectangle = Geodetic::Areas::Rectangle.new(nw: nw, se: se)
```

The constructor accepts any coordinate type that responds to `to_lla` -- coordinates are automatically converted to LLA.

```ruby
nw_wm = Geodetic::Coordinates::WebMercator.from_lla(nw)
se_wm = Geodetic::Coordinates::WebMercator.from_lla(se)
rectangle = Geodetic::Areas::Rectangle.new(nw: nw_wm, se: se_wm)
```

Raises `ArgumentError` if the NW corner has a lower latitude than the SE corner, or if the NW corner has a higher longitude than the SE corner.

### Attributes

| Attribute  | Type | Description |
|------------|------|-------------|
| `nw`       | LLA  | The northwest corner (max latitude, min longitude) |
| `se`       | LLA  | The southeast corner (min latitude, max longitude) |
| `centroid` | LLA  | The center point, computed automatically |

All attributes are read-only.

### Computed Corners

```ruby
rectangle.ne    # => LLA (nw.lat, se.lng)
rectangle.sw    # => LLA (se.lat, nw.lng)
```

### Methods

#### `includes?(a_point)` / `include?(a_point)` / `inside?(a_point)`

Returns `true` if the given point falls within (or on the boundary of) the rectangle. Accepts any coordinate type that responds to `to_lla`.

```ruby
point = Geodetic::Coordinates::LLA.new(lat: 40.5, lng: -74.5)
rectangle.includes?(point)  # => true
```

#### `excludes?(a_point)` / `exclude?(a_point)` / `outside?(a_point)`

Returns `true` if the given point falls outside the rectangle.

```ruby
rectangle.excludes?(point)  # => true or false
```

### Alias Summary

| Primary Method | Aliases |
|---------------|---------|
| `includes?` | `include?`, `inside?` |
| `excludes?` | `exclude?`, `outside?` |

### Integration with GH36

`Geodetic::Coordinates::GH36#to_area` returns a `Rectangle` representing the geohash cell's bounding box:

```ruby
gh36 = Geodetic::Coordinates::GH36.new("bdrdC26BqH")
area = gh36.to_area
# => Geodetic::Areas::Rectangle

area.includes?(gh36.to_lla)  # => true (midpoint is inside the cell)
```
