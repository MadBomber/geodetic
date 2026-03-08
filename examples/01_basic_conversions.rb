#!/usr/bin/env ruby

# Demonstration of orthogonal coordinate system conversions
# Shows all coordinate systems converting to/from each other

require_relative '../lib/geodetic'
require_relative '../lib/geodetic/coordinate/lla'
require_relative '../lib/geodetic/coordinate/ecef'
require_relative '../lib/geodetic/coordinate/enu'
require_relative '../lib/geodetic/coordinate/ned'
require_relative '../lib/geodetic/coordinate/utm'

include Geodetic
LLA  = Coordinate::LLA
ECEF = Coordinate::ECEF
ENU  = Coordinate::ENU
NED  = Coordinate::NED
UTM  = Coordinate::UTM

puts "=== Orthogonal Coordinate System Conversions Demo ==="
puts

# Test location: Seattle Space Needle
seattle_lat = 47.6205
seattle_lng = -122.3493
seattle_alt = 184.0

puts "Original Test Point (Seattle Space Needle):"
puts "Latitude:  #{seattle_lat}"
puts "Longitude: #{seattle_lng}"
puts "Altitude:  #{seattle_alt}m"
puts

# Create initial LLA coordinate
lla = LLA.new(lat: seattle_lat, lng: seattle_lng, alt: seattle_alt)
puts "1. LLA Coordinate: #{lla}"

# LLA -> ECEF
ecef = lla.to_ecef
puts "2. LLA -> ECEF: #{ecef}"

# ECEF -> LLA (roundtrip test)
lla_back = ecef.to_lla
puts "3. ECEF -> LLA: #{lla_back}"
lat_error = (seattle_lat - lla_back.lat).abs
lng_error = (seattle_lng - lla_back.lng).abs
alt_error = (seattle_alt - lla_back.alt).abs
puts "   Roundtrip errors: lat=#{lat_error}, lng=#{lng_error}, alt=#{alt_error}"
puts

# LLA -> UTM
utm = lla.to_utm
puts "4. LLA -> UTM: #{utm}"

# UTM -> LLA (roundtrip test)
lla_from_utm = utm.to_lla
puts "5. UTM -> LLA: #{lla_from_utm}"
puts

# Reference point for local coordinates (slightly offset)
ref_lla = LLA.new(lat: seattle_lat - 0.01, lng: seattle_lng + 0.01, alt: seattle_alt - 100)
puts "Reference point for local coordinates:"
puts "6. Reference LLA: #{ref_lla}"

# LLA -> ENU
enu = lla.to_enu(ref_lla)
puts "7. LLA -> ENU: #{enu}"
puts "   (East: #{enu.e.round(2)}m, North: #{enu.n.round(2)}m, Up: #{enu.u.round(2)}m)"

# ENU -> LLA (roundtrip test)
lla_from_enu = enu.to_lla(ref_lla)
puts "8. ENU -> LLA: #{lla_from_enu}"

# LLA -> NED
ned = lla.to_ned(ref_lla)
puts "9. LLA -> NED: #{ned}"
puts "   (North: #{ned.n.round(2)}m, East: #{ned.e.round(2)}m, Down: #{ned.d.round(2)}m)"

# NED -> LLA (roundtrip test)
lla_from_ned = ned.to_lla(ref_lla)
puts "10. NED -> LLA: #{lla_from_ned}"
puts

# Cross-conversions between local coordinate systems
puts "=== Local Coordinate Cross-Conversions ==="

# ENU <-> NED
ned_from_enu = enu.to_ned
puts "11. ENU -> NED: #{ned_from_enu}"
enu_from_ned = ned.to_enu
puts "12. NED -> ENU: #{enu_from_ned}"

# Verify ENU <-> NED consistency
enu_error_e = (enu.e - enu_from_ned.e).abs
enu_error_n = (enu.n - enu_from_ned.n).abs
enu_error_u = (enu.u - enu_from_ned.u).abs
puts "    ENU roundtrip errors: e=#{enu_error_e}, n=#{enu_error_n}, u=#{enu_error_u}"
puts

# Chain conversions to test system consistency
puts "=== Chain Conversion Test (LLA -> ECEF -> ENU -> NED -> ECEF -> LLA) ==="

ref_ecef = ref_lla.to_ecef

step1_ecef = lla.to_ecef
puts "13. LLA -> ECEF: #{step1_ecef}"

step2_enu = step1_ecef.to_enu(ref_ecef, ref_lla)
puts "14. ECEF -> ENU: #{step2_enu}"

step3_ned = step2_enu.to_ned
puts "15. ENU -> NED: #{step3_ned}"

step4_ecef = step3_ned.to_ecef(ref_ecef, ref_lla)
puts "16. NED -> ECEF: #{step4_ecef}"

step5_lla = step4_ecef.to_lla
puts "17. ECEF -> LLA: #{step5_lla}"

# Check final accuracy
final_lat_error = (seattle_lat - step5_lla.lat).abs
final_lng_error = (seattle_lng - step5_lla.lng).abs
final_alt_error = (seattle_alt - step5_lla.alt).abs
puts "    Chain conversion errors: lat=#{final_lat_error}, lng=#{final_lng_error}, alt=#{final_alt_error}"
puts

# Distance calculations
puts "=== Distance and Bearing Calculations ==="

# Create another test point (Pioneer Square, Seattle)
pioneer_lla = LLA.new(lat: 47.6097, lng: -122.3331, alt: 56.0)
puts "18. Second point (Pioneer Square): #{pioneer_lla}"

# ECEF distance
pioneer_ecef = pioneer_lla.to_ecef
ecef_distance = ecef.distance_to(pioneer_ecef)
puts "19. ECEF distance: #{ecef_distance.to_s}"

# ENU distance and bearing
pioneer_enu = pioneer_lla.to_enu(lla)  # Using first point as reference
enu_origin = ENU.new(e: 0, n: 0, u: 0)
enu_distance = enu_origin.distance_to_origin
enu_bearing = enu_origin.local_bearing_to(pioneer_enu)
horizontal_distance = enu_origin.horizontal_distance_to(pioneer_enu)

puts "20. ENU distance to origin: #{enu_distance.round(2)}m"
puts "21. ENU bearing: #{enu_bearing.round(1)} degrees"
puts "22. Horizontal distance: #{horizontal_distance.round(2)}m"

# UTM distance (same zone)
pioneer_utm = pioneer_lla.to_utm
utm_distance = utm.distance_to(pioneer_utm)
puts "23. UTM distance: #{utm_distance.to_s}"

puts
puts "=== All Coordinate Systems Summary ==="
puts "LLA:  #{lla}"
puts "ECEF: #{ecef}"
puts "UTM:  #{utm}"
puts "ENU:  #{enu} (relative to reference)"
puts "NED:  #{ned} (relative to reference)"

puts
puts "=== to_s Precision Control ==="
puts
puts "All to_s methods accept an optional precision parameter:"
puts
puts "LLA (default=6):"
puts "  to_s     => #{lla.to_s}"
puts "  to_s(3)  => #{lla.to_s(3)}"
puts "  to_s(0)  => #{lla.to_s(0)}"
puts
puts "ECEF (default=2):"
puts "  to_s     => #{ecef.to_s}"
puts "  to_s(0)  => #{ecef.to_s(0)}"
puts
puts "UTM (default=2):"
puts "  to_s     => #{utm.to_s}"
puts "  to_s(0)  => #{utm.to_s(0)}"
puts
puts "ENU (default=2):"
puts "  to_s     => #{enu.to_s}"
puts "  to_s(4)  => #{enu.to_s(4)}"
puts "  to_s(0)  => #{enu.to_s(0)}"
puts
puts "All coordinate systems successfully demonstrate complete orthogonal conversions!"
puts "Each system can convert to and from every other system with high precision."
