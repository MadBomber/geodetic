#!/usr/bin/env ruby

# Demonstration of Geodetic Arithmetic
# Shows how operators compose geometry from coordinates, vectors, and distances:
#   +  builds geometry (Segments, Paths, Circles)
#   *  translates geometry (Coordinates, Segments, Paths, Circles, Polygons)
# Also demonstrates the Vector class and Path#to_corridor.

require_relative "../lib/geodetic"

include Geodetic

LLA      = Coordinate::LLA
Distance = Geodetic::Distance
Vector   = Geodetic::Vector
Bearing  = Geodetic::Bearing

# ── Notable locations ────────────────────────────────────────────

seattle  = LLA.new(lat: 47.6205, lng: -122.3493, alt: 0.0)
portland = LLA.new(lat: 45.5152, lng: -122.6784, alt: 0.0)
sf       = LLA.new(lat: 37.7749, lng: -122.4194, alt: 0.0)
la       = LLA.new(lat: 34.0522, lng: -118.2437, alt: 0.0)
nyc      = LLA.new(lat: 40.7128, lng: -74.0060,  alt: 0.0)

puts "=== Geodetic Arithmetic Demo ==="
puts

# ── 1. Building Segments with + ──────────────────────────────────

puts "--- 1. Coordinate + Coordinate → Segment ---"
puts

seg = seattle + portland
puts <<~SEG
  seattle + portland
  Type:    #{seg.class}
  Start:   #{seg.start_point.to_s(4)}
  End:     #{seg.end_point.to_s(4)}
  Length:  #{seg.length.to_km.to_s(1)}
  Bearing: #{seg.bearing}
SEG

# Cross-system: UTM + LLA works
utm = portland.to_utm
cross_seg = seattle + utm
puts <<~CROSS
  Cross-system: seattle (LLA) + portland (UTM)
  Length: #{cross_seg.length.to_km.to_s(1)}
CROSS
puts

# ── 2. Building Paths with + ────────────────────────────────────

puts "--- 2. Chaining + → Path ---"
puts

path = seattle + portland + sf + la
puts <<~PATH
  seattle + portland + sf + la
  Type:           #{path.class}
  Waypoints:      #{path.size}
  First:          #{path.first.to_s(4)}
  Last:           #{path.last.to_s(4)}
  Total distance: #{path.total_distance.to_km.to_s(1)}
PATH

# Coordinate + Segment → Path
seg = portland + sf
path2 = seattle + seg
puts <<~CSEG
  seattle + (portland + sf)
  Waypoints: #{path2.size}  (seattle → portland → sf)
CSEG

# Segment + Segment → Path
seg1 = seattle + portland
seg2 = sf + la
path3 = seg1 + seg2
puts <<~SSEG
  (seattle + portland) + (sf + la)
  Waypoints: #{path3.size}  (seattle → portland → sf → la)
SSEG
puts

# ── 3. Coordinate + Distance → Circle ───────────────────────────

puts "--- 3. Coordinate + Distance → Circle ---"
puts

radius = Distance.km(50)
circle = seattle + radius
puts <<~CIRC
  seattle + Distance.km(50)
  Type:     #{circle.class}
  Centroid: #{circle.centroid.to_s(4)}
  Radius:   #{circle.radius} m

  Portland inside 50km circle? #{circle.includes?(portland)}
  SF inside 50km circle?       #{circle.includes?(sf)}
CIRC

# Distance + Coordinate also works
circle2 = Distance.km(50) + seattle
puts <<~CIRC2
  Distance.km(50) + seattle  (commutative)
  Same circle? #{circle.centroid == circle2.centroid && circle.radius == circle2.radius}
CIRC2
puts

# ── 4. Vector Construction ──────────────────────────────────────

puts "--- 4. Vectors ---"
puts

v = Vector.new(distance: 100_000, bearing: 45.0)
puts <<~VEC
  Vector(100km, 45°)
  Distance:  #{v.distance.to_km}
  Bearing:   #{v.bearing} (#{v.bearing.to_compass})
  North:     #{v.north.round(1)} m
  East:      #{v.east.round(1)} m
  Magnitude: #{v.magnitude.round(1)} m
VEC

# From a Segment
seg = seattle + portland
v_from_seg = seg.to_vector
puts <<~VSEG
  Vector.from_segment(seattle → portland)
  Distance: #{v_from_seg.distance.to_km.to_s(1)}
  Bearing:  #{v_from_seg.bearing} (#{v_from_seg.bearing.to_compass})
VSEG

# From components
v2 = Vector.from_components(north: 1000, east: 1000)
puts <<~VCOMP
  Vector.from_components(north: 1000, east: 1000)
  Distance: #{v2.distance.to_s(1)}
  Bearing:  #{v2.bearing}
VCOMP
puts

# ── 5. Vector Arithmetic ────────────────────────────────────────

puts "--- 5. Vector Arithmetic ---"
puts

north = Vector.new(distance: 1000, bearing: 0.0)
east  = Vector.new(distance: 1000, bearing: 90.0)

sum = north + east
puts <<~VADD
  north(1km) + east(1km)
  Result:  #{sum.distance.to_s(1)} at #{sum.bearing}
  (1km north + 1km east = #{sum.distance.meters.round(1)}m at 45°)
VADD

scaled = north * 5
puts <<~VSCALE
  north(1km) * 5
  Result: #{scaled.distance.to_km}
VSCALE

reversed = north.reverse
puts <<~VREV
  north(1km).reverse
  Bearing: #{reversed.bearing} (#{reversed.bearing.to_compass})
VREV

cancelled = north + north.reverse
puts <<~VCANCEL
  north + north.reverse
  Zero? #{cancelled.zero?}
VCANCEL

puts <<~VDOT
  Dot & Cross products:
  north.dot(east)   = #{north.dot(east).round(1)}  (perpendicular → 0)
  north.dot(north)  = #{north.dot(north).round(1)}  (parallel → magnitude²)
  north.cross(east) = #{north.cross(east).round(1)}  (perpendicular → area)
VDOT
puts

# ── 6. Coordinate + Vector → Segment (Vincenty Direct) ──────────

puts "--- 6. Coordinate + Vector → Segment ---"
puts

v = Vector.new(distance: 100_000, bearing: 45.0)
seg = seattle + v
puts <<~CV
  seattle + Vector(100km, 45° NE)
  Type:    #{seg.class}
  Start:   #{seg.start_point.to_s(4)}
  End:     #{seg.end_point.to_s(4)}
  Length:  #{seg.length.to_km.to_s(1)}
  Bearing: #{seg.bearing}
CV

# Vector + Coordinate → Segment (prepend via reverse)
seg2 = v + seattle
puts <<~VC
  Vector(100km, 45° NE) + seattle
  Start:   #{seg2.start_point.to_s(4)}  (100km SW of seattle)
  End:     #{seg2.end_point.to_s(4)}  (seattle)
  Length:  #{seg2.length.to_km.to_s(1)}
VC
puts

# ── 7. Extending with Vectors ───────────────────────────────────

puts "--- 7. Extending Geometry with Vectors ---"
puts

# Segment + Vector → Path
seg = seattle + portland
detour_east = Vector.new(distance: 50_000, bearing: 90.0)
path = seg + detour_east
puts <<~SV
  (seattle + portland) + Vector(50km east)
  Type:      #{path.class}
  Waypoints: #{path.size}
  Last point #{path.last.lng > portland.lng ? "is east of" : "is NOT east of"} portland
SV

# Vector + Segment → Path (prepend)
approach = Vector.new(distance: 30_000, bearing: 180.0)
path2 = approach + seg
puts <<~VS
  Vector(30km south) + (seattle + portland)
  Type:      #{path2.class}
  Waypoints: #{path2.size}
  First point #{path2.first.lat > seattle.lat ? "is north of" : "is NOT north of"} seattle
  (reversed: 30km south → first point is 30km north)
VS

# Path + Vector → Path
route = seattle + portland + sf
extend_south = Vector.new(distance: 200_000, bearing: 180.0)
route2 = route + extend_south
puts <<~PV
  (seattle + portland + sf) + Vector(200km south)
  Waypoints: #{route2.size}
  Last point latitude: #{route2.last.lat.round(4)} (south of SF's #{sf.lat})
PV
puts

# ── 8. Translation with * ───────────────────────────────────────

puts "--- 8. Translation with * ---"
puts

shift_east = Vector.new(distance: 100_000, bearing: 90.0)

# Coordinate
p2 = seattle * shift_east
puts <<~TC
  Coordinate * Vector(100km east)
  seattle:    #{seattle.to_s(4)}
  translated: #{p2.to_s(4)}
  seattle.translate(v) also works: #{seattle.translate(shift_east).to_s(4)}
TC

# Segment
seg = seattle + portland
seg2 = seg * shift_east
puts <<~TS
  Segment * Vector(100km east)
  Original length: #{seg.length.to_km.to_s(1)}
  Shifted length:  #{seg2.length.to_km.to_s(1)}  (preserved)
  Start moved east: #{seg2.start_point.lng > seg.start_point.lng}
TS

# Path
route = seattle + portland + sf
route2 = route * shift_east
puts <<~TP
  Path * Vector(100km east)
  Original waypoints: #{route.size}
  Shifted waypoints:  #{route2.size}  (preserved)
  All moved east: #{route.coordinates.zip(route2.coordinates).all? { |a, b| b.lng > a.lng }}
TP

# Circle
circle = seattle + Distance.km(25)
circle2 = circle * shift_east
puts <<~TCIR
  Circle * Vector(100km east)
  Original centroid: #{circle.centroid.to_s(4)}
  Shifted centroid:  #{circle2.centroid.to_s(4)}
  Radius preserved:  #{circle.radius == circle2.radius}
TCIR

# Polygon
a = LLA.new(lat: 47.5, lng: -122.5, alt: 0)
b = LLA.new(lat: 47.5, lng: -122.2, alt: 0)
c = LLA.new(lat: 47.7, lng: -122.35, alt: 0)
poly = Areas::Polygon.new(boundary: [a, b, c])
poly2 = poly * shift_east
puts <<~TPOLY
  Polygon * Vector(100km east)
  Original centroid: #{poly.centroid.to_s(4)}
  Shifted centroid:  #{poly2.centroid.to_s(4)}
TPOLY
puts

# ── 9. + vs * with Vector ───────────────────────────────────────

puts "--- 9. Key Distinction: + vs * ---"
puts

v = Vector.new(distance: 50_000, bearing: 0.0)
journey     = seattle + v   # Segment (the journey)
destination = seattle * v   # Coordinate (just the result)

puts <<~DIFF
  v = Vector(50km north)

  seattle + v  → #{journey.class}
    start: #{journey.start_point.to_s(4)}
    end:   #{journey.end_point.to_s(4)}

  seattle * v  → #{destination.class}
    result: #{destination.to_s(4)}

  The endpoint equals the translated point:
    #{journey.end_point == destination}
DIFF
puts

# ── 10. Corridors ───────────────────────────────────────────────

puts "--- 10. Path Corridors ---"
puts

route = seattle + portland + sf
corridor = route.to_corridor(width: 50_000)
puts <<~CORR
  route.to_corridor(width: 50_000)  (50km wide)
  Type:     #{corridor.class}
  Vertices: #{corridor.boundary.size} (#{route.size} left + #{route.size} right + 1 closing)

  Portland inside corridor? #{corridor.includes?(portland)}
CORR

# Translate the corridor
shifted_corridor = corridor * Vector.new(distance: 200_000, bearing: 90.0)
puts <<~SCORR
  corridor * Vector(200km east)
  Portland still inside shifted corridor? #{shifted_corridor.includes?(portland)}
SCORR
puts

# ── 11. Composing Operations ────────────────────────────────────

puts "--- 11. Composing Operations ---"
puts

# Build a route, translate it, make a corridor
v = Vector.new(distance: 100_000, bearing: 90.0)
shifted_route = (seattle + portland + sf) * v
corridor = shifted_route.to_corridor(width: Distance.km(20))
puts <<~COMPOSE
  ((seattle + portland + sf) * Vector(100km east)).to_corridor(width: 20km)
  Route waypoints:   #{shifted_route.size}
  Corridor vertices: #{corridor.boundary.size}
COMPOSE

# Vector arithmetic to build displacement
leg1 = Vector.new(distance: 50_000, bearing: 0.0)    # 50km north
leg2 = Vector.new(distance: 30_000, bearing: 90.0)   # 30km east
combined = leg1 + leg2
seg = seattle + combined
puts <<~VECMATH
  Combined vector: north(50km) + east(30km)
  Resultant: #{combined.distance.to_km.to_s(1)} at #{combined.bearing}
  Segment from seattle: #{seg.length.to_km.to_s(1)} at #{seg.bearing}
VECMATH

# Scale a vector to create multiple equidistant points
base = Vector.new(distance: 100_000, bearing: 45.0)
points = (1..5).map { |i| seattle * (base * i) }
puts <<~EQUI
  5 equidistant points at 100km intervals, bearing 45° NE:
EQUI
points.each_with_index do |pt, i|
  d = seattle.distance_to(pt).to_km
  puts "    #{i + 1}. #{pt.to_s(4)}  (#{d.to_s(0)} from seattle)"
end

puts
puts "=== Done ==="
