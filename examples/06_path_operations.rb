#!/usr/bin/env ruby

# Demonstration of the Path class
# Shows construction, navigation, mutation, closest-approach
# calculations, containment testing, Enumerable, subpaths,
# interpolation, bounding boxes, intersection, path-to-path
# and path-to-area operations, and Feature integration.

require_relative "../lib/geodetic"

include Geodetic
LLA      = Coordinate::LLA
Distance = Geodetic::Distance

# ── Define waypoints along a hiking route through Manhattan ────

battery_park   = LLA.new(lat: 40.7033, lng: -74.0170, alt: 0)
wall_street    = LLA.new(lat: 40.7074, lng: -74.0113, alt: 0)
brooklyn_bridge = LLA.new(lat: 40.7061, lng: -73.9969, alt: 0)
city_hall      = LLA.new(lat: 40.7128, lng: -74.0060, alt: 0)
soho           = LLA.new(lat: 40.7233, lng: -73.9985, alt: 0)
union_square   = LLA.new(lat: 40.7359, lng: -73.9911, alt: 0)
empire_state   = LLA.new(lat: 40.7484, lng: -73.9857, alt: 0)
times_square   = LLA.new(lat: 40.7580, lng: -73.9855, alt: 0)
central_park   = LLA.new(lat: 40.7829, lng: -73.9654, alt: 0)

# ── 1. Construction ────────────────────────────────────────────

puts "=== Path Operations Demo ==="
puts
puts "--- 1. Construction ---"

# From an array of coordinates
route = Path.new(coordinates: [
  battery_park, wall_street, brooklyn_bridge,
  city_hall, soho, union_square, empire_state
])

puts <<~CONSTRUCTION
  Route has #{route.size} waypoints
  Start: #{route.first.to_s(4)}
  End:   #{route.last.to_s(4)}
CONSTRUCTION
puts

# ── 2. Navigation ─────────────────────────────────────────────

puts "--- 2. Navigation ---"

puts <<~NAV
  After Wall Street:  #{route.next(wall_street)&.to_s(4) || 'nil'}
  Before SoHo:        #{route.prev(soho)&.to_s(4) || 'nil'}
  Start has no prev:  #{route.prev(battery_park).inspect}
  End has no next:    #{route.next(empire_state).inspect}
NAV
puts

# ── 3. Segments, distances, and bearings ──────────────────────

puts "--- 3. Segment Analysis ---"

route.segments.each_with_index do |(a, b), i|
  dist    = a.distance_to(b)
  bearing = a.bearing_to(b)
  puts "  Segment #{i + 1}: #{dist.to_km} #{bearing.to_compass(points: 8)} (#{bearing.to_s(1)})"
end

puts <<~TOTAL

  Total route distance: #{route.total_distance.to_km}
TOTAL
puts

# ── 4. Mutation: building a path incrementally ────────────────

puts "--- 4. Mutation ---"

# Start empty, build with <<
trail = Path.new
trail << battery_park << wall_street << city_hall
puts "Built with <<:  #{trail.size} waypoints"

# Prepend with >>
trail >> LLA.new(lat: 40.6892, lng: -74.0445, alt: 0)  # Statue of Liberty ferry
puts "After >> prepend: #{trail.size} waypoints, starts at #{trail.first.to_s(4)}"

# Insert between waypoints
trail.insert(brooklyn_bridge, after: wall_street)
puts "After insert:     #{trail.size} waypoints"

# Non-mutating + returns a new path
extended = trail + soho
puts "Original trail:   #{trail.size} waypoints (unchanged)"
puts "Extended trail:   #{extended.size} waypoints (new path)"

# Delete a waypoint
trail.delete(wall_street)
puts "After delete:     #{trail.size} waypoints"
puts

# ── 5. Path + Path, Path - Path ───────────────────────────────

puts "--- 5. Path + Path, Path - Path ---"

downtown = Path.new(coordinates: [battery_park, wall_street, brooklyn_bridge])
uptown   = Path.new(coordinates: [city_hall, soho, union_square])

# Concatenate two paths
combined = downtown + uptown
puts "  Downtown (#{downtown.size}) + Uptown (#{uptown.size}) = Combined (#{combined.size})"

# Subtract a path's coordinates from another
trimmed = combined - uptown
puts "  Combined - Uptown = #{trimmed.size} waypoints: #{trimmed.map { |c| c.to_s(4) }.join(', ')}"
puts

# ── 6. Closest approach ───────────────────────────────────────

puts "--- 6. Closest Approach ---"

# The Flatiron Building is not on our route — where do we pass closest?
flatiron = LLA.new(lat: 40.7411, lng: -73.9897, alt: 0)

closest = route.closest_coordinate_to(flatiron)
dist    = route.distance_to(flatiron)
bearing = route.bearing_to(flatiron)

puts <<~APPROACH
  Target:           Flatiron Building (#{flatiron.to_s(4)})
  Nearest waypoint: #{route.nearest_waypoint(flatiron).to_s(4)}
  Closest approach: #{closest.to_s(4)}
  Distance:         #{dist.to_km}
  Bearing:          #{bearing.to_s(1)} (#{bearing.to_compass(points: 8)})
APPROACH

# Compare waypoint-only vs geometric projection
wp_dist = route.nearest_waypoint(flatiron).distance_to(flatiron)
puts <<~COMPARE
  Waypoint-only distance:  #{wp_dist.to_km}
  Projected distance:      #{dist.to_km}
  Improvement:             #{Distance.new(wp_dist.meters - dist.meters)}
COMPARE
puts

# ── 7. Containment testing ─────────────────────────────────────

puts "--- 7. Containment ---"

# Waypoint check
puts "  Union Square is a waypoint?  #{route.includes?(union_square)}"
puts "  Flatiron is a waypoint?      #{route.includes?(flatiron)}"

# On-segment check (is a point on the path within tolerance?)
midpoint_lat = (union_square.lat + empire_state.lat) / 2.0
midpoint_lng = (union_square.lng + empire_state.lng) / 2.0
on_path = LLA.new(lat: midpoint_lat, lng: midpoint_lng, alt: 0)
off_path = LLA.new(lat: midpoint_lat + 0.01, lng: midpoint_lng, alt: 0)

puts <<~CONTAINMENT
  Midpoint on segment?         #{route.contains?(on_path)}
  Point 1km off path?          #{route.contains?(off_path)}
  Point 1km off (500m tol)?    #{route.contains?(off_path, tolerance: 500)}
CONTAINMENT
puts

# ── 8. Enumerable ──────────────────────────────────────────────

puts "--- 8. Enumerable ---"

# Path includes Enumerable — use map, select, any?, etc.
latitudes = route.map { |c| c.lat.round(4) }
puts "  Latitudes: #{latitudes.join(', ')}"

northernmost = route.max_by { |c| c.lat }
puts "  Northernmost waypoint: #{northernmost.to_s(4)}"

above_40_72 = route.select { |c| c.lat > 40.72 }
puts "  Waypoints above 40.72°N: #{above_40_72.size}"
puts

# ── 9. Equality ────────────────────────────────────────────────

puts "--- 9. Equality ---"

p1 = Path.new(coordinates: [battery_park, wall_street, city_hall])
p2 = Path.new(coordinates: [battery_park, wall_street, city_hall])
p3 = p1.reverse

puts <<~EQUALITY
  Same coordinates, same order:      #{p1 == p2}
  Same coordinates, reversed order:  #{p1 == p3}
  Path vs reversed path:             #{p1 == p1.reverse}
EQUALITY
puts

# ── 10. Subpath (between) ─────────────────────────────────────

puts "--- 10. Subpath (between) ---"

sub = route.between(wall_street, union_square)
puts <<~SUBPATH
  Full route:  #{route.size} waypoints, #{route.total_distance.to_km}
  Subpath:     #{sub.size} waypoints (Wall Street → Union Square)
  Sub-distance: #{sub.total_distance.to_km}
SUBPATH
puts

# ── 11. Split ──────────────────────────────────────────────────

puts "--- 11. Split ---"

left, right = route.split_at(city_hall)
puts <<~SPLIT
  Split at City Hall:
  Left half:  #{left.size} waypoints (#{left.first.to_s(4)} → #{left.last.to_s(4)})
  Right half: #{right.size} waypoints (#{right.first.to_s(4)} → #{right.last.to_s(4)})
  Shared point: #{left.last == right.first}
SPLIT
puts

# ── 12. Interpolation (at_distance) ───────────────────────────

puts "--- 12. Interpolation ---"

total = route.total_distance
quarter   = route.at_distance(Distance.new(total.meters * 0.25))
halfway   = route.at_distance(Distance.new(total.meters * 0.50))
three_qtr = route.at_distance(Distance.new(total.meters * 0.75))

puts <<~INTERP
  Total route: #{total.to_km}
  At 25%:  #{quarter.to_s(4)}
  At 50%:  #{halfway.to_s(4)}
  At 75%:  #{three_qtr.to_s(4)}
INTERP
puts

# ── 13. Bounding Box ──────────────────────────────────────────

puts "--- 13. Bounding Box ---"

bbox = route.bounds
puts <<~BOUNDS
  NW corner: #{bbox.nw.to_s(4)}
  SE corner: #{bbox.se.to_s(4)}
  Centroid:  #{bbox.centroid.to_s(4)}
  Flatiron inside bounds?  #{bbox.includes?(flatiron)}
  Central Park in bounds?  #{bbox.includes?(central_park)}
BOUNDS
puts

# ── 14. To Polygon ────────────────────────────────────────────

puts "--- 14. To Polygon ---"

# A triangular path can be closed into a polygon
triangle = Path.new(coordinates: [battery_park, brooklyn_bridge, empire_state])
poly = triangle.to_polygon
puts <<~POLYGON
  Triangle path: #{triangle.size} waypoints
  Polygon boundary: #{poly.boundary.size} points (closed)
  City Hall inside triangle?  #{poly.includes?(city_hall)}
  Central Park inside?        #{poly.includes?(central_park)}
POLYGON
puts

# ── 15. Intersection ──────────────────────────────────────────

puts "--- 15. Path Intersection ---"

# A crosstown path that crosses our uptown route
crosstown_west = LLA.new(lat: 40.7350, lng: -74.0050, alt: 0)
crosstown_east = LLA.new(lat: 40.7350, lng: -73.9750, alt: 0)
crosstown = Path.new(coordinates: [crosstown_west, crosstown_east])

# A path that runs parallel, never crossing
parallel_west = LLA.new(lat: 40.7000, lng: -74.0200, alt: 0)
parallel_east = LLA.new(lat: 40.7000, lng: -73.9800, alt: 0)
parallel = Path.new(coordinates: [parallel_west, parallel_east])

puts <<~INTERSECT
  Route intersects crosstown? #{route.intersects?(crosstown)}
  Route intersects parallel?  #{route.intersects?(parallel)}
INTERSECT
puts

# ── 16. Path-to-Path closest points ──────────────────────────

puts "--- 16. Path-to-Path Closest Points ---"

west_side = Path.new(coordinates: [
  LLA.new(lat: 40.7100, lng: -74.0150, alt: 0),
  LLA.new(lat: 40.7500, lng: -74.0050, alt: 0)
])

result = route.closest_points_to(west_side)
puts <<~P2P
  Route closest point:     #{result[:path_point].to_s(4)}
  West Side closest point: #{result[:area_point].to_s(4)}
  Distance between:        #{result[:distance].to_km}
P2P
puts

# ── 17. Path-to-Area closest points ──────────────────────────

puts "--- 17. Path-to-Area Closest Points ---"

# Distance from route to a circular area around Central Park
park_zone = Areas::Circle.new(centroid: central_park, radius: 500)
circle_result = route.closest_points_to(park_zone)

puts <<~AREA
  Central Park zone (500m radius):
  Path closest point:  #{circle_result[:path_point].to_s(4)}
  Area closest point:  #{circle_result[:area_point].to_s(4)}
  Distance to zone:    #{circle_result[:distance].to_km}
AREA

# Distance from route to a polygon
park_poly = Areas::Polygon.new(boundary: [
  LLA.new(lat: 40.800, lng: -73.958, alt: 0),
  LLA.new(lat: 40.800, lng: -73.949, alt: 0),
  LLA.new(lat: 40.764, lng: -73.973, alt: 0),
  LLA.new(lat: 40.764, lng: -73.981, alt: 0)
])

poly_result = route.closest_points_to(park_poly)
puts <<~POLY
  Central Park polygon:
  Path closest point:  #{poly_result[:path_point].to_s(4)}
  Area closest point:  #{poly_result[:area_point].to_s(4)}
  Distance to polygon: #{poly_result[:distance].to_km}
POLY
puts

# ── 18. Reverse ────────────────────────────────────────────────

puts "--- 18. Reverse ---"

return_route = route.reverse
puts <<~REVERSE
  Original: #{route.first.to_s(4)} -> #{route.last.to_s(4)}
  Reversed: #{return_route.first.to_s(4)} -> #{return_route.last.to_s(4)}
  Same distance: #{route.total_distance.to_km} vs #{return_route.total_distance.to_km}
REVERSE
puts

# ── 19. Feature integration ───────────────────────────────────

puts "--- 19. Feature Integration ---"

hiking_route = Feature.new(
  label:    "Manhattan Walking Tour",
  geometry: route,
  metadata: { type: "walking", difficulty: "easy" }
)

statue = Feature.new(
  label:    "Statue of Liberty",
  geometry: LLA.new(lat: 40.6892, lng: -74.0445, alt: 0),
  metadata: { category: "monument" }
)

puts <<~FEATURE
  Route:    #{hiking_route.label} (#{hiking_route.metadata[:type]})
  Closest approach to #{statue.label}: #{hiking_route.distance_to(statue).to_km}
  Bearing to #{statue.label}: #{hiking_route.bearing_to(statue).to_s(1)}
FEATURE
