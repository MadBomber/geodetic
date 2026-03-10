# Feature Reference

`Geodetic::Feature` wraps a geometry with a human-readable label and an arbitrary metadata hash. It provides a single object that ties spatial data to application-level information like names, categories, and display properties.

---

## Constructor

```ruby
Feature.new(
  label:    "Statue of Liberty",
  geometry: Geodetic::Coordinate::LLA.new(lat: 40.6892, lng: -74.0445, alt: 0),
  metadata: { category: "monument", year: 1886 }
)
```

The `geometry` parameter accepts any coordinate class, any area class (`Circle`, `Polygon`, `BoundingBox`), or a `Path`. The `metadata` hash is optional and defaults to `{}`.

---

## Attributes

| Attribute  | Type   | Mutable | Description |
|------------|--------|---------|-------------|
| `label`    | String | Yes     | A display name for the feature |
| `geometry` | Object | Yes     | A coordinate or area object |
| `metadata` | Hash   | Yes     | Arbitrary key-value pairs |

All three attributes have both reader and writer methods.

---

## Geometry Types

A Feature's geometry can be any of:

- **Coordinate** — any of the 18 coordinate classes (`LLA`, `ECEF`, `UTM`, etc.)
- **Area** — `Areas::Circle`, `Areas::Polygon`, or `Areas::BoundingBox`
- **Path** — a `Geodetic::Path` representing a route or trail

When the geometry is an area, `distance_to` and `bearing_to` use the area's `centroid` as the reference point. When the geometry is a Path, `distance_to` and `bearing_to` use geometric projection to find the closest approach point on the path.

---

## Methods

### `distance_to(other)`

Returns a `Geodetic::Distance` between this feature and another feature, coordinate, or area. When either side is an area geometry, its centroid is used.

The `other` parameter can be a `Feature`, a coordinate, or an area.

```ruby
liberty = Feature.new(label: "Liberty", geometry: LLA.new(lat: 40.6892, lng: -74.0445, alt: 0))
empire  = Feature.new(label: "Empire",  geometry: LLA.new(lat: 40.7484, lng: -73.9857, alt: 0))

liberty.distance_to(empire).to_km   # => "8.24 km"

# Also works with a raw coordinate
liberty.distance_to(LLA.new(lat: 40.7484, lng: -73.9857, alt: 0))
```

### `bearing_to(other)`

Returns a `Geodetic::Bearing` from this feature to another feature, coordinate, or area. Uses the same centroid resolution as `distance_to`.

```ruby
liberty.bearing_to(empire).degrees      # => 36.95
liberty.bearing_to(empire).to_compass   # => "NE"
```

### `to_s`

Returns `"label (geometry.to_s)"`.

```ruby
liberty.to_s  # => "Liberty (40.689200, -74.044500, 0.00)"
```

### `inspect`

Returns a detailed string with label, geometry, and metadata.

```ruby
liberty.inspect
# => "#<Geodetic::Feature name=\"Liberty\" geometry=#<Geodetic::Coordinate::LLA ...> metadata={}>"
```

---

## Area Geometry Example

```ruby
park_boundary = Areas::Polygon.new(boundary: [
  LLA.new(lat: 40.7679, lng: -73.9818, alt: 0),
  LLA.new(lat: 40.7649, lng: -73.9727, alt: 0),
  LLA.new(lat: 40.8003, lng: -73.9494, alt: 0),
  LLA.new(lat: 40.8008, lng: -73.9585, alt: 0),
])

park = Feature.new(label: "Central Park", geometry: park_boundary)

# distance_to uses the polygon's centroid
park.distance_to(liberty)   # => Distance
park.bearing_to(liberty)    # => Bearing
```

---

## Centroid Resolution

When computing distances and bearings, Feature resolves the underlying point as follows:

- If the geometry responds to `centroid` (all area classes do), the centroid is used.
- Otherwise, the geometry itself is used directly (all coordinate classes).

This applies to both the source feature and the target. When the target is a Feature, its geometry is resolved the same way. When the target is a raw coordinate or area, the same logic applies.
