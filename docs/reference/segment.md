# Segment Reference

`Geodetic::Segment` represents a directed line segment between two points on the Earth's surface. It is the fundamental geometric primitive underlying `Path` segments, `Polygon` edges, and closest-approach calculations.

A Segment has a `start_point` and an `end_point`, both stored as `Coordinate::LLA`. Properties like `length`, `bearing`, and `midpoint` are computed lazily and cached.

---

## Great Circle Arcs

On a sphere, any two points that are not antipodal (diametrically opposite) define a great circle, and that great circle produces two arcs between them: the **minor arc** (the shorter path) and the **major arc** (the longer way around the globe).

Segment always uses the **minor arc**. All operations — `length`, `bearing`, `interpolate`, `project`, `contains?` — follow the shortest path between the two endpoints via Vincenty geodesic calculations.

For **antipodal points** (exactly opposite sides of the Earth, roughly 20,000 km apart), the great circle is degenerate: there are infinitely many paths of equal length and the bearing is undefined.

In practice, real-world segments rarely approach even a quarter of the Earth's circumference (~10,000 km), so the minor arc assumption holds for virtually all use cases.

---

## Constructor

```ruby
a = Geodetic::Coordinate::LLA.new(lat: 40.7484, lng: -73.9857, alt: 0)
b = Geodetic::Coordinate::LLA.new(lat: 40.7580, lng: -73.9855, alt: 0)

seg = Geodetic::Segment.new(a, b)
```

Accepts any coordinate type that responds to `to_lla`. Endpoints are converted to LLA on construction.

---

## Attributes

| Attribute     | Type | Description |
|---------------|------|-------------|
| `start_point` | LLA  | The starting point of the segment |
| `end_point`   | LLA  | The ending point of the segment |

---

## Properties

All properties are lazily computed and cached after first access.

| Method         | Returns  | Description |
|----------------|----------|-------------|
| `length`       | Distance | Great-circle distance between endpoints |
| `length_meters`| Float    | Length in meters (convenience accessor) |
| `bearing`      | Bearing  | Forward azimuth from start to end |
| `midpoint`     | LLA      | Point at the halfway mark |

```ruby
seg.length           # => #<Geodetic::Distance 1067.45 m>
seg.length_meters    # => 1067.45
seg.bearing          # => #<Geodetic::Bearing 1.0°>
seg.midpoint         # => LLA at the midpoint
```

---

## Geometry

### `reverse`

Returns a new Segment with start and end points swapped.

```ruby
rev = seg.reverse
rev.start_point == seg.end_point  # => true
```

### `interpolate(fraction)`

Returns the LLA coordinate at a given fraction (0.0 to 1.0) along the segment.

```ruby
seg.interpolate(0.0)   # => start_point
seg.interpolate(0.5)   # => midpoint
seg.interpolate(1.0)   # => end_point
seg.interpolate(0.25)  # => quarter-way along
```

---

## Projection

### `project(point)`

Projects a point onto the segment, returning the closest point on the segment and the distance in meters.

```ruby
foot, distance_m = seg.project(target_point)
```

- If the perpendicular foot falls within the segment, returns the foot and the perpendicular distance.
- If the foot falls before the start, returns `start_point`.
- If the foot falls past the end, returns `end_point`.
- Handles zero-length segments and target-at-endpoint edge cases.

This is the core geometric operation used by `Path#closest_coordinate_to`, `Path#closest_points_to`, and `Path#at_distance`.

---

## Membership

| Method | Description |
|--------|-------------|
| `includes?(point)` | True if the point is a vertex (start or end point) |
| `contains?(point, tolerance: 10.0)` | True if the point lies on the segment within tolerance (meters) |
| `excludes?(point, tolerance: 10.0)` | Opposite of `contains?` |

`includes?` checks vertices only. `contains?` checks whether a point lies anywhere along the line between the two endpoints using a bearing comparison with a tolerance derived from the segment length.

```ruby
seg.includes?(seg.start_point)     # => true
seg.includes?(seg.midpoint)        # => false

seg.contains?(seg.midpoint)        # => true
seg.contains?(far_away_point)      # => false
```

---

## Intersection

### `intersects?(other_segment)`

Tests whether two segments cross each other using cross-product orientation tests on a flat lat/lng approximation. Handles both proper intersections and collinear overlap.

```ruby
seg1 = Geodetic::Segment.new(a, b)
seg2 = Geodetic::Segment.new(c, d)

seg1.intersects?(seg2)  # => true/false
```

Used internally by `Path#intersects?` and `Path#to_polygon` for self-intersection validation.

---

## Conversion

| Method   | Returns | Description |
|----------|---------|-------------|
| `to_path`| Path    | A two-point Path from start to end |
| `to_a`   | Array   | `[start_point, end_point]` |

```ruby
seg.to_path   # => #<Geodetic::Path size=2 ...>
seg.to_a      # => [start_point, end_point]
```

---

## Equality and Display

```ruby
seg1 == seg2   # true if same start and end points

seg.to_s       # => "Segment(40.748400, ... -> 40.758000, ...)"
seg.inspect    # => "#<Geodetic::Segment start=... end=... length=1067.45 m>"
```

Two segments are equal if they have the same start and end points. Direction matters: `Segment.new(a, b) != Segment.new(b, a)`.

---

## Relationship to Path and Polygon

`Path#segments` returns an array of Segment objects:

```ruby
route = Path.new(coordinates: [a, b, c, d])
route.segments  # => [Segment(a→b), Segment(b→c), Segment(c→d)]
```

Polygon edges are implicit segments formed by consecutive boundary points. Segment's `project`, `intersects?`, and `contains?` methods power the geometric operations in both Path and Polygon.
