#!/usr/bin/env ruby

# Demonstration of bearing calculations and the Bearing class
# Shows great-circle bearings, compass directions, elevation angles,
# cross-system bearings, and Bearing class features.

require_relative "../lib/geodetic"

Bearing = Geodetic::Bearing

# ── Notable locations ────────────────────────────────────────────

seattle  = GCS::LLA.new(lat: 47.6205, lng: -122.3493, alt: 0.0)
portland = GCS::LLA.new(lat: 45.5152, lng: -122.6784, alt: 0.0)
sf       = GCS::LLA.new(lat: 37.7749, lng: -122.4194, alt: 0.0)
nyc      = GCS::LLA.new(lat: 40.7128, lng: -74.0060,  alt: 0.0)
london   = GCS::LLA.new(lat: 51.5074, lng: -0.1278,   alt: 0.0)

puts "=== Bearing Calculations Demo ==="
puts

# ── Basic bearing_to ──────────────────────────────────────────────

puts "--- Great-Circle Bearings (Forward Azimuth) ---"
puts

b = seattle.bearing_to(portland)
puts <<~HEREDOC
  Seattle -> Portland:
    #{b.to_s}
    #{b.to_compass(points: 16)} (16-point compass)
    #{b.to_radians.round(4)} radians
    Back azimuth: #{b.reverse.to_s}
HEREDOC

b = seattle.bearing_to(nyc)
puts "Seattle -> NYC:      #{b.to_s}  (#{b.to_compass(points: 8)})"

b = seattle.bearing_to(london)
puts "Seattle -> London:   #{b.to_s}  (#{b.to_compass(points: 8)})"

b = seattle.bearing_to(sf)
puts "Seattle -> SF:       #{b.to_s}  (#{b.to_compass(points: 8)})"
puts

# ── Compass directions at different resolutions ──────────────────

puts "--- Compass Resolution Comparison ---"
puts

targets = { "Portland" => portland, "SF" => sf, "NYC" => nyc, "London" => london }

puts "  %-10s %12s  %4s  %4s  %4s" % ["Target", "Degrees", "4pt", "8pt", "16pt"]
puts "  " + "-" * 42

targets.each do |name, target|
  b = seattle.bearing_to(target)
  puts "  %-10s %12s  %4s  %4s  %4s" % [
    name, b.to_s, b.to_compass(points: 4),
    b.to_compass(points: 8), b.to_compass(points: 16)
  ]
end
puts

# ── Elevation angles ─────────────────────────────────────────────

puts "--- Elevation Angles ---"
puts

ground  = GCS::LLA.new(lat: 47.6205, lng: -122.3493, alt: 0.0)
hilltop = GCS::LLA.new(lat: 47.6205, lng: -122.3493, alt: 5000.0)
plane   = GCS::LLA.new(lat: 47.6300, lng: -122.3400, alt: 10000.0)
nearby  = GCS::LLA.new(lat: 47.6210, lng: -122.3490, alt: 100.0)

puts "  From ground (0m) to directly above (5000m):"
puts "    Elevation: #{ground.elevation_to(hilltop).round(2)}°  (nearly straight up)"
puts
puts "  From ground to airplane (10km alt, ~1km away):"
puts "    Elevation: #{ground.elevation_to(plane).round(2)}°"
puts "    Bearing:   #{ground.bearing_to(plane).to_s}"
puts
puts "  From ground to nearby hilltop (100m alt, ~60m away):"
puts "    Elevation: #{ground.elevation_to(nearby).round(2)}°"
puts "    Bearing:   #{ground.bearing_to(nearby).to_s}"
puts

# ── Chain bearings ────────────────────────────────────────────────

puts "--- Chain Bearings (Consecutive Legs) ---"
puts "Route: Seattle -> Portland -> SF -> NYC -> London"
puts

bearings = GCS.bearing_between(seattle, portland, sf, nyc, london)
legs = [
  "Seattle -> Portland",
  "Portland -> SF",
  "SF -> NYC",
  "NYC -> London"
]

legs.each_with_index do |label, i|
  b = bearings[i]
  puts "  %-22s %12s  %-3s  (reverse: %s)" % [
    label, b.to_s, b.to_compass(points: 8), b.reverse.to_s
  ]
end
puts

# ── Cross-system bearings ────────────────────────────────────────

puts "--- Cross-System Bearings ---"
puts

utm_seattle   = seattle.to_utm
mgrs_portland = GCS::MGRS.from_lla(portland)
wm_sf         = GCS::WebMercator.from_lla(sf)

b = utm_seattle.bearing_to(mgrs_portland)
puts "  UTM(Seattle) -> MGRS(Portland):      #{b.to_s}  (#{b.to_compass})"

b = mgrs_portland.bearing_to(wm_sf)
puts "  MGRS(Portland) -> WebMercator(SF):   #{b.to_s}  (#{b.to_compass})"

b = wm_sf.bearing_to(utm_seattle)
puts "  WebMercator(SF) -> UTM(Seattle):     #{b.to_s}  (#{b.to_compass})"
puts

# ── Local bearings (ENU/NED) ─────────────────────────────────────

puts "--- Local Tangent Plane Bearings (ENU / NED) ---"
puts

enu_origin = GCS::ENU.new(e: 0.0, n: 0.0, u: 0.0)
enu_ne     = GCS::ENU.new(e: 100.0, n: 100.0, u: 0.0)
enu_south  = GCS::ENU.new(e: 0.0, n: -200.0, u: 50.0)

puts "  ENU local_bearing_to:"
puts "    Origin -> NE point (100,100):  #{enu_origin.local_bearing_to(enu_ne).round(2)}°"
puts "    Origin -> South point (0,-200): #{enu_origin.local_bearing_to(enu_south).round(2)}°"
puts

ned_origin = GCS::NED.new(n: 0.0, e: 0.0, d: 0.0)
ned_above  = GCS::NED.new(n: 100.0, e: 0.0, d: -100.0)
ned_below  = GCS::NED.new(n: 100.0, e: 0.0, d: 100.0)

puts "  NED local_bearing_to / local_elevation_angle_to:"
puts "    Origin -> N+Up:    bearing #{ned_origin.local_bearing_to(ned_above).round(2)}°, elevation #{ned_origin.local_elevation_angle_to(ned_above).round(2)}°"
puts "    Origin -> N+Down:  bearing #{ned_origin.local_bearing_to(ned_below).round(2)}°, elevation #{ned_origin.local_elevation_angle_to(ned_below).round(2)}°"
puts

# ── Bearing class features ───────────────────────────────────────

puts "=== Bearing Class Features ==="
puts

# ── Construction and normalization ────────────────────────────────

puts "--- Construction (auto-normalizes to 0-360) ---"
puts

[0, 90, -90, 450, 720, -180].each do |deg|
  puts "  Bearing.new(%-4d) => %s" % [deg, Bearing.new(deg).to_s]
end
puts

# ── Reverse (back azimuth) ───────────────────────────────────────

puts "--- Reverse (Back Azimuth) ---"
puts

[0, 45, 90, 180, 270, 315].each do |deg|
  b = Bearing.new(deg)
  puts "  %-10s reverse => %s" % [b.to_s, b.reverse.to_s]
end
puts

# ── Arithmetic ───────────────────────────────────────────────────

puts "--- Arithmetic ---"
puts

b = Bearing.new(350)
puts "  b = #{b.to_s}"
puts "  b + 20 = #{(b + 20).to_s}  (wraps past 360)"
puts "  b - 10 = #{(b - 10).to_s}"
puts

b1 = Bearing.new(90)
b2 = Bearing.new(45)
puts "  Bearing(90) - Bearing(45) = #{(b1 - b2)}  (Float, angular difference)"
puts "  Bearing(45) - Bearing(90) = #{(b2 - b1)}  (negative difference)"
puts

# ── Comparison ───────────────────────────────────────────────────

puts "--- Comparison ---"
puts

puts "  Bearing(90) == Bearing(90)?   #{Bearing.new(90) == Bearing.new(90)}"
puts "  Bearing(90) == Bearing(450)?  #{Bearing.new(90) == Bearing.new(450)}"
puts "  Bearing(45) < Bearing(90)?    #{Bearing.new(45) < Bearing.new(90)}"
puts "  Bearing(270) > 180?           #{Bearing.new(270) > 180}"
puts

# ── Combined distance and bearing ────────────────────────────────

puts "=== Combined Distance + Bearing ==="
puts

puts "  %-22s %10s  %12s  %6s" % ["Leg", "Distance", "Bearing", "Dir"]
puts "  " + "-" * 54

route = [
  ["Seattle", seattle],
  ["Portland", portland],
  ["SF", sf],
  ["NYC", nyc],
  ["London", london]
]

route.each_cons(2) do |(name_a, coord_a), (name_b, coord_b)|
  d = coord_a.distance_to(coord_b)
  b = coord_a.bearing_to(coord_b)
  label = "#{name_a} -> #{name_b}"
  km_str = "%.1f km" % d.to_km.to_f
  puts "  %-22s %10s  %12s  %6s" % [label, km_str, b.to_s, b.to_compass(points: 8)]
end
puts

puts "=== Done ==="
