# WKB Serialization Reference

`Geodetic::WKB` provides [Well-Known Binary](https://en.wikipedia.org/wiki/Well-known_binary_representation_of_geometry) (WKB) serialization for all Geodetic geometry types. WKB is the binary counterpart to WKT, used by PostGIS, GEOS, RGeo, Shapely, and most GIS tools for efficient geometry storage and transfer.

Every geometry type gains `to_wkb` and `to_wkb_hex` instance methods. The module also provides `WKB.parse` and `WKB.parse_with_srid` for importing WKB data back into Geodetic objects.

**Byte order:** Output is always little-endian (NDR), matching PostGIS, GEOS, RGeo, Shapely, and virtually all modern GIS tools. Big-endian (XDR) input is fully supported by the parser.

---

## Export

### Coordinates → POINT

All 18 coordinate classes gain `to_wkb` and `to_wkb_hex` methods. They convert the coordinate to LLA and return WKB binary or hex-encoded output.

```ruby
seattle = Geodetic::Coordinate::LLA.new(lat: 47.6205, lng: -122.3493, alt: 0.0)

seattle.to_wkb           # => 21-byte binary string
seattle.to_wkb_hex       # => "01010000008a1f63ee5a965ec08195438b6ccf4740"
```

**Altitude handling:** When altitude is non-zero, the Z type code is used (Point Z = 1001):

```ruby
Geodetic::Coordinate::LLA.new(lat: 47.62, lng: -122.35, alt: 184.0).to_wkb_hex
# => "01e90300008a1f63ee5a965ec08195438b6ccf47400000000000006740"
```

**Cross-system:** Any coordinate type works — UTM, ECEF, MGRS, etc. are converted to LLA internally.

```ruby
seattle.to_utm.to_wkb_hex    # => hex string
seattle.to_ecef.to_wkb_hex   # => hex string
```

**ENU and NED:** These are relative coordinate systems. Calling `to_wkb` raises `ArgumentError`.

---

### Segment → LINESTRING

```ruby
seg = Geodetic::Segment.new(seattle, portland)
seg.to_wkb           # => 41-byte binary string
seg.to_wkb_hex       # => hex string
```

---

### Path → LINESTRING / POLYGON

Returns a LINESTRING by default. Pass `as: :polygon` for a closed POLYGON.

```ruby
route = Geodetic::Path.new(coordinates: [seattle, portland, sf])
route.to_wkb              # => LINESTRING binary
route.to_wkb(as: :polygon) # => POLYGON binary
```

---

### Areas::Polygon → POLYGON

```ruby
poly = Geodetic::Areas::Polygon.new(boundary: [a, b, c])
poly.to_wkb       # => binary
poly.to_wkb_hex   # => hex string
```

All Polygon subclasses (`Triangle`, `Rectangle`, `Pentagon`, `Hexagon`, `Octagon`) inherit this method.

---

### Areas::Circle → POLYGON

Approximated as a regular N-gon. Default is 32 segments.

```ruby
circle = Geodetic::Areas::Circle.new(centroid: seattle, radius: 10_000)

circle.to_wkb                   # => 32-gon binary (541 bytes)
circle.to_wkb(segments: 64)     # => 64-gon
circle.to_wkb(segments: 8)      # => 8-gon (157 bytes)
```

---

### Areas::BoundingBox → POLYGON

5 positions (4 corners + closing point).

```ruby
bbox = Geodetic::Areas::BoundingBox.new(
  nw: Geodetic::Coordinate::LLA.new(lat: 48.0, lng: -123.0, alt: 0),
  se: Geodetic::Coordinate::LLA.new(lat: 46.0, lng: -121.0, alt: 0)
)
bbox.to_wkb       # => 93-byte binary
bbox.to_wkb_hex   # => hex string
```

---

### Feature → delegates to geometry

WKB has no concept of properties or labels. `Feature#to_wkb` delegates directly to the underlying geometry.

```ruby
f = Geodetic::Feature.new(label: "Seattle", geometry: seattle, metadata: { pop: 750_000 })
f.to_wkb_hex   # => same as seattle.to_wkb_hex
```

---

## Options

All `to_wkb` and `to_wkb_hex` methods accept:

| Parameter | Default | Description |
|-----------|---------|-------------|
| `srid:` | `nil` | When set, produces EWKB with embedded SRID |

---

## Z-Dimension Consistency

When any point in a geometry has non-zero altitude, **all** points in that geometry use the Z type code. This follows the OGC rule that Z-dimensionality is uniform within a geometry.

```ruby
# seattle (alt=0) + sf (alt=100) → LineString Z (type code 1002)
mixed = Geodetic::Segment.new(seattle, sf_with_altitude)
mixed.to_wkb  # type code = 1002 (LineString Z)

# Both at alt=0 → LineString (type code 2)
flat = Geodetic::Segment.new(seattle, portland)
flat.to_wkb   # type code = 2 (LineString)
```

---

## SRID / EWKB

Pass `srid:` to any `to_wkb` or `to_wkb_hex` call to produce Extended WKB (EWKB), the format used by PostGIS:

```ruby
seattle.to_wkb_hex(srid: 4326)
# => "0101000020e61000008a1f63ee5a965ec08195438b6ccf4740"

seg.to_wkb_hex(srid: 4326)
# => "0102000020e6100000020000008a1f63ee..."
```

EWKB embeds the SRID in the type code using the `0x20000000` flag, followed by a 4-byte SRID value.

Common SRIDs:

| SRID | Description |
|------|-------------|
| 4326 | WGS84 geographic (lat/lng) |
| 3857 | Web Mercator |
| 32610 | UTM Zone 10N |

---

## File I/O

### Binary Format

#### `WKB.save!(path, *objects, srid: nil)`

Write geometries to a binary file using a framed format: 4-byte LE count, then for each geometry a 4-byte LE size followed by raw WKB bytes. Accepts individual objects or an array.

```ruby
Geodetic::WKB.save!("shapes.wkb", seattle, segment, polygon)
Geodetic::WKB.save!("shapes.wkb", [seattle, segment, polygon])
Geodetic::WKB.save!("shapes.wkb", seattle, polygon, srid: 4326)
```

#### `WKB.load(path)`

Read a binary WKB file and return an Array of Geodetic objects.

```ruby
objects = Geodetic::WKB.load("shapes.wkb")
# => [Coordinate::LLA, Segment, Areas::Polygon]
```

### Hex Format

#### `WKB.save_hex!(path, *objects, srid: nil)`

Write one hex-encoded WKB string per line. Human-readable and diff-friendly.

```ruby
Geodetic::WKB.save_hex!("shapes.wkb.hex", seattle, segment, polygon)
```

Output file:

```
01010000008a1f63ee5a965ec08195438b6ccf4740
0102000000020000008a1f63ee5a965ec0...
01030000000100000004000000...
```

#### `WKB.load_hex(path)`

Read a hex WKB file and return an Array of Geodetic objects. Blank lines and lines starting with `#` are skipped.

```ruby
objects = Geodetic::WKB.load_hex("shapes.wkb.hex")
# => [Coordinate::LLA, Segment, Areas::Polygon]
```

### Roundtrip

```ruby
objects = [seattle, segment, polygon]

# Binary roundtrip
Geodetic::WKB.save!("data.wkb", objects)
loaded = Geodetic::WKB.load("data.wkb")

# Hex roundtrip
Geodetic::WKB.save_hex!("data.wkb.hex", objects, srid: 4326)
loaded = Geodetic::WKB.load_hex("data.wkb.hex")
```

---

## Import

### `WKB.parse(input)`

Parse a WKB binary string or hex string and return a Geodetic object (or Array for Multi*/GeometryCollection types). Auto-detects binary vs hex encoding.

```ruby
Geodetic::WKB.parse("01010000008a1f63ee5a965ec08195438b6ccf4740")
# => Coordinate::LLA

Geodetic::WKB.parse(binary_string)
# => Coordinate::LLA
```

### `WKB.parse_with_srid(input)`

Parse WKB/EWKB and return both the object and the SRID:

```ruby
obj, srid = Geodetic::WKB.parse_with_srid("0101000020e61000008a1f63ee5a965ec08195438b6ccf4740")
obj   # => Coordinate::LLA
srid  # => 4326

obj, srid = Geodetic::WKB.parse_with_srid(plain_wkb_hex)
srid  # => nil
```

---

## WKB → Geodetic Type Mapping

| WKB Type Code | WKB Type | Geodetic Type |
|---------------|----------|---------------|
| 1 | POINT | `Coordinate::LLA` |
| 2 (2 points) | LINESTRING | `Segment` |
| 2 (3+ points) | LINESTRING | `Path` |
| 3 | POLYGON | `Areas::Polygon` (outer ring only; holes are dropped) |
| 4 | MULTIPOINT | Array of `Coordinate::LLA` |
| 5 | MULTILINESTRING | Array of `Segment` or `Path` |
| 6 | MULTIPOLYGON | Array of `Areas::Polygon` |
| 7 | GEOMETRYCOLLECTION | Array of mixed types |

Z variants (type + 1000) are supported: Point Z = 1001, LineString Z = 1002, Polygon Z = 1003.

---

## Geometry Mapping (Export)

| Geodetic Type | WKB Type | Notes |
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

## WKB Binary Structure

Each WKB geometry starts with:

| Offset | Size | Description |
|--------|------|-------------|
| 0 | 1 byte | Byte order: `0x01` = little-endian (NDR), `0x00` = big-endian (XDR) |
| 1 | 4 bytes | Type code (uint32) |
| 5 | 4 bytes | SRID (uint32, only in EWKB when SRID flag is set) |
| 5 or 9 | varies | Geometry data (IEEE 754 doubles) |

**Type codes:**

| Code | Type | Z Code |
|------|------|--------|
| 1 | Point | 1001 |
| 2 | LineString | 1002 |
| 3 | Polygon | 1003 |
| 4 | MultiPoint | 1004 |
| 5 | MultiLineString | 1005 |
| 6 | MultiPolygon | 1006 |
| 7 | GeometryCollection | 1007 |

**EWKB flags** (OR'd into type code):

| Flag | Value | Description |
|------|-------|-------------|
| SRID | `0x20000000` | SRID follows the type code |
| Z | `0x80000000` | Coordinates include Z values |

---

## Roundtrip Example

```ruby
require "geodetic"

seattle = Geodetic::Coordinate::LLA.new(lat: 47.6205, lng: -122.3493, alt: 0)

# Export
hex = seattle.to_wkb_hex(srid: 4326)
# => "0101000020e61000008a1f63ee5a965ec08195438b6ccf4740"

# Import
obj, srid = Geodetic::WKB.parse_with_srid(hex)
obj.lat   # => 47.6205
obj.lng   # => -122.3493
srid      # => 4326

# Re-export
obj.to_wkb_hex(srid: srid) == hex  # => true
```

---

## Integration with PostGIS and RGeo

WKB is the preferred format for exchanging geometry with spatial databases:

```ruby
# Writing to PostGIS (hex format)
hex = polygon.to_wkb_hex(srid: 4326)
ActiveRecord::Base.connection.execute(
  "INSERT INTO regions (geom) VALUES (ST_GeomFromWKB(decode('#{hex}', 'hex'), 4326))"
)

# Or using EWKB directly
ewkb_hex = polygon.to_wkb_hex(srid: 4326)
ActiveRecord::Base.connection.execute(
  "INSERT INTO regions (geom) VALUES ('#{ewkb_hex}')"
)

# Reading from PostGIS
row = ActiveRecord::Base.connection.select_one("SELECT ST_AsEWKB(geom)::text FROM regions LIMIT 1")
obj, srid = Geodetic::WKB.parse_with_srid(row["st_asewkb"])
```

WKB binary is also accepted by RGeo's `WKRep::WKBParser`, Shapely's `wkb.loads()`, JTS, GEOS, and virtually every GIS library.

---

## WKB vs WKT

| | WKB | WKT |
|---|-----|-----|
| **Format** | Binary | Text |
| **Size** | Compact | Larger |
| **Human-readable** | No (use hex) | Yes |
| **Speed** | Faster to parse | Slower |
| **Use case** | Database storage, wire transfer | Debugging, config files, SQL |
| **SRID support** | EWKB flag | EWKT prefix |

Both formats support the same geometry types and Z-dimension handling.
