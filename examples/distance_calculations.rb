#!/usr/bin/env ruby

# Demonstration of distance calculations and the Distance class
# Shows great-circle distances, straight-line distances, unit conversions,
# and arithmetic with the Distance class.

require_relative "../lib/geodetic"

Distance = Geodetic::Distance

# ── Notable locations ────────────────────────────────────────────

seattle  = GCS::LLA.new(lat: 47.6205, lng: -122.3493, alt: 0.0)
portland = GCS::LLA.new(lat: 45.5152, lng: -122.6784, alt: 0.0)
sf       = GCS::LLA.new(lat: 37.7749, lng: -122.4194, alt: 0.0)
nyc      = GCS::LLA.new(lat: 40.7128, lng: -74.0060,  alt: 0.0)
london   = GCS::LLA.new(lat: 51.5074, lng: -0.1278,   alt: 0.0)

puts "=== Distance Calculations Demo ==="
puts

# ── Basic distance_to ────────────────────────────────────────────

puts "--- Great-Circle Distances (Vincenty) ---"
puts

d = seattle.distance_to(portland)
puts "Seattle -> Portland:"
puts "  #{d.meters.round(2)} meters"
puts "  #{d.to_km.to_f.round(2)} km"
puts "  #{d.to_mi.to_f.round(2)} miles"
puts "  #{d.to_nmi.to_f.round(2)} nautical miles"
puts

d = seattle.distance_to(nyc)
puts "Seattle -> New York: #{d.to_mi.to_s}"
puts

d = seattle.distance_to(london)
puts "Seattle -> London:   #{d.to_km.to_s}"
puts

# ── Radial distances (one-to-many) ──────────────────────────────

puts "--- Radial Distances from Seattle ---"
puts

distances = seattle.distance_to(portland, sf, nyc, london)
labels    = %w[Portland SF NYC London]

distances.each_with_index do |dist, i|
  puts "  -> %-10s %10.1f km  (%7.1f mi)" % [labels[i], dist.to_km.to_f, dist.to_mi.to_f]
end
puts

# ── Chain distances (consecutive pairs) ─────────────────────────

puts "--- Chain Distances (consecutive legs) ---"
puts "Route: Seattle -> Portland -> SF -> NYC"
puts

legs = GCS.distance_between(seattle, portland, sf, nyc)
leg_labels = ["Seattle -> Portland", "Portland -> SF", "SF -> NYC"]

total = Distance.new(0)
legs.each_with_index do |leg, i|
  total = total + leg
  puts "  %-20s %8.1f km" % [leg_labels[i], leg.to_km.to_f]
end
puts "  %-20s %8.1f km" % ["Total", total.to_km.to_f]
puts

# ── Straight-line vs great-circle ───────────────────────────────

puts "--- Straight-Line vs Great-Circle ---"
puts

gc = seattle.distance_to(london)
sl = seattle.straight_line_distance_to(london)

puts "Seattle -> London:"
puts "  Great-circle:  #{gc.to_km.to_f.round(1)} km"
puts "  Straight-line: #{sl.to_km.to_f.round(1)} km (through the Earth)"
puts "  Difference:    #{(gc - sl).to_km.to_f.round(1)} km"
puts

# ── Cross-system distances ──────────────────────────────────────

puts "--- Cross-System Distances ---"
puts

utm_seattle  = seattle.to_utm
mgrs_portland = GCS::MGRS.from_lla(portland)

d = utm_seattle.distance_to(mgrs_portland)
puts "UTM(Seattle) -> MGRS(Portland): #{d.to_km.to_f.round(2)} km"

wm_sf = GCS::WebMercator.from_lla(sf)
d = wm_sf.distance_to(utm_seattle)
puts "WebMercator(SF) -> UTM(Seattle): #{d.to_mi.to_f.round(2)} mi"
puts

# ── Distance class construction ─────────────────────────────────

puts "=== Distance Class Features ==="
puts

puts "--- Construction from different units ---"
puts

examples = [
  Distance.new(1000),
  Distance.km(5),
  Distance.mi(3),
  Distance.ft(5280),
  Distance.nmi(1),
]

examples.each do |d|
  puts "  %-40s => %10.3f meters" % [d.inspect, d.meters]
end
puts

# ── Unit conversions ────────────────────────────────────────────

puts "--- Unit Conversions ---"
puts

d = Distance.new(1609.344)
puts "1609.344 meters is:"
puts "  #{d.to_km.to_f.round(6)} km"
puts "  #{d.to_mi.to_f.round(6)} miles"
puts "  #{d.to_ft.to_f.round(2)} feet"
puts "  #{d.to_yd.to_f.round(2)} yards"
puts "  #{d.to_nmi.to_f.round(6)} nautical miles"
puts "  #{d.to_cm.to_f.round(2)} cm"
puts "  #{d.to_mm.to_f.round(2)} mm"
puts

# ── Display formatting ──────────────────────────────────────────

puts "--- Display Formatting ---"
puts

d = Distance.km(42.195) # marathon distance
puts "Marathon distance:"
puts "  to_s:     #{d.to_s}"
puts "  to_f:     #{d.to_f}"
puts "  to_i:     #{d.to_i}"
puts "  inspect:  #{d.inspect}"
puts "  in miles: #{d.to_mi.to_s}"
puts "  in feet:  #{d.to_ft.to_s}"
puts

# ── Arithmetic ──────────────────────────────────────────────────

puts "--- Arithmetic ---"
puts

d1 = Distance.km(5)
d2 = Distance.mi(3)

puts "d1 = #{d1.inspect}"
puts "d2 = #{d2.inspect}"
puts

sum = d1 + d2
puts "d1 + d2  = #{sum.to_km.to_f.round(3)} km  (#{sum.meters.round(3)} m)"

diff = d1 - d2
puts "d1 - d2  = #{diff.to_km.to_f.round(3)} km  (#{diff.meters.round(3)} m)"

scaled = d1 * 3
puts "d1 * 3   = #{scaled.to_km.to_f.round(3)} km"

halved = d2 / 2
puts "d2 / 2   = #{halved.to_mi.to_f.round(3)} mi"

ratio = d1 / d2
puts "d1 / d2  = #{ratio.round(6)} (ratio)"
puts

# Numeric constants use the display unit
puts "--- Numeric Constants in Display Unit ---"
puts

d = Distance.new(5000).to_km  # 5 km
puts "d = #{d.inspect}"
puts "d + 3 (adds 3 km) = #{(d + 3).to_km.to_f} km"
puts "d - 2 (subs 2 km) = #{(d - 2).to_km.to_f} km"
puts "d > 4 (4 km)?       #{d > 4}"
puts "d < 4 (4 km)?       #{d < 4}"
puts

# ── Comparison ──────────────────────────────────────────────────

puts "--- Comparison (unit-independent) ---"
puts

a = Distance.km(1)
b = Distance.new(1000)
c = Distance.mi(1)

puts "1 km == 1000 m?  #{a == b}"
puts "1 mi > 1 km?     #{c > a}"
puts "1 km < 1 mi?     #{a < c}"
puts

# ── Coerce (Numeric * Distance) ────────────────────────────────

d = Distance.km(10)
result = 3 * d
puts "3 * #{d.to_s} = #{result} (via coerce)"
puts

puts "=== Done ==="
