#!/usr/bin/env ruby
# frozen_string_literal: true

# S2 Geometry Coordinate System — Complete Demo
#
# Demonstrates all capabilities of the Geodetic::Coordinate::S2 class:
#   1. Construction (from lat/lng, token, integer, other coordinates)
#   2. Properties (level, face, token, cell_id)
#   3. Round-trip coordinate conversion
#   4. Cell hierarchy (parent, children, ancestry)
#   5. Edge neighbors
#   6. Containment and intersection
#   7. Cell area calculations
#   8. Cell polygons (to_area)
#   9. Database range scans
#  10. Cross-hash conversions (S2 ↔ GH, OLC, H3, etc.)
#  11. Distance and bearing
#  12. Arithmetic (Vector translation)
#  13. Serialization (WKT, GeoJSON)
#  14. The six cube faces
#  15. Performance characteristics
#
# Requires: brew install s2geometry
# Run:      ruby -Ilib examples/15_s2_geometry.rb

require_relative '../lib/geodetic'
require 'benchmark'

S2      = Geodetic::Coordinate::S2
LLA     = Geodetic::Coordinate::LLA
H3      = Geodetic::Coordinate::H3
GH      = Geodetic::Coordinate::GH
OLC     = Geodetic::Coordinate::OLC
Polygon = Geodetic::Areas::Polygon

unless S2.available?
  abort "libs2 not found. Install with: brew install s2geometry"
end

def section(title)
  puts
  puts "=" * 70
  puts "  #{title}"
  puts "=" * 70
  puts
end

def format_area(m2)
  if m2 > 1_000_000
    "%.1f km²" % (m2 / 1_000_000)
  elsif m2 > 1
    "%.1f m²" % m2
  else
    "%.2f cm²" % (m2 * 10_000)
  end
end

# =========================================================================
section "1. Construction"
# =========================================================================

seattle = LLA.new(lat: 47.6062, lng: -122.3321)

puts "From LLA (default level 15):"
s2 = S2.new(seattle)
puts "  #{s2.inspect}"

puts
puts "From LLA with custom level:"
[5, 10, 15, 20, 25, 30].each do |lvl|
  cell = S2.new(seattle, precision: lvl)
  printf("  Level %2d: token=%-18s  cell_id=%d\n", lvl, cell.to_s, cell.cell_id)
end

puts
puts "From token string:"
restored = S2.new("54906ab12f10f899")
puts "  S2.new(\"54906ab12f10f899\") => level=#{restored.level}, face=#{restored.face}"

puts
puts "From integer cell ID:"
from_int = S2.new(6093487605063678105)
puts "  S2.new(6093487605063678105) => token=#{from_int.to_s}"

puts
puts "From 0x-prefixed hex:"
from_hex = S2.new("0x54906ab12f10f899")
puts "  S2.new(\"0x54906ab12f10f899\") => token=#{from_hex.to_s}"

puts
puts "From other coordinate systems:"
ecef = seattle.to_ecef
utm  = seattle.to_utm
puts "  From ECEF: #{S2.new(ecef)}"
puts "  From UTM:  #{S2.new(utm)}"

# =========================================================================
section "2. Properties"
# =========================================================================

cell = S2.new(seattle, precision: 15)
puts <<~PROPS
  token:      #{cell.to_s}
  cell_id:    #{cell.cell_id}
  level:      #{cell.level}
  face:       #{cell.face}
  valid?:     #{cell.valid?}
  leaf?:      #{cell.leaf?}
  face_cell?: #{cell.face_cell?}
PROPS

puts
puts "Integer format: #{cell.to_s(:integer)}"
puts "Inspect:        #{cell.inspect}"

# =========================================================================
section "3. Round-trip Coordinate Conversion"
# =========================================================================

places = {
  "Seattle"        => [47.6062, -122.3321],
  "New York"       => [40.7128, -74.0060],
  "Tokyo"          => [35.6762, 139.6503],
  "Sydney"         => [-33.8688, 151.2093],
  "London"         => [51.5074, -0.1278],
  "Null Island"    => [0.0, 0.0],
  "Near N. Pole"   => [89.99, 45.0],
  "Near S. Pole"   => [-89.99, -135.0],
  "Antimeridian"   => [0.0, 179.999],
}

puts "lat/lng -> S2 (level 30) -> lat/lng:"
places.each do |name, (lat, lng)|
  s = S2.new(LLA.new(lat: lat, lng: lng), precision: 30)
  lla = s.to_lla
  err = [(lat - lla.lat).abs, (lng - lla.lng).abs].max
  printf("  %-14s (%8.4f, %9.4f) -> (%8.4f, %9.4f)  err=%.1e°\n",
    name, lat, lng, lla.lat, lla.lng, err)
end

# =========================================================================
section "4. Cell Hierarchy"
# =========================================================================

leaf = S2.new(seattle, precision: 30)
puts "Ancestry of Seattle leaf cell (level 30 -> 0):"
[30, 25, 20, 15, 10, 5, 1, 0].each do |lvl|
  ancestor = lvl == 30 ? leaf : leaf.parent(lvl)
  printf("  Level %2d: %-18s  face=%d  area=%s\n",
    lvl, ancestor.to_s, ancestor.face, format_area(ancestor.cell_area))
end

puts
puts "Children of level-10 cell:"
parent10 = S2.new(seattle, precision: 10)
parent10.children.each_with_index do |child, i|
  printf("  Child %d: %-18s  level=%d\n", i, child.to_s, child.level)
end

puts
puts "Grandchildren (level 10 -> 12, two generations):"
count = 0
parent10.children.each do |child|
  child.children.each do |grandchild|
    printf("  %-18s  level=%d\n", grandchild.to_s, grandchild.level)
    count += 1
  end
end
puts "  Total: #{count} cells (4^2 = 16)"

# =========================================================================
section "5. Edge Neighbors"
# =========================================================================

cell15 = S2.new(seattle, precision: 15)
puts "Edge neighbors of #{cell15.to_s} (level #{cell15.level}):"
cell15.neighbors.each_with_index do |n, i|
  printf("  [%d] %-18s  level=%d  face=%d\n", i, n.to_s, n.level, n.face)
end

puts
puts "Neighbor chain — walk 5 steps in one direction:"
current = cell15
5.times do |step|
  nbrs = current.neighbors
  current = nbrs[0]
  printf("  Step %d: %-18s\n", step + 1, current.to_s)
end

# =========================================================================
section "6. Containment and Intersection"
# =========================================================================

coarse = S2.new(seattle, precision: 10)
fine   = S2.new(seattle, precision: 20)
other  = S2.new(LLA.new(lat: 35.6762, lng: 139.6503), precision: 20)

puts <<~CONTAIN
  Level 10 contains level 20 (same location)?  #{coarse.contains?(fine)}
  Level 20 contains level 10?                   #{fine.contains?(coarse)}
  Level 10 intersects level 20?                 #{coarse.intersects?(fine)}
  Seattle L20 intersects Tokyo L20?             #{fine.intersects?(other)}
  Cell contains itself?                         #{coarse.contains?(coarse)}
CONTAIN

# =========================================================================
section "7. Cell Area Calculations"
# =========================================================================

puts "Exact area for Seattle cells at each level:"
[0, 5, 10, 12, 15, 18, 20, 24, 28, 30].each do |lvl|
  c = S2.new(seattle, precision: lvl)
  printf("  Level %2d: %s\n", lvl, format_area(c.cell_area))
end

puts
puts "Average cell area by level:"
[0, 5, 10, 15, 20, 25, 30].each do |lvl|
  printf("  Level %2d: %s (avg)\n", lvl, format_area(S2.average_cell_area(lvl)))
end

puts
puts "Precision in meters (level 15):"
pm = cell15.precision_in_meters
printf("  edge ≈ %.0f m, area ≈ %s\n", pm[:lat], format_area(pm[:area_m2]))

# =========================================================================
section "8. Cell Polygons (to_area)"
# =========================================================================

polygon = cell15.to_area
puts "Level 15 cell as polygon:"
puts "  Type: #{polygon.class}"
puts "  Vertices: #{polygon.boundary.length - 1} (quadrilateral + closing point)"
polygon.boundary[0..3].each_with_index do |v, i|
  printf("  v%d: (%.6f, %.6f)\n", i, v.lat, v.lng)
end

puts
puts "Point-in-polygon test:"
center = cell15.to_lla
puts "  Cell center inside polygon? #{polygon.includes?(center)}"
far_away = LLA.new(lat: 0.0, lng: 0.0)
puts "  Null Island inside polygon? #{polygon.includes?(far_away)}"

# =========================================================================
section "9. Database Range Scans"
# =========================================================================

cell12 = S2.new(seattle, precision: 12)
puts "Cell ID range for level 12 cell #{cell12.to_s}:"
printf("  range_min: 0x%016x\n", cell12.range_min)
printf("  cell_id:   0x%016x\n", cell12.cell_id)
printf("  range_max: 0x%016x\n", cell12.range_max)

puts
puts "Child cells fall within parent range:"
child20 = S2.new(seattle, precision: 20)
in_range = child20.cell_id >= cell12.range_min && child20.cell_id <= cell12.range_max
puts "  Level 20 child in level 12 range? #{in_range}"

puts
puts "SQL-style range query:"
puts "  SELECT * FROM locations"
puts "  WHERE s2_cell_id BETWEEN #{cell12.range_min} AND #{cell12.range_max}"

# =========================================================================
section "10. Cross-Hash Conversions"
# =========================================================================

s2_cell = S2.new(seattle, precision: 15)
puts "S2 #{s2_cell.to_s} converts to:"
puts "  Geohash:    #{s2_cell.to_gh}"
puts "  Open Loc.:  #{s2_cell.to_olc}"
puts "  Geohash-36: #{s2_cell.to_gh36}"
puts "  HAM:        #{s2_cell.to_ham}"
puts "  GEOREF:     #{s2_cell.to_georef}"
puts "  GARS:       #{s2_cell.to_gars}"
if H3.available?
  puts "  H3:         #{s2_cell.to_h3}"
end

puts
puts "Reverse conversions to S2:"
puts "  GH \"c23nb5\"     -> #{GH.new('c23nb5').to_s2}"
puts "  OLC \"84VVJM48+\" -> #{OLC.new('84VVJM48+').to_s2}"
if H3.available?
  h3 = H3.new(seattle, precision: 7)
  puts "  H3 #{h3}  -> #{h3.to_s2}"
end

puts
puts "LLA convenience methods:"
puts "  seattle.to_s2              => #{seattle.to_s2}"
puts "  seattle.to_s2(precision: 5) => #{seattle.to_s2(precision: 5)}"

# =========================================================================
section "11. Distance and Bearing"
# =========================================================================

s2_seattle = S2.new(seattle, precision: 15)
s2_nyc     = S2.new(LLA.new(lat: 40.7128, lng: -74.0060), precision: 15)
s2_tokyo   = S2.new(LLA.new(lat: 35.6762, lng: 139.6503), precision: 15)
s2_london  = S2.new(LLA.new(lat: 51.5074, lng: -0.1278), precision: 15)

puts "Great-circle distances from Seattle S2 cell:"
[[s2_nyc, "NYC"], [s2_tokyo, "Tokyo"], [s2_london, "London"]].each do |target, name|
  d = s2_seattle.distance_to(target)
  b = s2_seattle.bearing_to(target)
  printf("  -> %-7s %7.0f km  bearing %5.1f° (%s)\n",
    name, d.meters / 1000, b.degrees, b.to_compass)
end

# =========================================================================
section "12. Arithmetic (Vector Translation)"
# =========================================================================

v_east = Geodetic::Vector.new(distance: 10_000, bearing: 90)
v_north = Geodetic::Vector.new(distance: 5_000, bearing: 0)

puts "Translate S2 cell center by vectors:"
s = S2.new(seattle, precision: 15)

result = s * v_east
puts "  S2 * Vector(10km, 90°E) => #{result.class.name.split('::').last}: #{result}"

seg = s + v_north
puts "  S2 + Vector(5km, 0°N)   => #{seg.class.name.split('::').last}: #{seg}"

# =========================================================================
section "13. Serialization"
# =========================================================================

s = S2.new(seattle, precision: 15)

puts "WKT:"
puts "  #{s.to_wkt}"

puts
puts "WKT with SRID:"
puts "  #{s.to_wkt(srid: 4326)}"

puts
puts "GeoJSON (point):"
gj = s.to_geojson
puts "  type: #{gj['type']}"
puts "  coordinates: #{gj['coordinates']}"

puts
puts "Cell polygon WKT:"
poly = s.to_area
puts "  #{poly.to_wkt}"

puts
puts "Cell polygon GeoJSON:"
pgj = poly.to_geojson
puts "  type: #{pgj['type']}"
puts "  coordinates: [#{pgj['coordinates'].first.length} vertices]"

puts
puts "WKB (hex, first 40 chars):"
puts "  #{s.to_wkb_hex[0..39]}..."

# =========================================================================
section "14. The Six Cube Faces"
# =========================================================================

puts "S2 projects a cube onto the sphere with 6 faces:"
face_centers = [
  [0.0,    0.0],    # Face 0: +X (front)
  [0.0,   90.0],    # Face 1: +Y (right)
  [90.0,   0.0],    # Face 2: +Z (top / north pole)
  [0.0,  180.0],    # Face 3: -X (back)
  [0.0,  -90.0],    # Face 4: -Y (left)
  [-90.0,  0.0],    # Face 5: -Z (bottom / south pole)
]

face_names = ["+X (front)", "+Y (right)", "+Z (north pole)",
              "-X (back)", "-Y (left)", "-Z (south pole)"]

face_centers.each_with_index do |(lat, lng), expected_face|
  c = S2.new(LLA.new(lat: lat, lng: lng), precision: 0)
  printf("  Face %d %-18s: lat=%6.1f, lng=%7.1f  token=%s  area=%s\n",
    c.face, face_names[expected_face], lat, lng, c.to_s, format_area(c.cell_area))
end

puts
puts "Cells near face boundaries (equator at different longitudes):"
[0, 45, 90, 135, 180, -135, -90, -45].each do |lng|
  c = S2.new(LLA.new(lat: 0.0, lng: lng.to_f), precision: 5)
  printf("  Equator, lng=%4d°: face=%d  token=%s\n", lng, c.face, c.to_s)
end

# =========================================================================
section "15. Performance Characteristics"
# =========================================================================

n = 200_000
puts "Benchmarking #{n} iterations:"
puts

s = S2.new(seattle, precision: 15)
token = s.to_s
leaf = S2.new(seattle, precision: 30)
child = S2.new(seattle, precision: 20)

benchmarks = {
  "encode (LLA->S2)"     => -> { n.times { S2.from_lla(seattle, Geodetic::WGS84, 15) } },
  "decode (S2->LLA)"     => -> { n.times { s.to_lla } },
  "from_token"            => -> { n.times { S2.new(token) } },
  "to_s (token)"          => -> { n.times { s.to_s } },
  "parent_at_level"       => -> { n.times { leaf.parent(10) } },
  "edge_neighbors"        => -> { n.times { s.neighbors } },
  "cell_area"             => -> { n.times { s.cell_area } },
  "to_area (polygon)"     => -> { n.times { s.to_area } },
  "contains?"             => -> { n.times { s.contains?(child) } },
}

printf("  %-22s  %10s  %12s\n", "Operation", "Time (s)", "Ops/sec")
printf("  %-22s  %10s  %12s\n", "-" * 22, "-" * 10, "-" * 12)

benchmarks.each do |label, work|
  elapsed = Benchmark.realtime { work.call }
  ops_sec = (n / elapsed).round(0)
  printf("  %-22s  %10.3f  %12s\n", label, elapsed, ops_sec.to_s.reverse.gsub(/(\d{3})(?=\d)/, '\\1,').reverse)
end

puts
puts "Done!"
