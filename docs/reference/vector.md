# Vector Reference

`Geodetic::Vector` represents a geodetic displacement — a combination of distance (magnitude) and bearing (direction). It is the fundamental type for expressing "how far and which way" between two points on Earth.

A Vector solves the **Vincenty direct problem**: given an origin point, a bearing, and a distance, compute the destination point on the WGS84 ellipsoid.

---

## Constructor

```ruby
# From numeric values (meters and degrees)
v = Geodetic::Vector.new(distance: 10_000, bearing: 90.0)

# From Distance and Bearing objects
v = Geodetic::Vector.new(
  distance: Geodetic::Distance.km(10),
  bearing:  Geodetic::Bearing.new(90.0)
)
```

Numeric arguments are automatically coerced: `distance` wraps into `Distance.new(value)` and `bearing` wraps into `Bearing.new(value)`.

---

## Attributes

| Attribute  | Type     | Description |
|------------|----------|-------------|
| `distance` | Distance | The magnitude of the vector |
| `bearing`  | Bearing  | The direction of the vector (0-360 degrees from north) |

---

## Components

A Vector decomposes into north/east components in meters, treating bearing as an angle measured clockwise from north.

| Method | Returns | Description |
|--------|---------|-------------|
| `north` | Float | North component: `distance * cos(bearing)` |
| `east`  | Float | East component: `distance * sin(bearing)` |

```ruby
v = Geodetic::Vector.new(distance: 1000, bearing: 45.0)
v.north  # => 707.107 (meters north)
v.east   # => 707.107 (meters east)
```

A due-north vector has a full north component and zero east component. A due-east vector has zero north and full east.

---

## Factory Methods

### `Vector.from_components(north:, east:)`

Reconstruct a Vector from north/east components in meters.

```ruby
v = Geodetic::Vector.from_components(north: 1000, east: 0)
v.bearing.degrees  # => 0.0 (due north)
v.distance.meters  # => 1000.0
```

Near-zero magnitudes (< 1e-9 meters) snap to a clean zero vector to avoid floating-point artifacts.

### `Vector.from_segment(segment)`

Create a Vector from an existing Segment's length and bearing.

```ruby
seg = Geodetic::Segment.new(seattle, portland)
v = Geodetic::Vector.from_segment(seg)
v.distance.meters  # => same as seg.length_meters
v.bearing.degrees  # => same as seg.bearing.degrees
```

Also available as `segment.to_vector`.

---

## Vincenty Direct

### `destination_from(origin)`

Given an origin coordinate, compute the destination point by traveling the vector's distance along the vector's bearing. Uses the full Vincenty direct formula on the WGS84 ellipsoid.

```ruby
v = Geodetic::Vector.new(distance: 100_000, bearing: 45.0)
dest = v.destination_from(seattle)  # => LLA 100km northeast of Seattle
```

Accepts any coordinate type — non-LLA inputs are converted automatically. A zero-distance vector returns the origin unchanged.

**Round-trip accuracy:**

```ruby
v = Geodetic::Vector.new(distance: 50_000, bearing: 135.0)
dest = v.destination_from(origin)
origin.distance_to(dest).meters  # => 50000.0 (within ~1 meter)
```

---

## Arithmetic

Vector arithmetic uses north/east component decomposition. The result is always a new Vector.

### Vector + Vector

Component-wise addition. Combines two displacements into a single resultant vector.

```ruby
north = Geodetic::Vector.new(distance: 1000, bearing: 0.0)
east  = Geodetic::Vector.new(distance: 1000, bearing: 90.0)
result = north + east
result.bearing.degrees  # => 45.0
result.distance.meters  # => 1414.21
```

### Vector - Vector

Component-wise subtraction.

```ruby
v1 = Geodetic::Vector.new(distance: 1000, bearing: 45.0)
result = v1 - v1
result.zero?  # => true
```

### Vector * Scalar

Scales the distance. Negative scalars reverse the bearing.

```ruby
v = Geodetic::Vector.new(distance: 1000, bearing: 45.0)
(v * 3).distance.meters   # => 3000.0, bearing 45
(v * -1).bearing.degrees  # => 225.0 (reversed)
```

`Scalar * Vector` also works via `coerce`:

```ruby
2 * v  # => Vector with double the distance
```

### Vector / Scalar

Scales the distance down. Raises `ZeroDivisionError` for zero. Negative divisors reverse the bearing.

```ruby
v = Geodetic::Vector.new(distance: 3000, bearing: 90.0)
(v / 3).distance.meters  # => 1000.0
```

### Unary Minus

Same distance, reversed bearing.

```ruby
v = Geodetic::Vector.new(distance: 1000, bearing: 45.0)
(-v).bearing.degrees  # => 225.0
```

### Identity: V + (-V)

Opposite vectors cancel to zero:

```ruby
v = Geodetic::Vector.new(distance: 1000, bearing: 45.0)
result = v + (-v)
result.zero?  # => true
```

---

## Products

### `dot(other)`

Scalar dot product using north/east components. Returns a Float.

```ruby
north = Geodetic::Vector.new(distance: 100, bearing: 0.0)
east  = Geodetic::Vector.new(distance: 100, bearing: 90.0)

north.dot(north)  # => 10000.0 (parallel)
north.dot(east)   # => 0.0 (perpendicular)
```

### `cross(other)`

2D cross product (scalar). Returns a Float. Positive means `other` is to the left of `self`.

```ruby
north.cross(east)  # => 10000.0
east.cross(north)  # => -10000.0
```

### `angle_between(other)`

Returns a Bearing representing the angular difference.

```ruby
north = Geodetic::Vector.new(distance: 100, bearing: 0.0)
east  = Geodetic::Vector.new(distance: 100, bearing: 90.0)
north.angle_between(east).degrees  # => 90.0
```

---

## Properties

| Method      | Returns  | Description |
|-------------|----------|-------------|
| `magnitude` | Float    | Distance in meters |
| `zero?`     | Boolean  | True if distance is zero |
| `normalize` | Vector   | Unit vector (1 meter) in the same bearing |
| `reverse`   | Vector   | Same distance, opposite bearing (alias for `-self`) |
| `inverse`   | Vector   | Alias for `reverse` |

```ruby
v = Geodetic::Vector.new(distance: 5000, bearing: 135.0)
v.magnitude            # => 5000.0
v.normalize.magnitude  # => 1.0
v.reverse.bearing.degrees  # => 315.0
```

---

## Comparison

Vectors include `Comparable`, ordered by distance (magnitude). Two vectors are equal (`==`) only if both distance and bearing match.

```ruby
short = Geodetic::Vector.new(distance: 100, bearing: 0.0)
long  = Geodetic::Vector.new(distance: 200, bearing: 0.0)
short < long  # => true

# Same magnitude, different bearing
a = Geodetic::Vector.new(distance: 100, bearing: 0.0)
b = Geodetic::Vector.new(distance: 100, bearing: 90.0)
(a <=> b) == 0  # => true (same magnitude)
a == b          # => false (different bearing)
```

---

## Display

```ruby
v = Geodetic::Vector.new(distance: 1000, bearing: 90.0)
v.to_s     # => "Vector(1000.00 m, 90.0000°)"
v.inspect  # => "#<Geodetic::Vector distance=#<Geodetic::Distance ...> bearing=#<Geodetic::Bearing ...>>"
```
