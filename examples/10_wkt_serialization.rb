#!/usr/bin/env ruby

# Demonstration of WKT (Well-Known Text) Serialization
# Shows export, import, roundtrip, SRID/EWKT, and Z-dimension handling.

require_relative "../lib/geodetic"

include Geodetic

LLA      = Coordinate::LLA
Distance = Geodetic::Distance

puts "=== WKT Serialization Demo ==="
puts

# ── 1. Coordinate → POINT ──────────────────────────────────────────

puts "--- 1. Coordinate → POINT ---"
puts

seattle = LLA.new(lat: 47.6205, lng: -122.3493, alt: 0.0)
puts "  seattle.to_wkt"
puts "  => #{seattle.to_wkt}"
puts

# Works from any coordinate system — converts through LLA
utm = seattle.to_utm
puts "  seattle.to_utm.to_wkt"
puts "  => #{utm.to_wkt}"
puts

# Altitude triggers Z suffix
space_needle = LLA.new(lat: 47.6205, lng: -122.3493, alt: 184.0)
puts "  With altitude:"
puts "  => #{space_needle.to_wkt}"
puts

# Custom precision
puts "  Custom precision (2):"
puts "  => #{seattle.to_wkt(precision: 2)}"
puts

# ── 2. Segment → LINESTRING ────────────────────────────────────────

puts "--- 2. Segment → LINESTRING ---"
puts

portland = LLA.new(lat: 45.5152, lng: -122.6784, alt: 0.0)
seg = Segment.new(seattle, portland)
puts "  #{seg.to_wkt}"
puts

# ── 3. Path → LINESTRING or POLYGON ────────────────────────────────

puts "--- 3. Path → LINESTRING / POLYGON ---"
puts

sf = LLA.new(lat: 37.7749, lng: -122.4194, alt: 0.0)
la = LLA.new(lat: 34.0522, lng: -118.2437, alt: 0.0)
route = Path.new(coordinates: [seattle, portland, sf, la])
puts "  Path as LINESTRING:"
puts "  #{route.to_wkt}"
puts

triangle_path = Path.new(coordinates: [
  LLA.new(lat: 47.0, lng: -122.5, alt: 0),
  LLA.new(lat: 46.0, lng: -121.0, alt: 0),
  LLA.new(lat: 46.0, lng: -123.0, alt: 0)
])
puts "  Path as POLYGON:"
puts "  #{triangle_path.to_wkt(as: :polygon)}"
puts

# ── 4. Areas → POLYGON ─────────────────────────────────────────────

puts "--- 4. Areas → POLYGON ---"
puts

a = LLA.new(lat: 47.7, lng: -122.5, alt: 0)
b = LLA.new(lat: 47.5, lng: -122.1, alt: 0)
c = LLA.new(lat: 47.3, lng: -122.4, alt: 0)
poly = Areas::Polygon.new(boundary: [a, b, c])
puts "  Polygon: #{poly.to_wkt(precision: 1)}"

circle = Areas::Circle.new(centroid: seattle, radius: 10_000)
circle_wkt = circle.to_wkt(segments: 8, precision: 4)
puts "  Circle (8-gon): #{circle_wkt[0..60]}..."

bbox = Areas::BoundingBox.new(
  nw: LLA.new(lat: 48.0, lng: -123.0, alt: 0),
  se: LLA.new(lat: 46.0, lng: -121.0, alt: 0)
)
puts "  BoundingBox: #{bbox.to_wkt(precision: 1)}"
puts

# ── 5. Feature delegates to geometry ───────────────────────────────

puts "--- 5. Feature → delegates to geometry ---"
puts

city = Feature.new(label: "Seattle", geometry: seattle, metadata: { pop: 750_000 })
puts "  Feature('Seattle').to_wkt"
puts "  => #{city.to_wkt}"
puts "  (WKT has no properties; label/metadata are lost)"
puts

# ── 6. SRID / EWKT ─────────────────────────────────────────────────

puts "--- 6. SRID / EWKT ---"
puts

puts "  POINT with SRID:"
puts "  => #{seattle.to_wkt(srid: 4326)}"

puts "  LINESTRING with SRID:"
puts "  => #{seg.to_wkt(srid: 4326)}"

puts "  POLYGON with SRID:"
puts "  => #{poly.to_wkt(srid: 4326, precision: 1)}"
puts

# ── 7. Z-dimension consistency ──────────────────────────────────────

puts "--- 7. Z-dimension consistency ---"
puts

# When ANY point has altitude, ALL points get Z
mixed = Path.new(coordinates: [seattle, space_needle])
puts "  seattle (alt=0) + space_needle (alt=184):"
puts "  => #{mixed.to_wkt}"
puts "  (Both coordinates get Z even though seattle has alt=0)"
puts

no_alt = Path.new(coordinates: [seattle, portland])
puts "  seattle + portland (both alt=0):"
puts "  => #{no_alt.to_wkt}"
puts "  (No Z suffix when all altitudes are zero)"
puts

# ── 8. Parsing WKT ─────────────────────────────────────────────────

puts "--- 8. Parsing WKT ---"
puts

wkt_strings = [
  "POINT(-122.3493 47.6205)",
  "POINT Z(-122.3493 47.6205 184.0)",
  "LINESTRING(-122.3493 47.6205, -122.6784 45.5152)",
  "POLYGON((-122.0 47.0, -121.0 46.0, -123.0 46.0, -122.0 47.0))",
  "MULTIPOINT((-122.35 47.62), (-122.68 45.52))",
  "GEOMETRYCOLLECTION(POINT(-122.35 47.62), LINESTRING(-122.35 47.62, -122.68 45.52))"
]

wkt_strings.each do |wkt|
  result = WKT.parse(wkt)
  type = wkt[/\A\w+/]
  if result.is_a?(Array)
    puts "  #{type} → #{result.map { |r| r.class.name.split('::').last }.join(', ')}"
  else
    puts "  #{type} → #{result.class.name.split('::').last}"
  end
end
puts

# Parsing EWKT with SRID
ewkt = "SRID=4326;POINT(-122.3493 47.6205)"
obj, srid = WKT.parse_with_srid(ewkt)
puts "  EWKT: #{ewkt}"
puts "  → object: #{obj.class.name.split('::').last}(#{obj.to_s(4)}), srid: #{srid}"
puts

# ── 9. Roundtrip ───────────────────────────────────────────────────

puts "--- 9. Roundtrip (export → parse → export) ---"
puts

objects = {
  "POINT"      => seattle,
  "POINT Z"    => space_needle,
  "LINESTRING" => Segment.new(seattle, portland),
  "PATH"       => Path.new(coordinates: [seattle, portland, sf]),
  "POLYGON"    => poly,
  "BBOX"       => bbox,
  "SRID"       => seattle  # will use srid: 4326
}

objects.each do |label, obj|
  srid = label == "SRID" ? 4326 : nil
  original_wkt = obj.to_wkt(srid: srid)

  if srid
    parsed, parsed_srid = WKT.parse_with_srid(original_wkt)
    roundtrip_wkt = parsed.to_wkt(srid: parsed_srid)
  else
    parsed = WKT.parse(original_wkt)
    roundtrip_wkt = parsed.to_wkt
  end

  match = original_wkt == roundtrip_wkt ? "MATCH" : "DIFF"
  puts "  #{label.ljust(12)} #{match}  #{original_wkt[0..55]}#{"..." if original_wkt.length > 55}"
end
puts

# ── 10. File I/O (save & load) ──────────────────────────────────────

puts "--- 10. File I/O (save & load) ---"
puts

output_path = File.join(__dir__, "geodetic_demo.wkt")

save_objects = [seattle, space_needle, seg, poly, bbox]
WKT.save!(output_path, save_objects)
puts "  Saved #{save_objects.length} objects to: #{output_path}"
puts "  File size: #{File.size(output_path)} bytes"
puts

puts "  File contents:"
File.readlines(output_path, chomp: true).each_with_index do |line, i|
  puts "    #{i + 1}: #{line}"
end
puts

loaded = WKT.load(output_path)
puts "  Loaded #{loaded.length} objects:"
loaded.each do |obj|
  puts "    #{obj.class.name.split('::').last}: #{obj.to_wkt(precision: 4)[0..60]}#{"..." if obj.to_wkt(precision: 4).length > 60}"
end
puts

# Verify roundtrip
puts "  Roundtrip check:"
save_objects.zip(loaded).each_with_index do |(orig, back), i|
  match = orig.to_wkt == back.to_wkt ? "MATCH" : "DIFF"
  puts "    object #{i + 1}: #{match}"
end
puts

# Save with SRID
srid_path = File.join(__dir__, "geodetic_demo_srid.wkt")
WKT.save!(srid_path, seattle, portland, srid: 4326, precision: 4)
puts "  Saved with SRID=4326 to: #{srid_path}"
File.readlines(srid_path, chomp: true).each { |line| puts "    #{line}" }
puts

# Clean up the SRID file
File.delete(srid_path) if File.exist?(srid_path)

puts "=== Done ==="
