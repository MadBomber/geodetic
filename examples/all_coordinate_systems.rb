#!/usr/bin/env ruby
# Comprehensive demonstration of all coordinate systems
# Shows complete orthogonal conversions between all implemented coordinate systems

require_relative '../lib/geodetic'
require_relative '../lib/geodetic/coordinates/lla'
require_relative '../lib/geodetic/coordinates/ecef'
require_relative '../lib/geodetic/coordinates/utm'
require_relative '../lib/geodetic/coordinates/enu'
require_relative '../lib/geodetic/coordinates/ned'
require_relative '../lib/geodetic/coordinates/mgrs'
require_relative '../lib/geodetic/coordinates/web_mercator'
require_relative '../lib/geodetic/coordinates/ups'
require_relative '../lib/geodetic/coordinates/usng'
require_relative '../lib/geodetic/coordinates/state_plane'
require_relative '../lib/geodetic/coordinates/bng'
require_relative '../lib/geodetic/geoid_height'

include Geodetic
LLA        = Coordinates::LLA
ECEF       = Coordinates::ECEF
UTM_Coord  = Coordinates::UTM
ENU        = Coordinates::ENU
NED        = Coordinates::NED
MGRS       = Coordinates::MGRS
USNG       = Coordinates::USNG
WebMerc    = Coordinates::WebMercator
UPS        = Coordinates::UPS
StatePlane = Coordinates::StatePlane
BNG        = Coordinates::BNG

def demo_coordinate_systems
  puts "=" * 80
  puts "COMPLETE COORDINATE SYSTEM CONVERSION DEMONSTRATION"
  puts "=" * 80
  puts

  # Test location: Seattle Space Needle
  seattle_lat = 47.6205
  seattle_lng = -122.3493
  seattle_alt = 184.0

  puts "Reference Location: Seattle Space Needle"
  puts "   Latitude:  #{seattle_lat} degrees"
  puts "   Longitude: #{seattle_lng} degrees"
  puts "   Altitude:  #{seattle_alt} meters"
  puts

  # Create reference LLA coordinate
  lla_coord = LLA.new(lat: seattle_lat, lng: seattle_lng, alt: seattle_alt)
  reference_lla = LLA.new(lat: seattle_lat, lng: seattle_lng, alt: 0.0)  # For local coordinates

  puts "ALL COORDINATE SYSTEM CONVERSIONS"
  puts "-" * 50

  # ========== ECEF Conversion ==========
  puts "Earth-Centered, Earth-Fixed (ECEF)"
  ecef_coord = lla_coord.to_ecef
  puts "   ECEF: X=#{ecef_coord.x.round(3)}m, Y=#{ecef_coord.y.round(3)}m, Z=#{ecef_coord.z.round(3)}m"

  # Round-trip test
  lla_from_ecef = ecef_coord.to_lla
  lat_error = (lla_from_ecef.lat - seattle_lat).abs
  lng_error = (lla_from_ecef.lng - seattle_lng).abs
  puts "   Round-trip error: Lat=#{lat_error.round(15)}, Lng=#{lng_error.round(15)}"
  puts

  # ========== UTM Conversion ==========
  puts "Universal Transverse Mercator (UTM)"
  utm_coord = lla_coord.to_utm
  puts "   UTM: #{utm_coord.easting.round(3)}E #{utm_coord.northing.round(3)}N Zone #{utm_coord.zone}#{utm_coord.hemisphere}"

  # Round-trip test
  lla_from_utm = utm_coord.to_lla
  utm_lat_error = (lla_from_utm.lat - seattle_lat).abs
  utm_lng_error = (lla_from_utm.lng - seattle_lng).abs
  puts "   Round-trip error: Lat=#{utm_lat_error.round(8)}, Lng=#{utm_lng_error.round(8)}"
  puts

  # ========== ENU Conversion ==========
  puts "East, North, Up (ENU) Local Coordinates"
  enu_coord = lla_coord.to_enu(reference_lla)
  puts "   ENU: E=#{enu_coord.east.round(3)}m, N=#{enu_coord.north.round(3)}m, U=#{enu_coord.up.round(3)}m"
  puts "   Distance from reference: #{enu_coord.distance_to_origin.round(3)}m"
  puts "   Bearing from reference: #{enu_coord.bearing_from_origin.round(3)} degrees"
  puts

  # ========== NED Conversion ==========
  puts "North, East, Down (NED) Local Coordinates"
  ned_coord = lla_coord.to_ned(reference_lla)
  puts "   NED: N=#{ned_coord.north.round(3)}m, E=#{ned_coord.east.round(3)}m, D=#{ned_coord.down.round(3)}m"
  puts "   Distance from reference: #{ned_coord.distance_to_origin.round(3)}m"
  puts "   Elevation angle: #{ned_coord.elevation_angle.round(3)} degrees"
  puts

  # ========== MGRS Conversion ==========
  puts "Military Grid Reference System (MGRS)"
  mgrs_coord = MGRS.from_lla(lla_coord)
  puts "   MGRS: #{mgrs_coord}"
  puts "   Zone: #{mgrs_coord.grid_zone_designator}, Square: #{mgrs_coord.square_identifier}"
  puts "   Within square: #{mgrs_coord.easting.round(3)}E, #{mgrs_coord.northing.round(3)}N"

  # Test different precisions
  mgrs_10m = MGRS.from_lla(lla_coord, WGS84, 4)
  mgrs_1m = MGRS.from_lla(lla_coord, WGS84, 5)
  puts "   10m precision: #{mgrs_10m}"
  puts "   1m precision:  #{mgrs_1m}"
  puts

  # ========== USNG Conversion ==========
  puts "US National Grid (USNG)"
  usng_coord = USNG.from_lla(lla_coord)
  puts "   USNG: #{usng_coord}"
  puts "   Full format: #{usng_coord.to_full_format}"
  puts "   Abbreviated: #{usng_coord.to_abbreviated_format}"
  puts

  # ========== Web Mercator Conversion ==========
  puts "Web Mercator (EPSG:3857) - Used by Google Maps, OSM"
  web_merc_coord = WebMerc.from_lla(lla_coord)
  puts "   Web Mercator: X=#{web_merc_coord.x.round(3)}m, Y=#{web_merc_coord.y.round(3)}m"

  # Test tile coordinates at different zoom levels
  tile_10 = web_merc_coord.to_tile_coordinates(10)
  tile_15 = web_merc_coord.to_tile_coordinates(15)
  puts "   Tile (zoom 10): X=#{tile_10[0]}, Y=#{tile_10[1]}"
  puts "   Tile (zoom 15): X=#{tile_15[0]}, Y=#{tile_15[1]}"
  puts

  # ========== UPS Conversion (using North Pole example) ==========
  puts "Universal Polar Stereographic (UPS)"
  north_pole_lla = LLA.new(lat: 89.0, lng: 0.0, alt: 0.0)
  ups_coord = UPS.from_lla(north_pole_lla)
  puts "   UPS (North Pole): #{ups_coord.easting.round(3)}E #{ups_coord.northing.round(3)}N Zone #{ups_coord.zone}#{ups_coord.hemisphere}"
  puts "   Grid convergence: #{ups_coord.grid_convergence.round(6)} degrees"
  puts "   Scale factor: #{ups_coord.point_scale_factor.round(8)}"
  puts

  # ========== State Plane Conversion ==========
  puts "State Plane Coordinate System (SPC)"
  begin
    ca_spc = StatePlane.from_lla(lla_coord, 'CA_I')
    puts "   California Zone I: #{ca_spc.easting.round(3)}ft, #{ca_spc.northing.round(3)}ft"
    puts "   State: #{ca_spc.zone_info[:state]}, Projection: #{ca_spc.zone_info[:projection]}"
    puts "   Units: #{ca_spc.zone_info[:units]}"

    # Convert to meters
    ca_spc_meters = ca_spc.to_meters
    puts "   In meters: #{ca_spc_meters.easting.round(3)}m, #{ca_spc_meters.northing.round(3)}m"
  rescue => e
    puts "   State Plane conversion: #{e.message}"
  end
  puts

  # ========== British National Grid Conversion ==========
  puts "British National Grid (BNG)"
  london_lla = LLA.new(lat: 51.5007, lng: -0.1246, alt: 11.0)
  bng_coord = BNG.from_lla(london_lla)
  puts "   BNG (London): #{bng_coord.easting.round(3)}E #{bng_coord.northing.round(3)}N"
  puts "   Grid reference: #{bng_coord.to_grid_reference(6)}"
  puts "   Grid reference (low precision): #{bng_coord.to_grid_reference(0)}"
  puts

  # ========== Geoid Height Demonstration ==========
  puts "Geoid Height and Vertical Datum Support"
  geoid = GeoidHeight.new(geoid_model: 'EGM2008')

  seattle_geoid_height = geoid.geoid_height_at(seattle_lat, seattle_lng)
  orthometric_height = geoid.ellipsoidal_to_orthometric(seattle_lat, seattle_lng, seattle_alt)

  puts "   Geoid height (EGM2008): #{seattle_geoid_height.round(3)}m"
  puts "   Ellipsoidal height (HAE): #{seattle_alt}m"
  puts "   Orthometric height (MSL): #{orthometric_height.round(3)}m"

  # Test different geoid models
  egm96_geoid = GeoidHeight.new(geoid_model: 'EGM96')
  egm96_height = egm96_geoid.geoid_height_at(seattle_lat, seattle_lng)
  puts "   Geoid height (EGM96): #{egm96_height.round(3)}m"
  puts "   Model difference: #{(seattle_geoid_height - egm96_height).abs.round(3)}m"

  # Test vertical datum conversion
  navd88_height = geoid.convert_vertical_datum(seattle_lat, seattle_lng, seattle_alt, 'HAE', 'NAVD88')
  puts "   Height in NAVD88: #{navd88_height.round(3)}m"
  puts

  # ========== Cross-System Conversions ==========
  puts "CROSS-SYSTEM CONVERSION CHAINS"
  puts "-" * 50

  # Chain 1: 3D systems that preserve altitude
  puts "Chain 1 (3D systems): LLA -> ECEF -> UTM -> ENU -> NED -> LLA"
  c1_ecef  = lla_coord.to_ecef
  c1_utm   = c1_ecef.to_utm
  c1_enu   = c1_utm.to_enu(reference_lla)
  c1_ned   = c1_enu.to_ned
  c1_final = c1_ned.to_lla(reference_lla)

  c1_lat_err = (c1_final.lat - seattle_lat).abs
  c1_lng_err = (c1_final.lng - seattle_lng).abs
  c1_alt_err = (c1_final.alt - seattle_alt).abs

  puts "   Final: #{c1_final.lat.round(8)}°, #{c1_final.lng.round(8)}°, #{c1_final.alt.round(3)}m"
  puts "   Error: Lat=#{c1_lat_err.round(10)}°, Lng=#{c1_lng_err.round(10)}°, Alt=#{c1_alt_err.round(6)}m"
  puts

  # Chain 2: 2D systems (use altitude 0.0 since these systems don't carry altitude)
  lla_2d = LLA.new(lat: seattle_lat, lng: seattle_lng, alt: 0.0)

  puts "Chain 2 (2D systems): LLA -> MGRS -> USNG -> Web Mercator -> LLA"
  puts "   Starting with altitude 0.0 (2D systems do not carry altitude)"
  c2_mgrs     = MGRS.from_lla(lla_2d)
  c2_usng     = USNG.from_mgrs(c2_mgrs)
  c2_web_merc = WebMerc.from_lla(c2_usng.to_lla)
  c2_final    = c2_web_merc.to_lla

  c2_lat_err = (c2_final.lat - seattle_lat).abs
  c2_lng_err = (c2_final.lng - seattle_lng).abs

  puts "   Final: #{c2_final.lat.round(8)}°, #{c2_final.lng.round(8)}°, #{c2_final.alt.round(3)}m"
  puts "   Error: Lat=#{c2_lat_err.round(8)}° (~#{(c2_lat_err * 111320).round(2)}m), Lng=#{c2_lng_err.round(8)}° (~#{(c2_lng_err * 111320 * Math.cos(seattle_lat * Math::PI / 180)).round(2)}m), Alt=#{c2_final.alt.round(3)}m"
  puts "   Lat/Lng error is from MGRS 1-meter grid precision truncation."
  puts

  # ========== Summary ==========
  puts "COORDINATE SYSTEM SUMMARY"
  puts "-" * 50
  puts "LLA (Latitude, Longitude, Altitude)"
  puts "ECEF (Earth-Centered, Earth-Fixed)"
  puts "UTM (Universal Transverse Mercator)"
  puts "ENU (East, North, Up)"
  puts "NED (North, East, Down)"
  puts "MGRS (Military Grid Reference System)"
  puts "USNG (US National Grid)"
  puts "Web Mercator (EPSG:3857)"
  puts "UPS (Universal Polar Stereographic)"
  puts "State Plane Coordinates"
  puts "British National Grid (BNG)"
  puts "Geoid Height Support"
  puts
  puts "All coordinate systems support complete bidirectional conversions!"
  puts "Total coordinate systems implemented: 12"
  puts "Total conversion paths available: 132 (12 x 11)"
  puts
  puts "=" * 80
end

# Run the demonstration if this file is executed directly
if __FILE__ == $0
  demo_coordinate_systems
end
