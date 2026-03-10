#!/usr/bin/env ruby

# Demonstration of GeoJSON Export
# Shows how to build a GeoJSON FeatureCollection from mixed Geodetic objects
# and save it to a file that can be opened in any GeoJSON viewer.

require_relative "../lib/geodetic"
require "tmpdir"

include Geodetic

LLA      = Coordinate::LLA
Distance = Geodetic::Distance
Vector   = Geodetic::Vector

puts "=== GeoJSON Export Demo ==="
puts

# ── 1. Individual to_geojson on each geometry type ─────────────────

puts "--- 1. Coordinate → GeoJSON Point ---"
puts

seattle = LLA.new(lat: 47.6205, lng: -122.3493, alt: 0.0)
puts "  seattle.to_geojson"
puts "  => #{seattle.to_geojson}"
puts

# Works from any coordinate system — converts through LLA
utm = seattle.to_utm
puts "  seattle.to_utm.to_geojson"
puts "  => #{utm.to_geojson}"
puts

# Altitude included when non-zero
space_needle = LLA.new(lat: 47.6205, lng: -122.3493, alt: 184.0)
puts "  With altitude: #{space_needle.to_geojson}"
puts

# ── 2. Segment → LineString ───────────────────────────────────────

puts "--- 2. Segment → GeoJSON LineString ---"
puts

portland = LLA.new(lat: 45.5152, lng: -122.6784, alt: 0.0)
seg = Segment.new(seattle, portland)
puts "  Segment(seattle → portland).to_geojson"
puts "  => #{seg.to_geojson}"
puts

# ── 3. Path → LineString or Polygon ───────────────────────────────

puts "--- 3. Path → GeoJSON LineString ---"
puts

sf = LLA.new(lat: 37.7749, lng: -122.4194, alt: 0.0)
la = LLA.new(lat: 34.0522, lng: -118.2437, alt: 0.0)
route = Path.new(coordinates: [seattle, portland, sf, la])

geojson = route.to_geojson
puts "  Path(4 waypoints).to_geojson"
puts "  type: #{geojson["type"]}, points: #{geojson["coordinates"].length}"
puts

# Path can also export as a polygon
triangle_path = Path.new(coordinates: [
  LLA.new(lat: 47.0, lng: -122.5, alt: 0),
  LLA.new(lat: 46.0, lng: -121.0, alt: 0),
  LLA.new(lat: 46.0, lng: -123.0, alt: 0)
])
poly_geojson = triangle_path.to_geojson(as: :polygon)
puts "  Path(3 points).to_geojson(as: :polygon)"
puts "  type: #{poly_geojson["type"]}, ring closed: #{poly_geojson["coordinates"][0].first == poly_geojson["coordinates"][0].last}"
puts

# ── 4. Areas → Polygon ────────────────────────────────────────────

puts "--- 4. Areas → GeoJSON Polygon ---"
puts

# Polygon
a = LLA.new(lat: 47.7, lng: -122.5, alt: 0)
b = LLA.new(lat: 47.5, lng: -122.1, alt: 0)
c = LLA.new(lat: 47.3, lng: -122.4, alt: 0)
poly = Areas::Polygon.new(boundary: [a, b, c])
puts "  Polygon(3 vertices).to_geojson"
puts "  type: #{poly.to_geojson["type"]}"

# Circle (approximated as 32-gon)
circle = Areas::Circle.new(centroid: seattle, radius: 10_000)
circle_gj = circle.to_geojson
ring_size = circle_gj["coordinates"][0].length
puts "  Circle(10km).to_geojson → #{ring_size - 1}-gon (#{ring_size} points including closing)"

# Circle with custom resolution
circle_gj_64 = circle.to_geojson(segments: 64)
puts "  Circle(10km).to_geojson(segments: 64) → #{circle_gj_64["coordinates"][0].length - 1}-gon"

# BoundingBox
bbox = Areas::BoundingBox.new(
  nw: LLA.new(lat: 48.0, lng: -123.0, alt: 0),
  se: LLA.new(lat: 46.0, lng: -121.0, alt: 0)
)
puts "  BoundingBox.to_geojson → #{bbox.to_geojson["coordinates"][0].length} points (4 corners + closing)"
puts

# ── 5. Feature → GeoJSON Feature with properties ──────────────────

puts "--- 5. Feature → GeoJSON Feature ---"
puts

city = Feature.new(
  label: "Seattle",
  geometry: seattle,
  metadata: { state: "WA", population: 750_000, timezone: "PST" }
)
feature_gj = city.to_geojson
puts "  Feature('Seattle').to_geojson"
puts "  type:       #{feature_gj["type"]}"
puts "  geometry:   #{feature_gj["geometry"]["type"]}"
puts "  properties: #{feature_gj["properties"]}"
puts

# Feature wrapping a polygon
park = Feature.new(
  label: "Triangle Park",
  geometry: poly,
  metadata: { type: "park", area_sqkm: 12.5 }
)
park_gj = park.to_geojson
puts "  Feature('Triangle Park', polygon).to_geojson"
puts "  geometry:   #{park_gj["geometry"]["type"]}"
puts "  properties: #{park_gj["properties"]}"
puts

# ── 6. Building a FeatureCollection ───────────────────────────────

puts "--- 6. GeoJSON FeatureCollection ---"
puts

gj = GeoJSON.new
puts "  gj = GeoJSON.new"
puts "  gj.size: #{gj.size}, empty? #{gj.empty?}"
puts

# Add cities as features
cities = {
  "Seattle"  => LLA.new(lat: 47.6205, lng: -122.3493, alt: 0),
  "Portland" => LLA.new(lat: 45.5152, lng: -122.6784, alt: 0),
  "San Francisco" => LLA.new(lat: 37.7749, lng: -122.4194, alt: 0),
  "Los Angeles" => LLA.new(lat: 34.0522, lng: -118.2437, alt: 0),
  "New York" => LLA.new(lat: 40.7128, lng: -74.0060, alt: 0)
}

cities.each do |name, coord|
  gj << Feature.new(label: name, geometry: coord, metadata: { type: "city" })
end
puts "  Added #{cities.size} cities as Features"

# Add a route as a path
west_coast = Path.new(coordinates: cities.values_at("Seattle", "Portland", "San Francisco", "Los Angeles"))
gj << Feature.new(label: "West Coast Route", geometry: west_coast, metadata: { mode: "driving" })
puts "  Added West Coast route (Path with 4 waypoints)"

# Add an array of raw coordinates (auto-wrapped as Features)
landmarks = [
  LLA.new(lat: 48.8566, lng: 2.3522, alt: 0),   # Paris
  LLA.new(lat: 51.5074, lng: -0.1278, alt: 0)    # London
]
gj << landmarks
puts "  Added 2 landmarks via << [array]"

# Add a bounding box and a circle
gj << Feature.new(label: "Pacific NW", geometry: bbox, metadata: { region: true })
gj << Feature.new(label: "Seattle Metro", geometry: circle, metadata: { radius_km: 10 })
puts "  Added bounding box and circle"

puts
puts "  Total items: #{gj.size}"
puts "  to_s: #{gj}"
puts

# ── 7. Initialize with objects ────────────────────────────────────

puts "--- 7. Initialize with objects ---"
puts

gj2 = GeoJSON.new(seattle, portland, sf)
puts "  GeoJSON.new(seattle, portland, sf) → size: #{gj2.size}"

gj3 = GeoJSON.new([seattle, portland])
puts "  GeoJSON.new([seattle, portland]) → size: #{gj3.size}"
puts

# ── 8. Delete and Clear ───────────────────────────────────────────

puts "--- 8. Delete and Clear ---"
puts

gj4 = GeoJSON.new(seattle, portland, sf)
puts "  Before delete: #{gj4.size}"
gj4.delete(portland)
puts "  After delete(portland): #{gj4.size}"
gj4.clear
puts "  After clear: #{gj4.size}, empty? #{gj4.empty?}"
puts

# ── 9. Enumerable ─────────────────────────────────────────────────

puts "--- 9. Enumerable ---"
puts

gj5 = GeoJSON.new(seattle, portland, sf)
puts "  Iterating:"
gj5.each { |obj| puts "    #{obj.class}: #{obj.to_s(4)}" }
puts "  map to classes: #{gj5.map(&:class).map(&:name)}"
puts

# ── 10. Export to Hash, JSON, and File ─────────────────────────────

puts "--- 10. Export ---"
puts

# to_h
h = gj.to_h
puts "  to_h:"
puts "    type: #{h["type"]}"
puts "    features: #{h["features"].length}"
puts "    geometry types: #{h["features"].map { |f| f["geometry"]["type"] }.tally}"
puts

# to_json (compact)
json = gj.to_json
puts "  to_json (compact): #{json.length} bytes"

# to_json (pretty)
pretty = gj.to_json(pretty: true)
puts "  to_json(pretty: true): #{pretty.length} bytes, #{pretty.lines.count} lines"
puts

# save to file
output_path = File.join(Dir.tmpdir, "geodetic_demo.geojson")
gj.save(output_path, pretty: true)
puts "  Saved to: #{output_path}"
puts "  File size: #{File.size(output_path)} bytes"
puts

# Show first few lines of the pretty-printed output
puts "  Preview (first 15 lines):"
pretty.lines.first(15).each { |line| puts "    #{line}" }
puts "    ..."
puts

puts "=== Done ==="
puts
puts "Open #{output_path} in https://geojson.io to visualize the data."
