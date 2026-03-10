#!/usr/bin/env ruby

# Demonstration of Segment and polygon subclasses (Triangle, Rectangle,
# Pentagon, Hexagon, Octagon). Shows construction, properties, predicates,
# containment testing, segment access, bounding boxes, and Feature integration.

require_relative "../lib/geodetic"

include Geodetic
LLA = Coordinate::LLA

# ── Notable locations around the National Mall, Washington DC ─────

lincoln     = LLA.new(lat: 38.8893, lng: -77.0502, alt: 0)
washington  = LLA.new(lat: 38.8895, lng: -77.0353, alt: 0)
capitol     = LLA.new(lat: 38.8899, lng: -77.0091, alt: 0)
white_house = LLA.new(lat: 38.8977, lng: -77.0365, alt: 0)
jefferson   = LLA.new(lat: 38.8814, lng: -77.0365, alt: 0)
pentagon    = LLA.new(lat: 38.8719, lng: -77.0563, alt: 0)

puts "=== Segments and Shapes Demo ==="
puts

# ── 1. Segment Basics ────────────────────────────────────────────

puts "--- 1. Segment ---"
puts

seg = Segment.new(lincoln, washington)

puts <<~SEG
  Lincoln Memorial -> Washington Monument
  Length:   #{seg.length.to_s}  (#{seg.length_meters.round(1)} m)
  Distance: #{seg.distance.to_s}  (alias for length)
  Bearing:  #{seg.bearing.to_s}  (#{seg.bearing.to_compass})
  Midpoint: #{seg.midpoint.to_s(4)}
  Centroid: #{seg.centroid.to_s(4)}  (alias for midpoint)
SEG
puts

# ── 2. Segment Operations ───────────────────────────────────────

puts "--- 2. Segment Operations ---"
puts

quarter = seg.interpolate(0.25)
puts "  Quarter-way point:  #{quarter.to_s(4)}"
puts "  Reverse bearing:    #{seg.reverse.bearing.to_s}"
puts

foot, dist_m = seg.project(white_house)
puts "  Project White House onto Lincoln-Washington segment:"
puts "  Foot:     #{foot.to_s(4)}"
puts "  Distance: #{dist_m.round(1)} m from segment"
puts

puts "  White House is a vertex?   #{seg.includes?(white_house)}"
puts "  Lincoln is a vertex?       #{seg.includes?(lincoln)}"
puts "  Midpoint on segment?       #{seg.contains?(seg.midpoint)}"
puts "  White House on segment?    #{seg.contains?(white_house)}"
puts

# ── 3. Segment Intersection ─────────────────────────────────────

puts "--- 3. Segment Intersection ---"
puts

mall_ns = Segment.new(white_house, jefferson)
mall_ew = Segment.new(lincoln, capitol)

puts "  N-S segment: White House -> Jefferson Memorial"
puts "  E-W segment: Lincoln Memorial -> Capitol"
puts "  Intersects?  #{mall_ew.intersects?(mall_ns)}"
puts

parallel = Segment.new(
  LLA.new(lat: 38.892, lng: -77.050, alt: 0),
  LLA.new(lat: 38.892, lng: -77.010, alt: 0)
)
puts "  Parallel segment (north of Mall):"
puts "  Intersects E-W?  #{mall_ew.intersects?(parallel)}"
puts

# ── 4. Triangle ──────────────────────────────────────────────────

puts "--- 4. Triangle ---"
puts

puts "  Isosceles (center + width + height):"
tri = Areas::Triangle.new(center: washington, width: 400, height: 600, bearing: 0)
puts "    Sides:       #{tri.sides}"
puts "    Width:       #{tri.width} m"
puts "    Height:      #{tri.height} m"
puts "    Bearing:     #{tri.bearing}\u00B0"
puts "    Equilateral? #{tri.equilateral?}"
puts "    Isosceles?   #{tri.isosceles?}"
puts "    Scalene?     #{tri.scalene?}"
puts "    Side lengths: #{tri.side_lengths.map { |l| "#{l.round(1)} m" }.join(', ')}"
puts "    Center inside?  #{tri.includes?(washington)}"
puts

puts "  Equilateral by side (500m):"
eq_tri = Areas::Triangle.new(center: washington, side: 500, bearing: 30)
puts "    Equilateral? #{eq_tri.equilateral?}"
puts "    Side lengths: #{eq_tri.side_lengths.map { |l| "#{l.round(1)} m" }.join(', ')}"
puts

puts "  Equilateral by radius (300m):"
r_tri = Areas::Triangle.new(center: washington, radius: 300, bearing: 0)
puts "    Equilateral? #{r_tri.equilateral?}"
puts "    Width:  #{r_tri.width.round(1)} m"
puts "    Height: #{r_tri.height.round(1)} m"
puts

puts "  Arbitrary 3 vertices:"
arb_tri = Areas::Triangle.new(vertices: [lincoln, washington, white_house])
puts "    Scalene?     #{arb_tri.scalene?}"
puts "    Side lengths: #{arb_tri.side_lengths.map { |l| "#{l.round(1)} m" }.join(', ')}"
puts "    Washington inside? #{arb_tri.includes?(washington)}"
puts

# ── 5. Rectangle ────────────────────────────────────────────────

puts "--- 5. Rectangle ---"
puts

puts "  From a Segment (Lincoln -> Washington) + width:"
centerline = Segment.new(lincoln, washington)
rect = Areas::Rectangle.new(segment: centerline, width: 200)

puts "    Width:     #{rect.width} m"
puts "    Height:    #{rect.height.round(1)} m"
puts "    Bearing:   #{rect.bearing.round(1)}\u00B0"
puts "    Center:    #{rect.center.to_s(4)}"
puts "    Square?    #{rect.square?}"
puts "    Sides:     #{rect.sides}"
puts "    Corners:   #{rect.corners.size}"
puts "    Centerline start: #{rect.centerline.start_point.to_s(4)}"
puts "    Centerline end:   #{rect.centerline.end_point.to_s(4)}"
puts

puts "  From an array of two points + width:"
rect2 = Areas::Rectangle.new(segment: [white_house, jefferson], width: 300)
puts "    Width:   #{rect2.width} m"
puts "    Height:  #{rect2.height.round(1)} m"
puts "    Bearing: #{rect2.bearing.round(1)}\u00B0"
puts "    Square?  #{rect2.square?}"
puts

puts "  Square rectangle (width = segment distance):"
short_seg = Segment.new(lincoln, seg.interpolate(0.1))
sq = Areas::Rectangle.new(segment: short_seg, width: short_seg.distance)
puts "    Width:   #{sq.width.round(1)} m"
puts "    Height:  #{sq.height.round(1)} m"
puts "    Square?  #{sq.square?}"
puts

# ── 6. Pentagon, Hexagon, Octagon ────────────────────────────────

puts "--- 6. Regular Polygons ---"
puts

[
  ["Pentagon", Areas::Pentagon.new(center: washington, radius: 500, bearing: 0)],
  ["Hexagon",  Areas::Hexagon.new(center: washington, radius: 500, bearing: 0)],
  ["Octagon",  Areas::Octagon.new(center: washington, radius: 500, bearing: 0)]
].each do |name, shape|
  puts "  #{name}:"
  puts "    Sides:    #{shape.sides}"
  puts "    Radius:   #{shape.radius} m"
  puts "    Vertices: #{shape.boundary.size - 1} (boundary has #{shape.boundary.size} points, closed)"
  puts "    Centroid: #{shape.centroid.to_s(4)}"
  puts "    Center inside?  #{shape.includes?(washington)}"
  puts "    Pentagon inside? #{shape.includes?(pentagon)}"
  puts
end

# ── 7. Polygon Segments ─────────────────────────────────────────

puts "--- 7. Polygon Segments ---"
puts

puts "  Rectangle segments (edges/border):"
rect.segments.each_with_index do |s, i|
  puts "    Edge #{i + 1}: #{s.length_meters.round(1)} m, bearing #{s.bearing.to_s}"
end
puts "    Connected? #{rect.segments.each_cons(2).all? { |a, b| a.end_point == b.start_point }}"
puts

puts "  Triangle segments:"
tri.segments.each_with_index do |s, i|
  puts "    Side #{i + 1}: #{s.length_meters.round(1)} m"
end
puts

# ── 8. Bounding Boxes ───────────────────────────────────────────

puts "--- 8. Bounding Boxes ---"
puts

[
  ["Triangle",  tri],
  ["Rectangle", rect]
].each do |name, shape|
  bbox = shape.to_bounding_box
  puts "  #{name}:"
  puts "    NW: #{bbox.nw.to_s(4)}"
  puts "    SE: #{bbox.se.to_s(4)}"

  shape_center = shape.respond_to?(:center) ? shape.center : shape.centroid
  puts "    Center inside bbox? #{bbox.includes?(shape_center)}"
  puts
end

# ── 9. Containment ──────────────────────────────────────────────

puts "--- 9. Containment Testing ---"
puts

hex = Areas::Hexagon.new(center: washington, radius: 500)

test_points = {
  "Washington Monument" => washington,
  "Lincoln Memorial"    => lincoln,
  "White House"         => white_house,
  "Pentagon"            => pentagon
}

puts "  Hexagon (500m radius around Washington Monument):"
test_points.each do |name, point|
  dist = washington.distance_to(point)
  puts "    #{name.ljust(22)} inside? #{hex.includes?(point).to_s.ljust(5)}  (#{dist.to_s} away)"
end
puts

# ── 10. Feature Integration ─────────────────────────────────────

puts "--- 10. Feature Integration ---"
puts

seg_feature = Feature.new(label: "National Mall Axis", geometry: centerline)
tri_feature = Feature.new(label: "Warning Zone", geometry: tri, metadata: { type: "restricted" })
rect_feature = Feature.new(label: "Search Area", geometry: rect, metadata: { priority: "high" })

puts "  Segment feature: #{seg_feature}"
puts "  Triangle feature: #{tri_feature}"
puts "  Rectangle feature: #{rect_feature}"
puts

puts "  Distance from each feature to the Pentagon:"
[seg_feature, tri_feature, rect_feature].each do |f|
  dist = f.distance_to(pentagon)
  bearing = f.bearing_to(pentagon)
  puts "    #{f.label.ljust(20)} #{dist.to_s.rjust(12)}  bearing #{bearing.to_s} (#{bearing.to_compass})"
end
puts

puts "=== Done ==="
