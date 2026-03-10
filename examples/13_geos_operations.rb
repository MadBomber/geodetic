#!/usr/bin/env ruby

# Demonstration of GEOS-Only Operations
# Shows geometry operations provided by the GEOS C library that have no
# pure Ruby equivalent in Geodetic: boolean operations, buffering,
# convex hull, simplification, validation repair, measurements, and
# PreparedGeometry batch queries.
#
# Requires: brew install geos
# Run:      ruby -Ilib examples/13_geos_operations.rb

require_relative "../lib/geodetic"

include Geodetic

LLA     = Coordinate::LLA
Polygon = Areas::Polygon
Geos    = Geodetic::Geos

unless Geos.available?
  if ENV.key?('GEODETIC_GEOS_DISABLE')
    abort "GEODETIC_GEOS_DISABLE is set. Unset it to run this demo:\n  unset GEODETIC_GEOS_DISABLE"
  else
    abort "libgeos_c not found. Install with: brew install geos"
  end
end

def section(title)
  puts
  puts "=" * 70
  puts title
  puts "=" * 70
end

def subsection(title)
  puts
  puts "  --- #{title} ---"
end

def fmt_polygon(poly)
  if poly.is_a?(Array)
    poly.map { |p| fmt_polygon(p) }.join("\n    ")
  elsif poly.is_a?(Polygon)
    n = poly.boundary.length - 1
    centroid = poly.centroid
    "Polygon(#{n} vertices, centroid: #{centroid.lat.round(4)}, #{centroid.lng.round(4)})"
  else
    poly.to_s
  end
end

# ---------------------------------------------------------------------------
# Build two overlapping polygons around NYC
# ---------------------------------------------------------------------------

# Lower Manhattan polygon (roughly)
lower = Polygon.new(boundary: [
  LLA.new(lat: 40.700, lng: -74.020, alt: 0),
  LLA.new(lat: 40.700, lng: -73.970, alt: 0),
  LLA.new(lat: 40.730, lng: -73.970, alt: 0),
  LLA.new(lat: 40.730, lng: -74.020, alt: 0),
])

# Midtown Manhattan polygon (overlaps northern edge of lower)
midtown = Polygon.new(boundary: [
  LLA.new(lat: 40.720, lng: -74.010, alt: 0),
  LLA.new(lat: 40.720, lng: -73.960, alt: 0),
  LLA.new(lat: 40.760, lng: -73.960, alt: 0),
  LLA.new(lat: 40.760, lng: -74.010, alt: 0),
])

puts <<~HEREDOC
  === GEOS-Only Operations Demo ===

    These operations require the GEOS C library and have no pure Ruby
    equivalent in Geodetic. They enable computational geometry workflows
    like boolean overlay, buffering, simplification, and spatial indexing.

    Two overlapping rectangles around Manhattan:
      Lower:   40.700-40.730 lat, -74.020 to -73.970 lng
      Midtown: 40.720-40.760 lat, -74.010 to -73.960 lng
      Overlap: 40.720-40.730 lat, -74.010 to -73.970 lng
HEREDOC

# ── 1. Boolean Operations ────────────────────────────────────────────

section "1. BOOLEAN OPERATIONS"

subsection "Intersection (area of overlap)"
overlap = Geos.intersection(lower, midtown)
puts "    Geos.intersection(lower, midtown)"
puts "    => #{fmt_polygon(overlap)}"
if overlap.is_a?(Polygon)
  puts "    Boundary:"
  overlap.boundary[0...-1].each do |pt|
    puts "      (#{pt.lat.round(4)}, #{pt.lng.round(4)})"
  end
end

subsection "Difference (lower minus midtown)"
diff = Geos.difference(lower, midtown)
puts "    Geos.difference(lower, midtown)"
puts "    => #{fmt_polygon(diff)}"
puts "    The part of Lower Manhattan not covered by Midtown."

subsection "Difference (midtown minus lower)"
diff2 = Geos.difference(midtown, lower)
puts "    Geos.difference(midtown, lower)"
puts "    => #{fmt_polygon(diff2)}"
puts "    The part of Midtown not covered by Lower Manhattan."

subsection "Symmetric Difference (in one but not both)"
sym = Geos.symmetric_difference(lower, midtown)
puts "    Geos.symmetric_difference(lower, midtown)"
puts "    => #{fmt_polygon(sym)}"
puts "    Everything except the overlap — the XOR of the two polygons."

subsection "Union (merge into one polygon)"
merged = Geos.union(lower)
puts "    Geos.union(lower)"
puts "    => #{fmt_polygon(merged)}"
puts "    Dissolves internal boundaries (useful for merging multi-polygons)."

# ── 2. Buffering ─────────────────────────────────────────────────────

section "2. BUFFERING"

puts <<~HEREDOC

    Buffer creates a polygon at a fixed distance around any geometry.
    Distance is in coordinate units (degrees for LLA).
    ~0.001 degrees ≈ 111 meters at the equator.
HEREDOC

# Buffer a point to create a circle-like polygon
point = LLA.new(lat: 40.7484, lng: -73.9857, alt: 0)
buffered = Geos.buffer(point, 0.005, quad_segs: 16)

puts "  Point buffer (Empire State Building, radius ~555m):"
puts "    Geos.buffer(point, 0.005, quad_segs: 16)"
if buffered.is_a?(Polygon)
  puts "    => #{fmt_polygon(buffered)}"
end

# Buffer a path to create a corridor
path = Path.new(coordinates: [
  LLA.new(lat: 40.7484, lng: -73.9857, alt: 0),
  LLA.new(lat: 40.7580, lng: -73.9855, alt: 0),
  LLA.new(lat: 40.7614, lng: -73.9776, alt: 0),
])
corridor = Geos.buffer(path, 0.002)

puts
puts "  Path buffer (corridor along a 3-point route, width ~222m):"
puts "    Geos.buffer(path, 0.002)"
if corridor.is_a?(Polygon)
  puts "    => #{fmt_polygon(corridor)}"
end

subsection "Buffer with style options"
flat_buf = Geos.buffer_with_style(path, 0.002,
  quad_segs: 8, end_cap_style: 2, join_style: 2)

puts "    Geos.buffer_with_style(path, 0.002,"
puts "      end_cap_style: 2,  # flat caps"
puts "      join_style: 2)     # mitre joins"
if flat_buf.is_a?(Polygon)
  puts "    => #{fmt_polygon(flat_buf)}"
end

# ── 3. Convex Hull ───────────────────────────────────────────────────

section "3. CONVEX HULL"

puts <<~HEREDOC

    Convex hull is the smallest convex polygon enclosing a geometry.
    Think of stretching a rubber band around all the points.
HEREDOC

# Scatter some NYC landmarks
landmarks = [
  LLA.new(lat: 40.6892, lng: -74.0445, alt: 0),  # Statue of Liberty
  LLA.new(lat: 40.7484, lng: -73.9857, alt: 0),  # Empire State
  LLA.new(lat: 40.7580, lng: -73.9855, alt: 0),  # Rockefeller Center
  LLA.new(lat: 40.7614, lng: -73.9776, alt: 0),  # Central Park South
  LLA.new(lat: 40.7128, lng: -74.0060, alt: 0),  # One World Trade
  LLA.new(lat: 40.6413, lng: -73.7781, alt: 0),  # JFK Airport
]
landmark_names = [
  "Statue of Liberty", "Empire State", "Rockefeller Center",
  "Central Park South", "One World Trade", "JFK Airport",
]

# Build a path from the landmarks so GEOS sees all the points
landmark_path = Path.new(coordinates: landmarks)
hull = Geos.convex_hull(landmark_path)

puts "  Input: 6 NYC landmarks"
landmarks.each_with_index do |pt, i|
  puts "    #{landmark_names[i]}: (#{pt.lat.round(4)}, #{pt.lng.round(4)})"
end
puts
puts "  Geos.convex_hull(landmark_path)"
if hull.is_a?(Polygon)
  puts "  => #{fmt_polygon(hull)}"
  puts "  Hull vertices:"
  hull.boundary[0...-1].each do |pt|
    puts "    (#{pt.lat.round(4)}, #{pt.lng.round(4)})"
  end
end

# ── 4. Simplification ────────────────────────────────────────────────

section "4. SIMPLIFICATION (Douglas-Peucker)"

puts <<~HEREDOC

    Simplify reduces vertices while preserving shape within a tolerance.
    Uses the Douglas-Peucker algorithm. Tolerance is in coordinate units.
HEREDOC

# Create a detailed polygon (50-vertex circle approximation)
step = 360.0 / 50
detailed = Polygon.new(boundary: 50.times.map { |i|
  angle = i * step * Geodetic::RAD_PER_DEG
  LLA.new(
    lat: 40.75 + 0.02 * Math.sin(angle),
    lng: -73.99 + 0.02 * Math.cos(angle),
    alt: 0.0
  )
})

puts "  Original polygon: #{detailed.boundary.length - 1} vertices"

[0.001, 0.005, 0.01].each do |tol|
  simplified = Geos.simplify(detailed, tol)
  if simplified.is_a?(Polygon)
    n = simplified.boundary.length - 1
    puts "  Geos.simplify(polygon, #{tol})  => #{n} vertices"
  end
end

# ── 5. Validity Checking ─────────────────────────────────────────────

section "5. VALIDITY CHECKING"

puts <<~HEREDOC

    GEOS checks geometry against OGC validity rules and can explain
    exactly why a geometry is invalid.
HEREDOC

puts "  Valid polygon:"
puts "    Geos.is_valid?(lower)  => #{Geos.is_valid?(lower)}"
puts "    Geos.is_valid_reason(lower)  => \"#{Geos.is_valid_reason(lower)}\""

# Feed a bowtie (self-intersecting) polygon directly to GEOS via its
# WKT string, bypassing Geodetic's Polygon constructor which would reject it.
puts
puts "  Self-intersecting polygon (bowtie):"
puts "    Vertices cross at the center, forming a figure-8."
bowtie_wkt = "POLYGON((0 0, 2 2, 2 0, 0 2, 0 0))"
bowtie_geom = Geodetic::Geos::LibGEOS.wkt_to_geom(bowtie_wkt)
begin
  valid = Geodetic::Geos::LibGEOS::F_IS_VALID.call(
    Geodetic::Geos::LibGEOS.context, bowtie_geom) == 1
  reason_ptr = Geodetic::Geos::LibGEOS::F_IS_VALID_REASON.call(
    Geodetic::Geos::LibGEOS.context, bowtie_geom)
  reason = reason_ptr.to_s
  Geodetic::Geos::LibGEOS::F_GEOS_FREE.call(Geodetic::Geos::LibGEOS.context, reason_ptr)
  puts "    Geos.is_valid?(bowtie)  => #{valid}"
  puts "    Geos.is_valid_reason(bowtie)  => \"#{reason}\""
ensure
  # keep bowtie_geom alive for make_valid below
end

# ── 6. Make Valid (Geometry Repair) ───────────────────────────────────

section "6. MAKE VALID (Geometry Repair)"

puts <<~HEREDOC

    make_valid repairs invalid geometries — fixing self-intersections,
    ring ordering, and other OGC violations. The result is always valid.
HEREDOC

puts "  Repairing the bowtie polygon:"
repaired_geom = Geodetic::Geos::LibGEOS::F_MAKE_VALID.call(
  Geodetic::Geos::LibGEOS.context, bowtie_geom)
repaired_wkt = Geodetic::Geos::LibGEOS.geom_to_wkt(repaired_geom, precision: 6)
repaired_valid = Geodetic::Geos::LibGEOS::F_IS_VALID.call(
  Geodetic::Geos::LibGEOS.context, repaired_geom) == 1
puts "    Geos.make_valid(bowtie)"
puts "    => #{repaired_wkt}"
puts "    Geos.is_valid?(repaired) => #{repaired_valid}"
puts "    GEOS splits the self-intersecting bowtie into valid geometry."
Geodetic::Geos::LibGEOS.destroy_geom(repaired_geom)
Geodetic::Geos::LibGEOS.destroy_geom(bowtie_geom)

# ── 7. Planar Measurements ───────────────────────────────────────────

section "7. PLANAR MEASUREMENTS"

puts <<~HEREDOC

    GEOS computes area, length, and minimum distance in coordinate units.
    For LLA geometries, units are square degrees (area) and degrees
    (length/distance). These are planar approximations — use Geodetic's
    Vincenty-based distance_to for geodesic accuracy.
HEREDOC

puts "  Area:"
puts "    Geos.area(lower)    => #{Geos.area(lower).round(8)} sq degrees"
puts "    Geos.area(midtown)  => #{Geos.area(midtown).round(8)} sq degrees"
if overlap.is_a?(Polygon)
  puts "    Geos.area(overlap)  => #{Geos.area(overlap).round(8)} sq degrees"
end

puts
puts "  Perimeter (length of boundary):"
puts "    Geos.length(lower)   => #{Geos.length(lower).round(6)} degrees"
puts "    Geos.length(midtown) => #{Geos.length(midtown).round(6)} degrees"

puts
puts "  Minimum distance between non-overlapping geometries:"

brooklyn = Polygon.new(boundary: [
  LLA.new(lat: 40.630, lng: -73.990, alt: 0),
  LLA.new(lat: 40.630, lng: -73.940, alt: 0),
  LLA.new(lat: 40.660, lng: -73.940, alt: 0),
  LLA.new(lat: 40.660, lng: -73.990, alt: 0),
])
dist = Geos.distance(lower, brooklyn)
puts "    Geos.distance(lower_manhattan, brooklyn) => #{dist.round(6)} degrees"
puts "    (Approx #{(dist * 111_000).round(0)} meters at this latitude)"

# ── 8. Nearest Points ────────────────────────────────────────────────

section "8. NEAREST POINTS"

puts <<~HEREDOC

    nearest_points finds the closest pair of points between two
    geometries — one point on each. Returns [LLA, LLA].
HEREDOC

pts = Geos.nearest_points(lower, brooklyn)
puts "  Geos.nearest_points(lower_manhattan, brooklyn)"
puts "    Point on Lower Manhattan: (#{pts[0].lat.round(6)}, #{pts[0].lng.round(6)})"
puts "    Point on Brooklyn:        (#{pts[1].lat.round(6)}, #{pts[1].lng.round(6)})"

geodesic_dist = pts[0].distance_to(pts[1])
puts "    Geodesic distance between them: #{geodesic_dist.to_s(0)}"

# ── 9. PreparedGeometry (Batch Spatial Index) ─────────────────────────

section "9. PREPARED GEOMETRY (Batch Spatial Index)"

puts <<~HEREDOC

    PreparedGeometry builds a spatial index once, then subsequent
    contains?/intersects? queries run in O(log n). Essential for
    testing many points against the same polygon.
HEREDOC

# Build a 100-vertex polygon
step = 360.0 / 100
big_poly = Polygon.new(boundary: 100.times.map { |i|
  angle = i * step * Geodetic::RAD_PER_DEG
  LLA.new(
    lat: 40.75 + 0.05 * Math.sin(angle),
    lng: -73.99 + 0.05 * Math.cos(angle),
    alt: 0.0
  )
})

# Generate test points
srand(42)
test_points = 20.times.map do
  LLA.new(lat: 40.69 + rand * 0.12, lng: -74.05 + rand * 0.12, alt: 0.0)
end

prepared = Geos.prepare(big_poly)

inside  = 0
outside = 0
test_points.each do |pt|
  if prepared.contains?(pt)
    inside += 1
  else
    outside += 1
  end
end

puts "  Polygon: 100 vertices, radius ~0.05 degrees"
puts "  Test points: #{test_points.length}"
puts "    Inside:  #{inside}"
puts "    Outside: #{outside}"
puts
puts "  PreparedGeometry also supports intersects?:"
seg = Segment.new(
  LLA.new(lat: 40.70, lng: -74.00, alt: 0),
  LLA.new(lat: 40.80, lng: -73.98, alt: 0)
)
puts "    prepared.intersects?(segment) => #{prepared.intersects?(seg)}"

prepared.release
puts "    prepared.release  # free GEOS memory"

# ── 10. Chaining Operations ──────────────────────────────────────────

section "10. CHAINING OPERATIONS"

puts <<~HEREDOC

    GEOS operations return Geodetic objects, so results chain naturally
    with other GEOS calls or with Geodetic's Ruby methods.
HEREDOC

puts "  Workflow: intersect two polygons, buffer the result, compute hull"
puts

# Step 1: Intersection
result = Geos.intersection(lower, midtown)
puts "  1. overlap = Geos.intersection(lower, midtown)"
puts "     => #{fmt_polygon(result)}"

# Step 2: Buffer the intersection
if result.is_a?(Polygon)
  buffered_overlap = Geos.buffer(result, 0.005)
  puts "  2. expanded = Geos.buffer(overlap, 0.005)"
  puts "     => #{fmt_polygon(buffered_overlap)}"

  # Step 3: Convex hull of the buffered result
  hull2 = Geos.convex_hull(buffered_overlap)
  puts "  3. hull = Geos.convex_hull(expanded)"
  puts "     => #{fmt_polygon(hull2)}"

  # Step 4: Compute area
  area = Geos.area(hull2)
  puts "  4. Geos.area(hull) => #{area.round(8)} sq degrees"

  # Step 5: Validate
  puts "  5. Geos.is_valid?(hull) => #{Geos.is_valid?(hull2)}"

  # Step 6: Use Geodetic methods on the result
  if hull2.is_a?(Polygon)
    puts "  6. hull.centroid => (#{hull2.centroid.lat.round(4)}, #{hull2.centroid.lng.round(4)})"
    puts "     hull.includes?(Empire State) => #{hull2.includes?(point)}"
  end
end

# ── 11. GeoJSON Export ────────────────────────────────────────────────

section "11. GEOJSON EXPORT OF GEOS RESULTS"

puts <<~HEREDOC

    GEOS results are standard Geodetic objects, so they work with
    GeoJSON export, WKT, WKB, and all other serialization.
HEREDOC

gj = GeoJSON.new
gj << Feature.new(label: "Lower Manhattan", geometry: lower,
                   metadata: { role: "input" })
gj << Feature.new(label: "Midtown", geometry: midtown,
                   metadata: { role: "input" })
if result.is_a?(Polygon)
  gj << Feature.new(label: "Overlap", geometry: result,
                     metadata: { role: "intersection" })
end
hull_result = Geos.convex_hull(landmark_path)
if hull_result.is_a?(Polygon)
  gj << Feature.new(label: "Landmark Hull", geometry: hull_result,
                     metadata: { role: "convex_hull" })
end

puts "  GeoJSON FeatureCollection with #{gj.size} features:"
gj.each do |obj|
  if obj.is_a?(Feature)
    puts "    - #{obj.label} (#{obj.metadata[:role]})"
  end
end
puts
puts "  gj.to_json  => #{gj.to_json.length} characters"

puts
puts "  WKT of the intersection:"
if result.is_a?(Polygon)
  wkt = result.to_wkt(precision: 4)
  puts "    #{wkt}"
end

# ── Summary ───────────────────────────────────────────────────────────

section "SUMMARY"

puts <<~HEREDOC

  GEOS-only operations demonstrated:

    Boolean operations:
      Geos.intersection(a, b)          Area of overlap
      Geos.difference(a, b)            A minus B
      Geos.symmetric_difference(a, b)  XOR of two geometries
      Geos.union(a)                    Dissolve internal boundaries

    Geometry construction:
      Geos.buffer(geom, distance)      Buffer zone around any geometry
      Geos.buffer_with_style(...)      Buffer with cap/join style control
      Geos.convex_hull(geom)           Smallest enclosing convex polygon
      Geos.simplify(geom, tolerance)   Douglas-Peucker vertex reduction

    Validation and repair:
      Geos.is_valid?(geom)             OGC validity check
      Geos.is_valid_reason(geom)       Human-readable invalidity reason
      Geos.make_valid(geom)            Repair invalid geometries

    Measurements:
      Geos.area(geom)                  Planar area (sq degrees for LLA)
      Geos.length(geom)                Planar perimeter/length
      Geos.distance(a, b)              Minimum planar distance
      Geos.nearest_points(a, b)        Closest point pair [LLA, LLA]

    Batch spatial indexing:
      Geos.prepare(polygon)            Build spatial index
      prepared.contains?(point)        O(log n) containment
      prepared.intersects?(geom)       O(log n) intersection
      prepared.release                 Free GEOS memory

  All results are standard Geodetic objects — they work with to_wkt,
  to_wkb, to_geojson, distance_to, bearing_to, includes?, and every
  other Geodetic method.

  Install GEOS:  brew install geos
  See also:      ruby -Ilib examples/12_geos_benchmark.rb
HEREDOC
