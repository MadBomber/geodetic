# Geodetic Arithmetic Reference

Geodetic provides operator overloading that lets you compose geometric objects naturally. The `+` operator builds geometry from parts, while `*` (and its alias `translate`) applies a vector displacement to shift objects.

---

## Design Principles

1. **Type determines result** — the types of the operands, not their values, determine the return type. `Coordinate + Coordinate` always returns a Segment, never conditionally a different type.

2. **Left operand is the anchor** — in asymmetric operations, the left operand provides the reference point. `P1 + V` creates a segment starting at P1; `V + P1` creates a segment ending at P1.

3. **Consistent translation** — `*` always means "translate by this vector," returning the same type as the receiver. A translated Segment is still a Segment; a translated Path is still a Path.

---

## The + Operator: Building Geometry

The `+` operator composes smaller geometric objects into larger ones. The result type depends on the combination of operand types.

### Coordinate + Coordinate → Segment

Two points define a directed line segment.

```ruby
seattle = Geodetic::Coordinate::LLA.new(lat: 47.62, lng: -122.35, alt: 0)
portland = Geodetic::Coordinate::LLA.new(lat: 45.52, lng: -122.68, alt: 0)

seg = seattle + portland  # => Geodetic::Segment
seg.start_point           # => seattle
seg.end_point             # => portland
seg.length                # => Distance (~235 km)
seg.bearing               # => Bearing (~186°)
```

Works across any coordinate system — the Segment converts both points to LLA internally:

```ruby
utm = portland.to_utm
seg = seattle + utm       # => Segment (seattle → portland via LLA)
```

Order matters: `seattle + portland` is a different segment than `portland + seattle`.

### Coordinate + Coordinate + Coordinate → Path

Chaining builds a path. The first `+` produces a Segment; the second `+` extends it into a Path.

```ruby
path = seattle + portland + sf  # => Geodetic::Path (3 points)
path.size                       # => 3
path.first                      # => seattle
path.last                       # => sf
```

Further chaining continues to extend the Path:

```ruby
path = seattle + portland + sf + la + nyc  # => Path (5 points)
```

### Coordinate + Segment → Path

A point plus a segment produces a three-point path: the point, then the segment's endpoints.

```ruby
seg = portland + sf
path = seattle + seg  # => Path: seattle → portland → sf
path.size             # => 3
```

### Segment + Coordinate → Path

Extending a segment with a point:

```ruby
seg = seattle + portland
path = seg + sf       # => Path: seattle → portland → sf
```

### Segment + Segment → Path

Two segments concatenate into a four-point path:

```ruby
seg1 = seattle + portland
seg2 = sf + la
path = seg1 + seg2    # => Path: seattle → portland → sf → la
```

### Coordinate + Distance → Circle

A point plus a distance defines a circle.

```ruby
radius = Geodetic::Distance.km(5)
circle = seattle + radius
# => Areas::Circle centered at seattle, 5000m radius
```

### Distance + Coordinate → Circle

Commutative — same result:

```ruby
circle = Geodetic::Distance.km(5) + seattle
# => Areas::Circle centered at seattle, 5000m radius
```

### Coordinate + Vector → Segment

A point plus a vector solves the Vincenty direct problem, producing a segment from the origin to the destination.

```ruby
v = Geodetic::Vector.new(distance: 100_000, bearing: 45.0)
seg = seattle + v
# => Segment from seattle to a point 100km northeast
seg.length_meters  # => ~100000.0
seg.bearing        # => ~45°
```

This is different from translation (`*`): `+` gives you the journey (a Segment), while `*` gives you just the destination (a Coordinate).

### Vector + Coordinate → Segment

The vector reversed determines the start point; the coordinate is the endpoint.

```ruby
v = Geodetic::Vector.new(distance: 10_000, bearing: 90.0)
seg = v + seattle
# => Segment from (10km west of seattle) to seattle
```

### Segment + Vector → Path

Extends the segment from its endpoint in the vector's direction.

```ruby
seg = seattle + portland
v = Geodetic::Vector.new(distance: 50_000, bearing: 180.0)
path = seg + v
# => Path: seattle → portland → (50km south of portland)
```

### Vector + Segment → Path

Prepends a new start point. The vector is reversed from the segment's start to find it.

```ruby
v = Geodetic::Vector.new(distance: 50_000, bearing: 90.0)
seg = seattle + portland
path = v + seg
# => Path: (50km west of seattle) → seattle → portland
```

### Path + Vector → Path

Extends the path from its last point in the vector's direction.

```ruby
path = seattle + portland + sf
v = Geodetic::Vector.new(distance: 100_000, bearing: 180.0)
path2 = path + v
# => Path: seattle → portland → sf → (100km south of sf)
```

### Path + Coordinate → Path

Appends a waypoint (already existed before arithmetic was added):

```ruby
path = seattle + portland
path2 = path + sf  # => Path: seattle → portland → sf
```

### Path + Path → Path

Concatenates two paths (already existed):

```ruby
west_coast = seattle + portland + sf
east_coast = nyc + dc
cross_country = west_coast + east_coast
```

---

## Complete + Operator Table

| Left | + Right | Result | Description |
|------|---------|--------|-------------|
| Coordinate | Coordinate | Segment | Two-point directed segment |
| Coordinate | Vector | Segment | Origin to Vincenty destination |
| Coordinate | Distance | Circle | Point + radius |
| Coordinate | Segment | Path | Point then segment endpoints |
| Segment | Coordinate | Path | Extend with waypoint |
| Segment | Segment | Path | Concatenate segments |
| Segment | Vector | Path | Extend from endpoint |
| Vector | Coordinate | Segment | Reverse start to coordinate |
| Vector | Segment | Path | Prepend via reverse |
| Vector | Vector | Vector | Component-wise addition |
| Distance | Coordinate | Circle | Radius + center |
| Path | Coordinate | Path | Append waypoint |
| Path | Path | Path | Concatenate |
| Path | Segment | Path | Append segment points |
| Path | Vector | Path | Extend from last point |

---

## The * Operator: Translation

The `*` operator translates (shifts) a geometric object by a vector displacement. Every point in the object is moved by the same vector. The result is always the same type as the receiver.

The named method `translate` is an alias for `*`.

### Coordinate * Vector → Coordinate

Returns the destination point — the pure result of moving the point.

```ruby
v = Geodetic::Vector.new(distance: 10_000, bearing: 0.0)
p2 = seattle * v           # => LLA (10km north of seattle)
p2 = seattle.translate(v)  # => same
```

Compare with `+`: `seattle + v` returns a **Segment** (the journey); `seattle * v` returns a **Coordinate** (just the destination).

### Segment * Vector → Segment

Both endpoints are translated by the same vector. Length and bearing are preserved.

```ruby
seg = Geodetic::Segment.new(seattle, portland)
v = Geodetic::Vector.new(distance: 100_000, bearing: 90.0)

shifted = seg * v
shifted = seg.translate(v)

shifted.length_meters  # => same as original
shifted.start_point    # => 100km east of seattle
shifted.end_point      # => 100km east of portland
```

### Path * Vector → Path

All waypoints are translated. The shape and distances between points are preserved.

```ruby
route = seattle + portland + sf
v = Geodetic::Vector.new(distance: 50_000, bearing: 0.0)

shifted = route * v           # => Path shifted 50km north
shifted = route.translate(v)  # => same
shifted.size                  # => 3
```

### Circle * Vector → Circle

The centroid is translated. The radius is preserved.

```ruby
circle = Geodetic::Areas::Circle.new(centroid: seattle, radius: 5000)
v = Geodetic::Vector.new(distance: 10_000, bearing: 180.0)

shifted = circle * v           # => Circle 10km south, same 5km radius
shifted = circle.translate(v)  # => same
shifted.radius                 # => 5000.0
```

### Polygon * Vector → Polygon

All boundary vertices are translated. The shape is preserved.

```ruby
a = LLA.new(lat: 40.0, lng: -74.0, alt: 0)
b = LLA.new(lat: 40.0, lng: -73.0, alt: 0)
c = LLA.new(lat: 41.0, lng: -73.5, alt: 0)
poly = Geodetic::Areas::Polygon.new(boundary: [a, b, c])

v = Geodetic::Vector.new(distance: 100_000, bearing: 0.0)
shifted = poly * v           # => Polygon shifted 100km north
shifted = poly.translate(v)  # => same
```

---

## Complete * Operator Table

| Object | * Vector | Result | Effect |
|--------|----------|--------|--------|
| Coordinate | Vector | Coordinate | Translate point |
| Segment | Vector | Segment | Translate both endpoints |
| Path | Vector | Path | Translate all waypoints |
| Circle | Vector | Circle | Translate centroid, preserve radius |
| Polygon | Vector | Polygon | Translate all vertices |

The `*` operator only accepts a `Vector` on the right side. Any other type raises `ArgumentError`.

---

## Corridors

`Path#to_corridor(width:)` converts a path into a polygon by offsetting each waypoint perpendicular to the path bearing on both sides.

```ruby
route = seattle + portland + sf
corridor = route.to_corridor(width: 1000)          # 1km wide
corridor = route.to_corridor(width: Distance.km(1)) # also accepts Distance
# => Areas::Polygon with 2*N boundary vertices
```

At interior waypoints, the perpendicular direction uses the mean bearing of the two adjacent segments to avoid self-intersection at bends.

Requires at least 2 coordinates. The `width:` parameter accepts meters (Numeric) or a `Distance` object.

---

## Combining + and *

The operators compose naturally:

```ruby
# Build a route, then shift it
v = Geodetic::Vector.new(distance: 50_000, bearing: 90.0)
route = (seattle + portland + sf) * v  # shifted 50km east

# Build a circle, then translate it
circle = (seattle + Distance.km(5)) * v

# Chain: point + vector gives segment, then extend
seg = seattle + Geodetic::Vector.new(distance: 100_000, bearing: 45.0)
path = seg + portland  # 3-point path

# Translate a corridor
corridor = route.to_corridor(width: 500)
shifted_corridor = corridor * v
```

---

## Key Distinctions

### + vs * with Vector

This is the most important distinction to understand:

| Expression | Result | Meaning |
|-----------|--------|---------|
| `P + V` | Segment | The **journey** — where you started and where you arrived |
| `P * V` | Coordinate | The **destination** — just where you end up |

`P + V` gives you a Segment because building geometry is the purpose of `+`. The segment records both the origin and the destination.

`P * V` gives you a Coordinate because translation is the purpose of `*`. You're moving the point, not creating a composite object.

### Commutativity

Most `+` operations are **not** commutative — order determines the structure:

- `P1 + P2` starts at P1; `P2 + P1` starts at P2
- `P + V` creates a segment starting at P; `V + P` creates a segment ending at P

The exceptions are:

- `P + Distance` and `Distance + P` both produce the same Circle
- `V1 + V2` and `V2 + V1` produce the same Vector (component addition is commutative)

Translation (`*`) is always `object * vector` — the vector must be on the right.
