#!/usr/bin/env ruby
# frozen_string_literal: true

# GEOS Performance Benchmark
#
# Compares pure Ruby spatial operations against GEOS-accelerated versions.
# Uses GEODETIC_GEOS_DISABLE env var to force Ruby-only execution, then
# runs the same operations with GEOS enabled.
#
# Requires: brew install geos
# Run:      ruby -Ilib examples/12_geos_benchmark.rb

require_relative '../lib/geodetic'
require 'benchmark'

LLA     = Geodetic::Coordinate::LLA
Polygon = Geodetic::Areas::Polygon
Path    = Geodetic::Path
Segment = Geodetic::Segment
Geos    = Geodetic::Geos

unless Geos::LibGEOS.available?
  abort "libgeos_c not found. Install with: brew install geos"
end

# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

def make_polygon(n_vertices, center_lat: 40.0, center_lng: -74.0, radius_deg: 1.0)
  step = 360.0 / n_vertices
  boundary = n_vertices.times.map do |i|
    angle = i * step * Geodetic::RAD_PER_DEG
    LLA.new(
      lat: center_lat + radius_deg * Math.sin(angle),
      lng: center_lng + radius_deg * Math.cos(angle),
      alt: 0.0
    )
  end
  Polygon.new(boundary: boundary)
end

def make_path(n_points, start_lat: 40.0, start_lng: -74.0, step_deg: 0.01, zigzag: 0.001)
  coords = n_points.times.map do |i|
    LLA.new(
      lat: start_lat + (i.even? ? zigzag : -zigzag),
      lng: start_lng + i * step_deg,
      alt: 0.0
    )
  end
  Path.new(coordinates: coords)
end

def section(title)
  puts
  puts "=" * 70
  puts title
  puts "=" * 70
end

def speedup(ruby_time, geos_time)
  return "N/A" if geos_time == 0
  ratio = ruby_time / geos_time
  format("%.1fx", ratio)
end

# ---------------------------------------------------------------------------
# Collect timings for Ruby-only vs GEOS
# ---------------------------------------------------------------------------

results = []

# --- 1. Polygon validation ------------------------------------------------

section "1. POLYGON VALIDATION"
puts "   Ruby uses O(n^2) pairwise segment tests."
puts "   GEOS uses an O(n log n) spatial index."

[50, 100, 500].each do |n|
  boundary = n.times.map do |i|
    angle = i * (360.0 / n) * Geodetic::RAD_PER_DEG
    LLA.new(lat: 40.0 + Math.sin(angle), lng: -74.0 + Math.cos(angle), alt: 0.0)
  end
  iterations = n <= 100 ? 500 : 50

  puts "\n  #{n} vertices, #{iterations} iterations:"

  # Ruby-only (disable GEOS)
  ENV['GEODETIC_GEOS_DISABLE'] = '1'
  ruby_time = Benchmark.realtime do
    iterations.times { Polygon.new(boundary: boundary.dup) }
  end

  # GEOS-enabled
  ENV.delete('GEODETIC_GEOS_DISABLE')
  geos_time = Benchmark.realtime do
    iterations.times { Polygon.new(boundary: boundary.dup) }
  end

  puts format("    Ruby:  %8.4fs", ruby_time)
  puts format("    GEOS:  %8.4fs  (%s faster)", geos_time, speedup(ruby_time, geos_time))
  results << { test: "Validation #{n}v", ruby: ruby_time, geos: geos_time }
end

# --- 2. Point-in-polygon --------------------------------------------------

section "2. POINT-IN-POLYGON"
puts "   Ruby uses winding-number with bearing calculations."
puts "   GEOS uses computational geometry contains test."
puts "   Threshold: polygons with >= #{Polygon::GEOS_INCLUDES_THRESHOLD} vertices use GEOS."

test_point = LLA.new(lat: 40.0, lng: -74.0, alt: 0.0)

[8, 30, 100, 500].each do |n|
  polygon = make_polygon(n)
  iterations = n <= 100 ? 5_000 : 1_000

  above = n >= Polygon::GEOS_INCLUDES_THRESHOLD
  label = above ? "GEOS" : "Ruby (below threshold)"
  puts "\n  #{n} vertices -> #{label}, #{iterations} iterations:"

  ENV['GEODETIC_GEOS_DISABLE'] = '1'
  ruby_time = Benchmark.realtime do
    iterations.times { polygon.includes?(test_point) }
  end

  ENV.delete('GEODETIC_GEOS_DISABLE')
  geos_time = Benchmark.realtime do
    iterations.times { polygon.includes?(test_point) }
  end

  puts format("    Ruby:  %8.4fs", ruby_time)
  puts format("    GEOS:  %8.4fs  (%s faster)", geos_time, speedup(ruby_time, geos_time))
  results << { test: "Includes #{n}v", ruby: ruby_time, geos: geos_time }
end

# --- 3. Path intersection -------------------------------------------------

section "3. PATH INTERSECTION"
puts "   Ruby uses O(n*m) pairwise segment tests."
puts "   GEOS uses spatial indexing for fast intersection."
puts "   Non-intersecting paths with overlapping bounds (worst case for Ruby)."

[100, 500, 1000].each do |n|
  # Two zigzag paths: bounds overlap but segments don't cross.
  # Ruby must check all O(n*m) segment pairs before returning false.
  path1 = make_path(n, start_lat: 40.0, zigzag: 0.05)
  path2 = make_path(n, start_lat: 40.08, zigzag: 0.05)
  iterations = [5000 / n, 5].max

  puts "\n  #{n} points per path, #{iterations} iterations:"

  ENV['GEODETIC_GEOS_DISABLE'] = '1'
  ruby_time = Benchmark.realtime do
    iterations.times { path1.intersects?(path2) }
  end

  ENV.delete('GEODETIC_GEOS_DISABLE')
  geos_time = Benchmark.realtime do
    iterations.times { path1.intersects?(path2) }
  end

  puts format("    Ruby:  %8.4fs", ruby_time)
  puts format("    GEOS:  %8.4fs  (%s faster)", geos_time, speedup(ruby_time, geos_time))
  results << { test: "Path intersect #{n}pt", ruby: ruby_time, geos: geos_time }
end

# --- 4. Batch containment with PreparedGeometry ----------------------------

section "4. BATCH CONTAINMENT (PreparedGeometry)"
puts "   Testing 1,000 random points against a 100-vertex polygon."
puts "   PreparedGeometry builds a spatial index once, then queries are O(log n)."

srand(42) # reproducible random points
polygon = make_polygon(100)
test_points = 1_000.times.map do
  LLA.new(lat: 39.0 + rand * 2.0, lng: -75.0 + rand * 2.0, alt: 0.0)
end

ENV['GEODETIC_GEOS_DISABLE'] = '1'
ruby_time = Benchmark.realtime do
  test_points.each { |pt| polygon.includes?(pt) }
end

ENV.delete('GEODETIC_GEOS_DISABLE')
geos_one_shot_time = Benchmark.realtime do
  test_points.each { |pt| polygon.includes?(pt) }
end

prepared_time = Benchmark.realtime do
  prepared = Geos.prepare(polygon)
  test_points.each { |pt| prepared.contains?(pt) }
  prepared.release
end

puts format("\n    Ruby:          %8.4fs", ruby_time)
puts format("    GEOS one-shot: %8.4fs  (%s faster)", geos_one_shot_time, speedup(ruby_time, geos_one_shot_time))
puts format("    GEOS prepared: %8.4fs  (%s faster)", prepared_time, speedup(ruby_time, prepared_time))
results << { test: "Batch 1k points", ruby: ruby_time, geos: prepared_time }

# --- 5. Segment intersection (Ruby wins) ----------------------------------

section "5. SINGLE SEGMENT INTERSECTION (Ruby wins here)"
puts "   For trivial operations, FFI overhead exceeds the computation cost."
puts "   Geodetic correctly keeps Ruby for this case."

seg1 = Segment.new(
  LLA.new(lat: 0.0, lng: 0.0, alt: 0.0),
  LLA.new(lat: 2.0, lng: 2.0, alt: 0.0)
)
seg2 = Segment.new(
  LLA.new(lat: 0.0, lng: 2.0, alt: 0.0),
  LLA.new(lat: 2.0, lng: 0.0, alt: 0.0)
)
iterations = 50_000

ruby_time = Benchmark.realtime { iterations.times { seg1.intersects?(seg2) } }
geos_time = Benchmark.realtime { iterations.times { Geos.intersects?(seg1, seg2) } }

puts format("\n    Ruby:  %8.4fs", ruby_time)
puts format("    GEOS:  %8.4fs  (Ruby is %s faster)", geos_time, speedup(geos_time, ruby_time))

# --- 6. GEOS-only operations ----------------------------------------------

section "6. GEOS-ONLY OPERATIONS (no Ruby equivalent)"
puts "   These capabilities are only available when GEOS is installed."

poly_a = make_polygon(100, center_lat: 40.0, center_lng: -74.0, radius_deg: 1.0)
poly_b = make_polygon(100, center_lat: 40.5, center_lng: -73.5, radius_deg: 1.0)
iterations = 500

puts "\n  Two 100-vertex polygons, #{iterations} iterations each:"
Benchmark.bm(22) do |x|
  x.report("  intersection")    { iterations.times { Geos.intersection(poly_a, poly_b) } }
  x.report("  difference")      { iterations.times { Geos.difference(poly_a, poly_b) } }
  x.report("  symmetric_diff")  { iterations.times { Geos.symmetric_difference(poly_a, poly_b) } }
  x.report("  convex_hull")     { iterations.times { Geos.convex_hull(poly_a) } }
  x.report("  simplify(0.01)")  { iterations.times { Geos.simplify(poly_a, 0.01) } }
  x.report("  is_valid?")       { iterations.times { Geos.is_valid?(poly_a) } }
  x.report("  area")            { iterations.times { Geos.area(poly_a) } }
  x.report("  nearest_points")  { iterations.times { Geos.nearest_points(poly_a, poly_b) } }
end

# --- Summary ---------------------------------------------------------------

section "SUMMARY"
puts
puts format("  %-25s %10s %10s %10s", "Test", "Ruby", "GEOS", "Speedup")
puts "  " + "-" * 57

results.each do |r|
  puts format("  %-25s %9.4fs %9.4fs %10s",
    r[:test], r[:ruby], r[:geos], speedup(r[:ruby], r[:geos]))
end

puts
puts "  Note: GEOS acceleration is automatic when libgeos_c is installed."
puts "  Set GEODETIC_GEOS_DISABLE=1 to force pure Ruby for all operations."
