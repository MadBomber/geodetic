#!/usr/bin/env ruby

# Demonstration of WKB (Well-Known Binary) Serialization
# Shows export, import, roundtrip, SRID/EWKB, Z-dimension handling,
# hex encoding, and file I/O in both binary and hex formats.

require_relative "../lib/geodetic"

include Geodetic

LLA = Coordinate::LLA

puts "=== WKB Serialization Demo ==="
puts
puts "  WKB is the binary counterpart to WKT — the format PostGIS, GEOS,"
puts "  RGeo, and Shapely use for efficient geometry storage and transfer."
puts "  Output is always little-endian (NDR), matching modern GIS conventions."
puts

# ── 1. Coordinate → POINT ──────────────────────────────────────────

puts "--- 1. Coordinate → POINT ---"
puts

seattle = LLA.new(lat: 47.6205, lng: -122.3493, alt: 0.0)
wkb = seattle.to_wkb
puts "  seattle.to_wkb"
puts "  => #{wkb.bytesize} bytes (binary)"
puts

hex = seattle.to_wkb_hex
puts "  seattle.to_wkb_hex"
puts "  => #{hex}"
puts

# Cross-system
utm = seattle.to_utm
puts "  seattle.to_utm.to_wkb_hex"
puts "  => #{utm.to_wkb_hex}"
puts

# Altitude triggers Z type code (Point Z = 1001)
space_needle = LLA.new(lat: 47.6205, lng: -122.3493, alt: 184.0)
puts "  With altitude (Point Z):"
puts "  => #{space_needle.to_wkb_hex}"
puts

# ── 2. Segment → LINESTRING ────────────────────────────────────────

puts "--- 2. Segment → LINESTRING ---"
puts

portland = LLA.new(lat: 45.5152, lng: -122.6784, alt: 0.0)
seg = Geodetic::Segment.new(seattle, portland)
puts "  #{seg.to_wkb.bytesize} bytes: #{seg.to_wkb_hex}"
puts

# ── 3. Path → LINESTRING / POLYGON ────────────────────────────────

puts "--- 3. Path → LINESTRING / POLYGON ---"
puts

sf = LLA.new(lat: 37.7749, lng: -122.4194, alt: 0.0)
route = Path.new(coordinates: [seattle, portland, sf])
puts "  Path (3 cities): #{route.to_wkb.bytesize} bytes"
puts "  hex: #{route.to_wkb_hex[0..60]}..."
puts

triangle = Path.new(coordinates: [
  LLA.new(lat: 47.0, lng: -122.5, alt: 0),
  LLA.new(lat: 46.0, lng: -121.0, alt: 0),
  LLA.new(lat: 46.0, lng: -123.0, alt: 0)
])
poly_wkb = triangle.to_wkb(as: :polygon)
puts "  Path as polygon: #{poly_wkb.bytesize} bytes"
puts

# ── 4. Areas → POLYGON ─────────────────────────────────────────────

puts "--- 4. Areas → POLYGON ---"
puts

a = LLA.new(lat: 47.7, lng: -122.5, alt: 0)
b = LLA.new(lat: 47.5, lng: -122.1, alt: 0)
c = LLA.new(lat: 47.3, lng: -122.4, alt: 0)
poly = Areas::Polygon.new(boundary: [a, b, c])
puts "  Polygon: #{poly.to_wkb.bytesize} bytes"

circle = Areas::Circle.new(centroid: seattle, radius: 10_000)
puts "  Circle (32-gon): #{circle.to_wkb.bytesize} bytes"
puts "  Circle (8-gon):  #{circle.to_wkb(segments: 8).bytesize} bytes"

bbox = Areas::BoundingBox.new(
  nw: LLA.new(lat: 48.0, lng: -123.0, alt: 0),
  se: LLA.new(lat: 46.0, lng: -121.0, alt: 0)
)
puts "  BoundingBox: #{bbox.to_wkb.bytesize} bytes"
puts

# ── 5. Feature delegates ───────────────────────────────────────────

puts "--- 5. Feature → delegates to geometry ---"
puts

city = Feature.new(label: "Seattle", geometry: seattle, metadata: { pop: 750_000 })
puts "  Feature('Seattle').to_wkb_hex"
puts "  => #{city.to_wkb_hex}"
puts "  (WKB has no properties; label/metadata are lost)"
puts

# ── 6. SRID / EWKB ─────────────────────────────────────────────────

puts "--- 6. SRID / EWKB ---"
puts

puts "  POINT with SRID=4326:"
puts "  => #{seattle.to_wkb_hex(srid: 4326)}"

puts "  LINESTRING with SRID=4326:"
puts "  => #{seg.to_wkb_hex(srid: 4326)}"
puts

# ── 7. Z-dimension consistency ──────────────────────────────────────

puts "--- 7. Z-dimension consistency ---"
puts

sf_alt = LLA.new(lat: 37.7749, lng: -122.4194, alt: 100.0)
mixed = Geodetic::Segment.new(seattle, sf_alt)
puts "  seattle (alt=0) + sf (alt=100):"
puts "  Type code: #{mixed.to_wkb[1, 4].unpack1("V")} (1002 = LineString Z)"
puts "  Both points get Z even though seattle has alt=0"
puts

no_alt = Geodetic::Segment.new(seattle, portland)
puts "  seattle + portland (both alt=0):"
puts "  Type code: #{no_alt.to_wkb[1, 4].unpack1("V")} (2 = LineString)"
puts

# ── 8. Parsing WKB ─────────────────────────────────────────────────

puts "--- 8. Parsing WKB ---"
puts

hex_samples = {
  "POINT(1 2)"       => "0101000000000000000000f03f0000000000000040",
  "LINESTRING(1..4)" => "010200000002000000000000000000f03f000000000000004000000000000008400000000000001040",
  "POLYGON"          => "01030000000100000004000000000000000000f03f00000000000000400000000000000840000000000000104000000000000014400000000000001840000000000000f03f0000000000000040",
  "MULTIPOINT"       => "0104000000020000000101000000000000000000f03f0000000000000040010100000000000000000008400000000000001040",
  "GEOM_COLLECTION"  => "0107000000020000000101000000000000000000f03f0000000000000040010200000002000000000000000000f03f000000000000004000000000000008400000000000001040"
}

hex_samples.each do |label, hex|
  result = WKB.parse(hex)
  if result.is_a?(Array)
    puts "  #{label.ljust(18)} → [#{result.map { |r| r.class.name.split('::').last }.join(', ')}]"
  else
    puts "  #{label.ljust(18)} → #{result.class.name.split('::').last}"
  end
end
puts

# Parse EWKB
obj, srid = WKB.parse_with_srid("0101000020e61000008a1f63ee5a965ec08195438b6ccf4740")
puts "  EWKB → #{obj.class.name.split('::').last}(#{obj.to_s(4)}), SRID=#{srid}"
puts

# Parse binary directly
binary = seattle.to_wkb
parsed = WKB.parse(binary)
puts "  Binary parse → #{parsed.class.name.split('::').last}(#{parsed.to_s(4)})"
puts

# ── 9. Roundtrip ───────────────────────────────────────────────────

puts "--- 9. Roundtrip (encode → parse → re-encode) ---"
puts

objects = {
  "POINT"      => seattle,
  "POINT Z"    => space_needle,
  "LINESTRING" => Geodetic::Segment.new(seattle, portland),
  "PATH"       => Path.new(coordinates: [seattle, portland, sf]),
  "POLYGON"    => poly,
  "BBOX"       => bbox,
  "SRID"       => seattle
}

objects.each do |label, obj|
  srid_val = label == "SRID" ? 4326 : nil
  original = obj.to_wkb_hex(srid: srid_val)

  if srid_val
    parsed, parsed_srid = WKB.parse_with_srid(original)
    roundtrip = parsed.to_wkb_hex(srid: parsed_srid)
  else
    parsed = WKB.parse(original)
    roundtrip = parsed.to_wkb_hex
  end

  match = original == roundtrip ? "MATCH" : "DIFF"
  puts "  #{label.ljust(12)} #{match}  #{original.length} hex chars"
end
puts

# ── 10. File I/O ───────────────────────────────────────────────────

puts "--- 10. File I/O ---"
puts

# Binary format
bin_path = File.join(__dir__, "geodetic_demo.wkb")
save_objects = [seattle, space_needle, seg, poly, bbox]
WKB.save!(bin_path, save_objects)
puts "  Binary: saved #{save_objects.length} objects to #{bin_path}"
puts "  File size: #{File.size(bin_path)} bytes"

loaded = WKB.load(bin_path)
puts "  Loaded #{loaded.length} objects:"
loaded.each do |obj|
  puts "    #{obj.class.name.split('::').last} (#{obj.to_wkb.bytesize} bytes)"
end
puts

# Hex format
hex_path = File.join(__dir__, "geodetic_demo_output.wkb.hex")
WKB.save_hex!(hex_path, save_objects)
puts "  Hex: saved #{save_objects.length} objects to #{hex_path}"
puts "  File contents:"
File.readlines(hex_path, chomp: true).each_with_index do |line, i|
  puts "    #{i + 1}: #{line[0..60]}#{"..." if line.length > 60}"
end
puts

hex_loaded = WKB.load_hex(hex_path)
puts "  Loaded #{hex_loaded.length} objects from hex file"
puts

# Roundtrip verification
puts "  File roundtrip check:"
save_objects.zip(loaded).each_with_index do |(orig, back), i|
  match = orig.to_wkb_hex == back.to_wkb_hex ? "MATCH" : "DIFF"
  puts "    object #{i + 1}: #{match}"
end
puts

# Load the fixture files
fixture_bin = File.join(__dir__, "sample_geometries.wkb")
if File.exist?(fixture_bin)
  fixture_objects = WKB.load(fixture_bin)
  puts "  Fixture binary: loaded #{fixture_objects.length} geometries from sample_geometries.wkb"
end

fixture_hex = File.join(__dir__, "sample_geometries.wkb.hex")
if File.exist?(fixture_hex)
  hex_objects = WKB.load_hex(fixture_hex)
  puts "  Fixture hex:    loaded #{hex_objects.length} geometries from sample_geometries.wkb.hex"
end
puts

puts "=== Done ==="
