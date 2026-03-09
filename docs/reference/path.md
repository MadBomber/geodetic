# Path Reference

`Geodetic::Path` represents a directed, ordered sequence of unique coordinates. It models routes, trails, boundaries, and any linear geographic feature where the order of waypoints matters.

A Path has a start (first coordinate) and an end (last coordinate). No duplicate coordinates are allowed — each waypoint appears exactly once, enabling unambiguous navigation with `next` and `prev`.

Path includes Ruby's `Enumerable` module, so all standard iteration methods (`map`, `select`, `any?`, `to_a`, etc.) are available.

---

## Constructor

```ruby
# Empty path
path = Path.new

# From an array of coordinates
path = Path.new(coordinates: [a, b, c, d])
```

Raises `ArgumentError` if any coordinate appears more than once.

---

## Attributes

| Attribute     | Type  | Description |
|---------------|-------|-------------|
| `coordinates` | Array | The ordered list of waypoints (read-only) |

---

## Navigation

| Method              | Returns     | Description |
|---------------------|-------------|-------------|
| `first`             | Coordinate  | Starting waypoint |
| `last`              | Coordinate  | Ending waypoint |
| `next(coordinate)`  | Coordinate  | Waypoint after the given one, or `nil` at end |
| `prev(coordinate)`  | Waypoint before the given one, or `nil` at start |
| `size`              | Integer     | Number of waypoints |
| `empty?`            | Boolean     | True if the path has no waypoints |
| `segments`          | Array       | Pairs of consecutive coordinates `[[a,b], [b,c], ...]` |

---

## Membership

| Method | Description |
|--------|-------------|
| `include?(coord)` | True if the coordinate is a waypoint in the path |
| `includes?(coord)` | Alias for `include?` |
| `contains?(coord, tolerance: 10.0)` | True if the coordinate lies on any segment within tolerance (meters) |
| `inside?(coord, tolerance: 10.0)` | Alias for `contains?` |
| `excludes?(coord, tolerance: 10.0)` | Opposite of `contains?` |
| `exclude?(coord)` | Alias for `excludes?` |
| `outside?(coord)` | Alias for `excludes?` |

`includes?` checks waypoints only. `contains?` checks whether a coordinate lies on the line between any two consecutive waypoints, using a bearing comparison with a tolerance derived from the segment length.

---

## Equality

```ruby
path1 == path2
```

Two paths are equal if they have the same coordinates in the same order.

---

## Spatial Methods

| Method | Returns | Description |
|--------|---------|-------------|
| `nearest_waypoint(target)` | Coordinate | The waypoint closest to the target |
| `closest_coordinate_to(target)` | Coordinate | The closest point on the path (projected onto segments) |
| `distance_to(other)` | Distance | Distance from the closest point on the path to the target |
| `bearing_to(other)` | Bearing | Bearing from the closest point on the path to the target |
| `closest_points_to(other)` | Hash | Closest pair between path and an Area or another Path |

The `other` parameter for `distance_to`, `bearing_to`, and `closest_coordinate_to` can be a coordinate, a Feature, an Area, or another Path.

### Closest Points

`closest_points_to` returns a hash with:

```ruby
{
  path_point: Coordinate,  # closest point on this path
  area_point: Coordinate,  # closest point on the other geometry
  distance:   Distance     # distance between the two points
}
```

Accepts `Areas::Circle`, `Areas::Polygon`, `Areas::BoundingBox`, or another `Path`.

---

## Computed Properties

| Method | Returns | Description |
|--------|---------|-------------|
| `total_distance` | Distance | Sum of all segment distances |
| `segment_distances` | Array | Distance for each segment |
| `segment_bearings` | Array | Bearing for each segment |
| `reverse` | Path | New path with coordinates in reverse order |

---

## Subpath and Split

### `between(from, to)`

Extracts a subpath between two waypoints (inclusive). Both must exist in the path, and `from` must precede `to`.

```ruby
sub = route.between(wall_street, union_square)
```

### `split_at(coordinate)`

Splits the path at a waypoint, returning two paths that share the split point.

```ruby
left, right = route.split_at(city_hall)
# left ends with city_hall, right starts with city_hall
```

---

## Interpolation

### `at_distance(distance)`

Returns the coordinate at a given distance along the path from the start. Accepts a `Distance` object or a numeric value in meters.

```ruby
halfway = route.at_distance(route.total_distance.meters / 2.0)
quarter = route.at_distance(Distance.new(route.total_distance.meters * 0.25))
```

Returns the last coordinate if the distance exceeds the total path length.

---

## Bounding Box

### `bounds`

Returns an `Areas::BoundingBox` representing the axis-aligned bounding box of all waypoints.

```ruby
bbox = route.bounds
bbox.nw  # => northwest corner
bbox.se  # => southeast corner
bbox.includes?(some_point)  # => true/false
```

---

## To Polygon

### `to_polygon`

Closes the path into an `Areas::Polygon` by connecting the last coordinate to the first. Requires at least 3 coordinates. Raises `ArgumentError` if the closing segment would intersect any interior segment of the path.

```ruby
triangle = Path.new(coordinates: [a, b, c])
poly = triangle.to_polygon
poly.includes?(some_point)
```

---

## Intersection

### `intersects?(other_path)`

Returns true if any segment of this path crosses any segment of the other path. Uses orientation-based intersection testing.

```ruby
route.intersects?(crosstown)  # => true/false
```

---

## Non-Mutating Operators

These return new Path objects; the original is unchanged.

| Operator | Accepts | Description |
|----------|---------|-------------|
| `+ coordinate` | Coordinate | New path with coordinate appended |
| `+ path` | Path | New path with all coordinates of the other path appended |
| `- coordinate` | Coordinate | New path with coordinate removed |
| `- path` | Path | New path with all of the other path's coordinates removed |

```ruby
combined = downtown_path + uptown_path
trimmed  = full_route - detour_path
```

Raises `ArgumentError` if `+` would create duplicates, or if `-` references coordinates not in the path.

---

## Mutating Operators

These modify the path in place and return `self` for chaining.

| Method | Accepts | Description |
|--------|---------|-------------|
| `<< other` | Coordinate or Path | Append to end |
| `>> other` | Coordinate or Path | Prepend to start |
| `prepend(other)` | Coordinate or Path | Same as `>>` |
| `insert(coord, after: ref)` | Coordinate | Insert after a reference waypoint |
| `insert(coord, before: ref)` | Coordinate | Insert before a reference waypoint |
| `delete(coord)` | Coordinate | Remove a waypoint |
| `remove(coord)` | Coordinate | Alias for `delete` |

```ruby
path = Path.new
path << a << b << c          # build incrementally
path >> start_point           # prepend
path << other_path            # append an entire path
path.insert(detour, after: b) # insert between waypoints
path.delete(b)                # remove a waypoint
```

---

## Enumerable

Path includes `Enumerable`. The `each` method iterates over coordinates in order.

```ruby
route.map { |c| c.lat }
route.select { |c| c.lat > 40.72 }
route.max_by { |c| c.lat }
route.to_a
```

---

## Display

| Method | Returns |
|--------|---------|
| `to_s` | `"Path(7): 40.70... -> 40.71... -> ..."` |
| `inspect` | `"#<Geodetic::Path size=7 first=... last=...>"` |

---

## Feature Integration

A Path can be used as the geometry of a `Feature`. When a Feature wraps a Path, `distance_to` and `bearing_to` use the Path's geometric projection to find the closest approach point.

```ruby
hiking_route = Feature.new(
  label:    "Manhattan Walking Tour",
  geometry: route,
  metadata: { type: "walking" }
)

hiking_route.distance_to(statue_of_liberty).to_km
hiking_route.bearing_to(statue_of_liberty).to_compass
```
