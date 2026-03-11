# GEOS Acceleration

Geodetic optionally integrates with the [GEOS](https://libgeos.org/) (Geometry Engine - Open Source) C library to accelerate spatial operations. When `libgeos_c` is available, Geodetic transparently delegates performance-critical geometry operations to GEOS while keeping pure Ruby as the fallback.

## Installation

```bash
# macOS
brew install geos

# Linux (Debian/Ubuntu)
sudo apt-get install libgeos-dev

# Linux (Fedora/RHEL)
sudo dnf install geos-devel
```

Verify installation:

```ruby
require "geodetic"
Geodetic::Geos.available?  # => true
```

## How It Works

Geodetic uses Ruby's `fiddle` stdlib (the same approach used for H3) to call the GEOS C API directly — no compiled extensions or external gems required. The integration uses the reentrant `_r` API for thread safety.

The bridge works through WKT serialization:

1. Geodetic objects are converted to WKT via `to_wkt`
2. GEOS parses the WKT into its internal geometry representation
3. GEOS performs the operation using optimized C code with spatial indexing
4. Results are converted back to WKT and parsed into Geodetic objects

This approach keeps the integration simple and maintainable while providing significant performance gains for complex geometries.

## Automatic Dispatch

Geodetic selectively uses GEOS only where it provides a measurable speedup. The dispatch logic is built into the existing classes:

### Polygon Validation

`Polygon.new(boundary: [...])` automatically validates the boundary for self-intersection. GEOS uses an O(n log n) spatial index compared to Ruby's O(n^2) pairwise segment test.

- GEOS is used at **all polygon sizes** when available
- Speedup grows with vertex count: ~2x at 50 vertices, ~5x at 100, ~50x+ at 500

### Point-in-Polygon

`polygon.includes?(point)` tests whether a point lies inside a polygon.

- GEOS is used for polygons with **15 or more vertices** (`Polygon::GEOS_INCLUDES_THRESHOLD`)
- Below 15 vertices, Ruby's winding-number algorithm is faster (FFI overhead dominates)
- Above the threshold, GEOS provides 2-10x speedup depending on polygon complexity

### Path Intersection

`path.intersects?(other_path)` tests whether two paths cross.

- GEOS is **always used** when available (wins at all tested sizes)
- Ruby uses O(n*m) brute-force segment pair testing
- GEOS uses spatial indexing for efficient intersection detection
- Speedup is most dramatic for non-intersecting paths with overlapping bounds (worst case for Ruby): 10x at 100 points, 100x+ at 1000 points

### Where Ruby Wins

Single segment intersection (`segment.intersects?(other_segment)`) stays in pure Ruby at all times. The FFI marshaling overhead for a single pair of line segments exceeds the computation cost. Geodetic does not use GEOS for this operation.

## PreparedGeometry

For batch operations (testing many points against the same polygon), `PreparedGeometry` builds a spatial index once and reuses it for O(log n) queries:

```ruby
polygon = Geodetic::Areas::Polygon.new(boundary: vertices)
prepared = Geodetic::Geos.prepare(polygon)

points.each do |pt|
  prepared.contains?(pt)  # O(log n) per query
end

prepared.release  # free the GEOS geometry
```

This is significantly faster than calling `polygon.includes?` in a loop, which creates a new GEOS geometry for each call.

## GEOS-Only Operations

GEOS provides operations that have no pure Ruby equivalent in Geodetic:

```ruby
Geos = Geodetic::Geos

# Boolean operations — return Geodetic objects
Geos.intersection(poly_a, poly_b)        # area of overlap
Geos.difference(poly_a, poly_b)          # A minus B
Geos.symmetric_difference(poly_a, poly_b) # area in either but not both

# Geometry analysis
Geos.convex_hull(polygon)                # smallest convex polygon
Geos.simplify(polygon, tolerance)        # Douglas-Peucker simplification
Geos.make_valid(polygon)                 # repair invalid geometry
Geos.is_valid?(polygon)                  # OGC validity check
Geos.is_valid_reason(polygon)            # human-readable validity reason

# Measurements
Geos.area(polygon)                       # area in coordinate units
Geos.length(path)                        # length in coordinate units
Geos.distance(geom_a, geom_b)           # minimum distance

# Spatial relationships
Geos.nearest_points(geom_a, geom_b)     # closest point pair
Geos.contains?(polygon, point)          # containment test
Geos.intersects?(geom_a, geom_b)        # intersection test

# Buffering
Geos.buffer(geometry, width)            # buffer zone
Geos.buffer_with_style(geometry, width, quad_segs:, cap_style:, join_style:)
```

## Disabling GEOS

Set the `GEODETIC_GEOS_DISABLE` environment variable to force pure Ruby for all operations:

```bash
GEODETIC_GEOS_DISABLE=1 ruby -Ilib my_script.rb
```

```ruby
ENV['GEODETIC_GEOS_DISABLE'] = '1'
Geodetic::Geos.available?  # => false (even when libgeos_c is installed)
```

This is useful for:

- Benchmarking Ruby vs GEOS performance (see example 12)
- Debugging to isolate whether an issue is in GEOS or Ruby code
- Running in environments where GEOS cannot be installed

## Performance Expectations

The following table shows representative speedups measured with [example 12](../../examples/12_geos_benchmark.rb). Actual results vary by hardware and polygon complexity.

| Operation | Size | Typical Speedup |
|-----------|------|-----------------|
| Polygon validation | 50 vertices | ~2x |
| Polygon validation | 100 vertices | ~5x |
| Polygon validation | 500 vertices | ~50x |
| Point-in-polygon | 30 vertices | ~2x |
| Point-in-polygon | 100 vertices | ~5x |
| Point-in-polygon | 500 vertices | ~10x |
| Path intersection | 100 points | ~10x |
| Path intersection | 500 points | ~50x |
| Path intersection | 1000 points | ~100x |
| Batch containment (prepared) | 1000 points × 100v | ~20x |
| Single segment | 2 points | Ruby is ~2x faster |

Run the benchmark yourself:

```bash
ruby -Ilib examples/12_geos_benchmark.rb
```

For a visual demonstration of GEOS operations rendered on a map:

```bash
ruby -Ilib examples/14_geos_map_rendering.rb
```

## Architecture Notes

- **Thread safety**: Uses the reentrant GEOS `_r` API with per-process context initialization
- **No compiled extensions**: Uses `fiddle` from Ruby's stdlib, same pattern as the H3 integration
- **Graceful degradation**: All operations work without GEOS; it is purely an optimization
- **WKT bridge**: Geometries are serialized to WKT for transfer between Ruby and GEOS, leveraging Geodetic's existing WKT infrastructure
- **Memory management**: GEOS geometries and readers/writers are properly freed via `GEOSGeom_destroy_r`, `GEOSWKTReader_destroy_r`, etc.
