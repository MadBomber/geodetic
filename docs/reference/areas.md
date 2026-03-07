# Areas Reference

The `Geodetic::Areas` module provides two geometric area classes for point-in-area testing: `Circle` and `Polygon`. Both operate on `Geodetic::Coordinates::LLA` points.

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

### Note

The `includes?` method relies on `LLA#distance_to`, which is not yet implemented in the current codebase. This method must be added to LLA before Circle can function.

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

### Note

The `includes?` method relies on `LLA#heading_to`, which is not yet implemented in the current codebase. This method must be added to LLA before Polygon's point-in-polygon test can function.
