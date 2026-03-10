# WKT Serialization Reference

`Geodetic::WKT` provides [Well-Known Text](https://en.wikipedia.org/wiki/Well-known_text_representation_of_geometry) (WKT) serialization for all Geodetic geometry types. WKT is the standard text format used by PostGIS, RGeo, Shapely, JTS, GEOS, and most GIS tools.

Every geometry type gains a `to_wkt` instance method. The module also provides `WKT.parse` and `WKT.parse_with_srid` for importing WKT strings back into Geodetic objects.

---

## Export

### Coordinates → POINT

All 18 coordinate classes gain a `to_wkt` method. It converts the coordinate to LLA and returns a WKT POINT string.

```ruby
seattle = Geodetic::Coordinate::LLA.new(lat: 47.6205, lng: -122.3493, alt: 0.0)
seattle.to_wkt
# => "POINT(-122.3493 47.6205)"
```

**Altitude handling:** When altitude is non-zero, the Z suffix is added:

```ruby
Geodetic::Coordinate::LLA.new(lat: 47.62, lng: -122.35, alt: 184.0).to_wkt
# => "POINT Z(-122.35 47.62 184.0)"
```

**Cross-system:** Any coordinate type works — UTM, ECEF, MGRS, etc. are converted to LLA internally.

```ruby
seattle.to_utm.to_wkt    # => "POINT(-122.3493 47.6205)"
seattle.to_ecef.to_wkt   # => "POINT(-122.3493 47.6205)"
```

**ENU and NED:** These are relative coordinate systems. Calling `to_wkt` raises `ArgumentError`.

```ruby
enu = Geodetic::Coordinate::ENU.new(e: 100, n: 200, u: 10)
enu.to_wkt  # => ArgumentError
```

### Options

All `to_wkt` methods accept these keyword arguments:

| Parameter | Default | Description |
|-----------|---------|-------------|
| `precision:` | `6` | Number of decimal places for coordinates |
| `srid:` | `nil` | When set, prepends `SRID=N;` (EWKT format) |

```ruby
seattle.to_wkt(precision: 2)
# => "POINT(-122.35 47.62)"

seattle.to_wkt(srid: 4326)
# => "SRID=4326;POINT(-122.3493 47.6205)"
```

---

### Segment → LINESTRING

```ruby
seg = Geodetic::Segment.new(seattle, portland)
seg.to_wkt
# => "LINESTRING(-122.3493 47.6205, -122.6784 45.5152)"
```

---

### Path → LINESTRING / POLYGON

Returns a LINESTRING by default. Pass `as: :polygon` for a closed POLYGON.

```ruby
route = Geodetic::Path.new(coordinates: [seattle, portland, sf])
route.to_wkt
# => "LINESTRING(-122.3493 47.6205, -122.6784 45.5152, -122.4194 37.7749)"

route.to_wkt(as: :polygon)
# => "POLYGON((-122.3493 47.6205, -122.6784 45.5152, -122.4194 37.7749, -122.3493 47.6205))"
```

**Edge cases:**

| Condition | Behavior |
|-----------|----------|
| Empty path | Raises `ArgumentError` |
| 1 coordinate (line_string) | Raises `ArgumentError` |
| 2 coordinates (polygon) | Raises `ArgumentError` |

---

### Areas::Polygon → POLYGON

```ruby
poly = Geodetic::Areas::Polygon.new(boundary: [a, b, c])
poly.to_wkt
# => "POLYGON((-122.5 47.7, -122.1 47.5, -122.4 47.3, -122.5 47.7))"
```

All Polygon subclasses (`Triangle`, `Rectangle`, `Pentagon`, `Hexagon`, `Octagon`) inherit this method.

---

### Areas::Circle → POLYGON

Approximated as a regular N-gon. Default is 32 segments.

```ruby
circle = Geodetic::Areas::Circle.new(centroid: seattle, radius: 10_000)

circle.to_wkt                 # => 32-gon
circle.to_wkt(segments: 64)   # => 64-gon
circle.to_wkt(segments: 8)    # => 8-gon
```

---

### Areas::BoundingBox → POLYGON

5 positions (4 corners + closing point).

```ruby
bbox = Geodetic::Areas::BoundingBox.new(
  nw: Geodetic::Coordinate::LLA.new(lat: 48.0, lng: -123.0, alt: 0),
  se: Geodetic::Coordinate::LLA.new(lat: 46.0, lng: -121.0, alt: 0)
)
bbox.to_wkt
# => "POLYGON((-123.0 48.0, -121.0 48.0, -121.0 46.0, -123.0 46.0, -123.0 48.0))"
```

---

### Feature → delegates to geometry

WKT has no concept of properties or labels. `Feature#to_wkt` delegates directly to the underlying geometry.

```ruby
f = Geodetic::Feature.new(label: "Seattle", geometry: seattle, metadata: { pop: 750_000 })
f.to_wkt
# => "POINT(-122.3493 47.6205)"
```

---

## Z-Dimension Consistency

When any point in a geometry has non-zero altitude, **all** points in that geometry use the Z suffix. This follows the OGC rule that Z-dimensionality is uniform within a geometry.

```ruby
# seattle has alt=0, sf has alt=100
path = Geodetic::Path.new(coordinates: [seattle, sf])
path.to_wkt
# => "LINESTRING Z(-122.3493 47.6205 0.0, -122.4194 37.7749 100.0)"

# Both at alt=0 → no Z
path2 = Geodetic::Path.new(coordinates: [seattle, portland])
path2.to_wkt
# => "LINESTRING(-122.3493 47.6205, -122.6784 45.5152)"
```

---

## SRID / EWKT

Pass `srid:` to any `to_wkt` call to produce Extended WKT (EWKT), the format used by PostGIS:

```ruby
seattle.to_wkt(srid: 4326)
# => "SRID=4326;POINT(-122.3493 47.6205)"

seg.to_wkt(srid: 4326)
# => "SRID=4326;LINESTRING(-122.3493 47.6205, -122.6784 45.5152)"

poly.to_wkt(srid: 4326)
# => "SRID=4326;POLYGON((...))
```

Common SRIDs:

| SRID | Description |
|------|-------------|
| 4326 | WGS84 geographic (lat/lng) |
| 3857 | Web Mercator |
| 32610 | UTM Zone 10N |

---

## File I/O

### `WKT.save!(path, *objects, srid: nil, precision: 6)`

Write one WKT string per line. Accepts individual objects or an array.

```ruby
Geodetic::WKT.save!("shapes.wkt", seattle, segment, polygon)
Geodetic::WKT.save!("shapes.wkt", [seattle, segment, polygon])
Geodetic::WKT.save!("shapes.wkt", seattle, polygon, srid: 4326, precision: 2)
```

Output file (one geometry per line):

```
POINT(-122.3493 47.6205)
LINESTRING(-122.3493 47.6205, -122.6784 45.5152)
POLYGON((-122.0 47.0, -121.0 46.0, -123.0 46.0, -122.0 47.0))
```

### `WKT.load(path)`

Read a WKT file and return an Array of Geodetic objects. Blank lines are skipped.

```ruby
objects = Geodetic::WKT.load("shapes.wkt")
# => [Coordinate::LLA, Segment, Areas::Polygon]
```

**Roundtrip:**

```ruby
Geodetic::WKT.save!("data.wkt", seattle, portland, polygon, srid: 4326)
objects = Geodetic::WKT.load("data.wkt")
```

---

## Import

### `WKT.parse(string)`

Parse a WKT string and return a Geodetic object (or Array for Multi*/GeometryCollection types).

```ruby
Geodetic::WKT.parse("POINT(-122.3493 47.6205)")
# => Coordinate::LLA

Geodetic::WKT.parse("LINESTRING(-122.35 47.62, -122.68 45.52)")
# => Segment (2 points) or Path (3+ points)

Geodetic::WKT.parse("POLYGON((-122.0 47.0, -121.0 46.0, -123.0 46.0, -122.0 47.0))")
# => Areas::Polygon

Geodetic::WKT.parse("MULTIPOINT((-122.35 47.62), (-122.68 45.52))")
# => [LLA, LLA]

Geodetic::WKT.parse("GEOMETRYCOLLECTION(POINT(-122.35 47.62), LINESTRING(...))")
# => [LLA, Segment]
```

SRID prefixes are silently stripped:

```ruby
Geodetic::WKT.parse("SRID=4326;POINT(-122.35 47.62)")
# => Coordinate::LLA (SRID discarded)
```

### `WKT.parse_with_srid(string)`

Parse a WKT/EWKT string and return both the object and the SRID:

```ruby
obj, srid = Geodetic::WKT.parse_with_srid("SRID=4326;POINT(-122.3493 47.6205)")
obj   # => Coordinate::LLA
srid  # => 4326

obj, srid = Geodetic::WKT.parse_with_srid("POINT(-122.3493 47.6205)")
srid  # => nil
```

---

## WKT → Geodetic Type Mapping

| WKT Type | Geodetic Type |
|----------|---------------|
| POINT | `Coordinate::LLA` |
| LINESTRING (2 points) | `Segment` |
| LINESTRING (3+ points) | `Path` |
| POLYGON | `Areas::Polygon` (outer ring only; holes are dropped) |
| MULTIPOINT | Array of `Coordinate::LLA` |
| MULTILINESTRING | Array of `Segment` or `Path` |
| MULTIPOLYGON | Array of `Areas::Polygon` |
| GEOMETRYCOLLECTION | Array of mixed types |

All types support the Z suffix for 3D coordinates.

---

## Geometry Mapping (Export)

| Geodetic Type | WKT Type | Notes |
|---------------|----------|-------|
| Any coordinate (LLA, UTM, ECEF, ...) | POINT | Converts through LLA |
| `Segment` | LINESTRING | 2 positions |
| `Path` | LINESTRING | N positions (default) |
| `Path` (with `as: :polygon`) | POLYGON | Auto-closes the ring |
| `Areas::Polygon` (and subclasses) | POLYGON | Boundary ring already closed |
| `Areas::Circle` | POLYGON | Approximated as N-gon (default 32) |
| `Areas::BoundingBox` | POLYGON | 4 corners, closed |
| `Feature` | Delegates to geometry | Properties are lost |

---

## Roundtrip Example

```ruby
require "geodetic"

seattle = Geodetic::Coordinate::LLA.new(lat: 47.6205, lng: -122.3493, alt: 0)

# Export
wkt = seattle.to_wkt(srid: 4326)
# => "SRID=4326;POINT(-122.3493 47.6205)"

# Import
obj, srid = Geodetic::WKT.parse_with_srid(wkt)
obj.lat   # => 47.6205
obj.lng   # => -122.3493
srid      # => 4326

# Re-export
obj.to_wkt(srid: srid) == wkt  # => true
```

---

## WKT Specification Notes

- **Coordinate order** is `longitude latitude` (same as GeoJSON), per OGC Simple Features.
- **Z suffix** indicates 3D coordinates: `POINT Z(lng lat alt)`.
- **Polygon rings** are closed (first point = last point).
- **EWKT** (Extended WKT) prepends `SRID=N;` — this is a PostGIS extension, not part of the OGC standard.
- **No properties** — unlike GeoJSON, WKT is geometry-only. Feature labels and metadata are not preserved.

---

## Integration with PostGIS and RGeo

WKT is the lingua franca for exchanging geometry between Ruby and spatial databases:

```ruby
# Writing to PostGIS
wkt = polygon.to_wkt(srid: 4326)
ActiveRecord::Base.connection.execute(
  "INSERT INTO regions (geom) VALUES (ST_GeomFromEWKT('#{wkt}'))"
)

# Reading from PostGIS
row = ActiveRecord::Base.connection.select_one("SELECT ST_AsEWKT(geom) FROM regions LIMIT 1")
obj, srid = Geodetic::WKT.parse_with_srid(row["st_asewkt"])
```

WKT strings are also accepted by RGeo's `WKRep::WKTParser`, Shapely's `loads()`, JTS, GEOS, and virtually every GIS library.
