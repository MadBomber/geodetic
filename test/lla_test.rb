# frozen_string_literal: true

require "test_helper"
require "geodetic/coordinate/lla"
require "geodetic/coordinate/ecef"
require "geodetic/coordinate/utm"
require "geodetic/coordinate/enu"
require "geodetic/coordinate/ned"

class LlaTest < Minitest::Test
  LLA  = Geodetic::Coordinate::LLA
  ECEF = Geodetic::Coordinate::ECEF
  UTM  = Geodetic::Coordinate::UTM
  ENU  = Geodetic::Coordinate::ENU
  NED  = Geodetic::Coordinate::NED

  # ── Constructor ──────────────────────────────────────────────

  def test_default_values
    coord = LLA.new
    assert_in_delta 0.0, coord.lat, 1e-6
    assert_in_delta 0.0, coord.lng, 1e-6
    assert_in_delta 0.0, coord.alt, 1e-6
  end

  def test_keyword_arguments
    coord = LLA.new(lat: 47.6205, lng: -122.3493, alt: 184.0)
    assert_in_delta 47.6205, coord.lat, 1e-6
    assert_in_delta(-122.3493, coord.lng, 1e-6)
    assert_in_delta 184.0, coord.alt, 1e-6
  end

  def test_validates_latitude_range
    assert_raises(ArgumentError) { LLA.new(lat: 91.0) }
    assert_raises(ArgumentError) { LLA.new(lat: -91.0) }
  end

  def test_validates_longitude_range
    assert_raises(ArgumentError) { LLA.new(lng: 181.0) }
    assert_raises(ArgumentError) { LLA.new(lng: -181.0) }
  end

  def test_to_f_coercion
    coord = LLA.new(lat: "47", lng: "-122", alt: "184")
    assert_in_delta 47.0, coord.lat, 1e-6
    assert_in_delta(-122.0, coord.lng, 1e-6)
    assert_in_delta 184.0, coord.alt, 1e-6
  end

  # ── Accessors and aliases ────────────────────────────────────

  def test_lat_latitude_alias
    coord = LLA.new(lat: 47.6205)
    assert_equal coord.lat, coord.latitude
  end

  def test_lng_longitude_alias
    coord = LLA.new(lng: -122.3493)
    assert_equal coord.lng, coord.longitude
  end

  def test_lon_reader_alias
    coord = LLA.new(lng: -122.3493)
    assert_equal coord.lng, coord.lon
  end

  def test_long_reader_alias
    coord = LLA.new(lng: -122.3493)
    assert_equal coord.lng, coord.long
  end

  def test_lon_constructor_kwarg
    coord = LLA.new(lat: 47.6205, lon: -122.3493)
    assert_in_delta(-122.3493, coord.lng, 1e-6)
  end

  def test_long_constructor_kwarg
    coord = LLA.new(lat: 47.6205, long: -122.3493)
    assert_in_delta(-122.3493, coord.lng, 1e-6)
  end

  def test_conflicting_longitude_kwargs_raises
    assert_raises(ArgumentError) { LLA.new(lng: 10.0, lon: 20.0) }
    assert_raises(ArgumentError) { LLA.new(lng: 10.0, long: 20.0) }
    assert_raises(ArgumentError) { LLA.new(lon: 10.0, long: 20.0) }
  end

  def test_alt_altitude_alias
    coord = LLA.new(alt: 184.0)
    assert_equal coord.alt, coord.altitude
  end

  # ── to_s ─────────────────────────────────────────────────────

  def test_to_s
    coord = LLA.new(lat: 47.6205, lng: -122.3493, alt: 184.0)
    assert_equal "47.620500, -122.349300, 184.00", coord.to_s
  end

  def test_to_s_with_precision
    coord = LLA.new(lat: 47.6205, lng: -122.3493, alt: 184.0)
    assert_equal "47.620, -122.349, 184.00", coord.to_s(3)
    assert_equal "47.62, -122.35, 184.00", coord.to_s(2)
    assert_equal "48, -122, 184", coord.to_s(0)
  end

  # ── to_a ─────────────────────────────────────────────────────

  def test_to_a
    coord = LLA.new(lat: 47.6205, lng: -122.3493, alt: 184.0)
    result = coord.to_a
    assert_equal 3, result.size
    assert_in_delta 47.6205, result[0], 1e-6
    assert_in_delta(-122.3493, result[1], 1e-6)
    assert_in_delta 184.0, result[2], 1e-6
  end

  # ── from_array ───────────────────────────────────────────────

  def test_from_array_roundtrip
    original = LLA.new(lat: 47.6205, lng: -122.3493, alt: 184.0)
    restored = LLA.from_array(original.to_a)
    assert_in_delta original.lat, restored.lat, 1e-6
    assert_in_delta original.lng, restored.lng, 1e-6
    assert_in_delta original.alt, restored.alt, 1e-6
  end

  # ── from_string ──────────────────────────────────────────────

  def test_from_string_roundtrip
    original = LLA.new(lat: 47.6205, lng: -122.3493, alt: 184.0)
    restored = LLA.from_string(original.to_s)
    assert_in_delta original.lat, restored.lat, 1e-6
    assert_in_delta original.lng, restored.lng, 1e-6
    assert_in_delta original.alt, restored.alt, 1e-6
  end

  # ── == ───────────────────────────────────────────────────────

  def test_equality_equal_coords
    a = LLA.new(lat: 47.6205, lng: -122.3493, alt: 184.0)
    b = LLA.new(lat: 47.6205, lng: -122.3493, alt: 184.0)
    assert_equal a, b
  end

  def test_equality_unequal_coords
    a = LLA.new(lat: 47.6205, lng: -122.3493, alt: 184.0)
    b = LLA.new(lat: 48.0, lng: -122.3493, alt: 184.0)
    refute_equal a, b
  end

  def test_equality_non_lla_object
    coord = LLA.new(lat: 47.6205, lng: -122.3493, alt: 184.0)
    refute_equal coord, "not an LLA"
  end

  # ── to_dms / from_dms ───────────────────────────────────────

  def test_to_dms_zero
    coord = LLA.new(lat: 0, lng: 0, alt: 0)
    expected = "0° 0' 0.00\" N, 0° 0' 0.00\" E, 0.00 m"
    assert_equal expected, coord.to_dms
  end

  def test_to_dms_positive_lat_lng
    coord = LLA.new(lat: 37.7749, lng: 122.4194, alt: 15.3)
    dms = coord.to_dms
    assert_match(/N/, dms)
    assert_match(/E/, dms)
  end

  def test_to_dms_negative_lat_lng
    coord = LLA.new(lat: -33.8688, lng: -151.2093, alt: 0.0)
    dms = coord.to_dms
    assert_match(/S/, dms)
    assert_match(/W/, dms)
  end

  def test_dms_roundtrip_with_altitude
    original = LLA.new(lat: 37.7749, lng: -122.419233, alt: 15.3)
    dms = original.to_dms
    restored = LLA.from_dms(dms)
    assert_in_delta original.lat, restored.lat, 1e-6
    assert_in_delta original.lng, restored.lng, 1e-6
    assert_in_delta original.alt, restored.alt, 1e-6
  end

  def test_dms_roundtrip_negative_altitude
    original = LLA.new(lat: -10.341666, lng: 40.85, alt: -5.5)
    dms = original.to_dms
    restored = LLA.from_dms(dms)
    assert_in_delta original.lat, restored.lat, 1e-6
    assert_in_delta original.lng, restored.lng, 1e-6
    assert_in_delta original.alt, restored.alt, 1e-6
  end

  # ── to_ecef / from_ecef ─────────────────────────────────────

  def test_ecef_roundtrip
    original = LLA.new(lat: 47.6205, lng: -122.3493, alt: 184.0)
    ecef = original.to_ecef
    restored = LLA.from_ecef(ecef)
    assert_in_delta original.lat, restored.lat, 1e-4
    assert_in_delta original.lng, restored.lng, 1e-4
    assert_in_delta original.alt, restored.alt, 1e-4
  end

  # ── to_utm / from_utm ───────────────────────────────────────

  def test_to_utm_produces_valid_utm
    original = LLA.new(lat: 47.6205, lng: -122.3493, alt: 184.0)
    utm = original.to_utm
    assert_instance_of UTM, utm
    assert_equal "N", utm.hemisphere
    assert_equal 10, utm.zone
    assert_in_delta 184.0, utm.altitude, 1e-6
    assert utm.easting > 0, "Easting should be positive"
    assert utm.northing > 0, "Northing should be positive"
  end

  def test_from_utm_produces_valid_lla
    utm = UTM.new(easting: 500000.0, northing: 5000000.0, altitude: 100.0, zone: 10, hemisphere: "N")
    restored = LLA.from_utm(utm)
    assert_instance_of LLA, restored
    assert_in_delta 100.0, restored.alt, 1e-6
    assert restored.lat >= -90 && restored.lat <= 90, "Latitude should be valid"
    assert restored.lng >= -180 && restored.lng <= 180, "Longitude should be valid"
  end

  # ── to_enu / from_enu ───────────────────────────────────────

  def test_enu_roundtrip
    reference = LLA.new(lat: 47.0, lng: -122.0, alt: 0.0)
    original  = LLA.new(lat: 47.6205, lng: -122.3493, alt: 184.0)
    enu = original.to_enu(reference)
    restored = LLA.from_enu(enu, reference)
    assert_in_delta original.lat, restored.lat, 1e-4
    assert_in_delta original.lng, restored.lng, 1e-4
    assert_in_delta original.alt, restored.alt, 1e-4
  end

  # ── to_ned / from_ned ───────────────────────────────────────

  def test_ned_roundtrip
    reference = LLA.new(lat: 47.0, lng: -122.0, alt: 0.0)
    original  = LLA.new(lat: 47.6205, lng: -122.3493, alt: 184.0)
    ned = original.to_ned(reference)
    restored = LLA.from_ned(ned, reference)
    assert_in_delta original.lat, restored.lat, 1e-4
    assert_in_delta original.lng, restored.lng, 1e-4
    assert_in_delta original.alt, restored.alt, 1e-4
  end

  # ── validate_coordinates! ────────────────────────────────────

  def test_validate_lat_above_90
    error = assert_raises(ArgumentError) { LLA.new(lat: 90.001) }
    assert_match(/Latitude/, error.message)
  end

  def test_validate_lat_below_negative_90
    error = assert_raises(ArgumentError) { LLA.new(lat: -90.001) }
    assert_match(/Latitude/, error.message)
  end

  def test_validate_lng_above_180
    error = assert_raises(ArgumentError) { LLA.new(lng: 180.001) }
    assert_match(/Longitude/, error.message)
  end

  def test_validate_lng_below_negative_180
    error = assert_raises(ArgumentError) { LLA.new(lng: -180.001) }
    assert_match(/Longitude/, error.message)
  end

  # -- bearing_to (universal mixin) ----------------------------------------

  def test_bearing_to_due_north
    a = LLA.new(lat: 0.0, lng: 0.0)
    b = LLA.new(lat: 1.0, lng: 0.0)
    bearing = a.bearing_to(b)
    assert_instance_of Geodetic::Bearing, bearing
    assert_in_delta 0.0, bearing.degrees, 0.01
  end

  def test_bearing_to_due_east
    a = LLA.new(lat: 0.0, lng: 0.0)
    b = LLA.new(lat: 0.0, lng: 1.0)
    assert_in_delta 90.0, a.bearing_to(b).degrees, 0.01
  end

  def test_bearing_to_due_south
    a = LLA.new(lat: 1.0, lng: 0.0)
    b = LLA.new(lat: 0.0, lng: 0.0)
    assert_in_delta 180.0, a.bearing_to(b).degrees, 0.01
  end

  def test_bearing_to_due_west
    a = LLA.new(lat: 0.0, lng: 0.0)
    b = LLA.new(lat: 0.0, lng: -1.0)
    assert_in_delta 270.0, a.bearing_to(b).degrees, 0.01
  end

  # -- elevation_to (universal mixin) ------------------------------------

  def test_elevation_to_same_altitude
    a = LLA.new(lat: 47.0, lng: -122.0, alt: 0.0)
    b = LLA.new(lat: 47.1, lng: -122.0, alt: 0.0)
    assert_in_delta 0.0, a.elevation_to(b), 1.0
  end

  def test_elevation_to_above
    a = LLA.new(lat: 47.0, lng: -122.0, alt: 0.0)
    b = LLA.new(lat: 47.0, lng: -122.0, alt: 10000.0)
    assert a.elevation_to(b) > 80.0  # nearly straight up
  end

  def test_elevation_to_below
    a = LLA.new(lat: 47.0, lng: -122.0, alt: 10000.0)
    b = LLA.new(lat: 47.0, lng: -122.0, alt: 0.0)
    assert a.elevation_to(b) < -80.0  # nearly straight down
  end

  # -- setters ---------------------------------------------------------------

  def test_lat_setter
    lla = LLA.new(lat: 47.0, lng: -122.0, alt: 100.0)
    lla.lat = 48.0
    assert_in_delta 48.0, lla.lat, 1e-6
  end

  def test_lng_setter
    lla = LLA.new(lat: 47.0, lng: -122.0, alt: 100.0)
    lla.lng = -121.0
    assert_in_delta(-121.0, lla.lng, 1e-6)
  end

  def test_alt_setter
    lla = LLA.new(lat: 47.0, lng: -122.0, alt: 100.0)
    lla.alt = 200.0
    assert_in_delta 200.0, lla.alt, 1e-6
  end

  def test_setter_aliases
    lla = LLA.new(lat: 47.0, lng: -122.0, alt: 100.0)
    lla.latitude = 48.0
    lla.longitude = -121.0
    lla.altitude = 200.0
    assert_in_delta 48.0, lla.lat, 1e-6
    assert_in_delta(-121.0, lla.lng, 1e-6)
    assert_in_delta 200.0, lla.alt, 1e-6
  end

  def test_setters_coerce_to_float
    lla = LLA.new(lat: 47.0, lng: -122.0, alt: 100.0)
    lla.lat = "48"
    lla.lng = "-121"
    lla.alt = "200"
    assert_in_delta 48.0, lla.lat, 1e-6
    assert_in_delta(-121.0, lla.lng, 1e-6)
    assert_in_delta 200.0, lla.alt, 1e-6
  end

  def test_lat_setter_validates_range
    lla = LLA.new(lat: 47.0, lng: -122.0, alt: 100.0)
    assert_raises(ArgumentError) { lla.lat = 91.0 }
    assert_raises(ArgumentError) { lla.lat = -91.0 }
    # Original value should be preserved
    assert_in_delta 47.0, lla.lat, 1e-6
  end

  def test_lng_setter_validates_range
    lla = LLA.new(lat: 47.0, lng: -122.0, alt: 100.0)
    assert_raises(ArgumentError) { lla.lng = 181.0 }
    assert_raises(ArgumentError) { lla.lng = -181.0 }
    # Original value should be preserved
    assert_in_delta(-122.0, lla.lng, 1e-6)
  end

  # ── NaN/Infinity validation in constructor ─────────────────

  def test_constructor_rejects_nan_lat
    error = assert_raises(ArgumentError) { LLA.new(lat: Float::NAN) }
    assert_match(/Latitude/, error.message)
  end

  def test_constructor_rejects_infinity_lat
    error = assert_raises(ArgumentError) { LLA.new(lat: Float::INFINITY) }
    assert_match(/Latitude/, error.message)
  end

  def test_constructor_rejects_negative_infinity_lat
    error = assert_raises(ArgumentError) { LLA.new(lat: -Float::INFINITY) }
    assert_match(/Latitude/, error.message)
  end

  def test_constructor_rejects_nan_lng
    error = assert_raises(ArgumentError) { LLA.new(lng: Float::NAN) }
    assert_match(/Longitude/, error.message)
  end

  def test_constructor_rejects_infinity_lng
    error = assert_raises(ArgumentError) { LLA.new(lng: Float::INFINITY) }
    assert_match(/Longitude/, error.message)
  end

  def test_constructor_rejects_negative_infinity_lng
    error = assert_raises(ArgumentError) { LLA.new(lng: -Float::INFINITY) }
    assert_match(/Longitude/, error.message)
  end

  def test_constructor_rejects_nan_alt
    error = assert_raises(ArgumentError) { LLA.new(alt: Float::NAN) }
    assert_match(/Altitude/, error.message)
  end

  def test_constructor_rejects_infinity_alt
    error = assert_raises(ArgumentError) { LLA.new(alt: Float::INFINITY) }
    assert_match(/Altitude/, error.message)
  end

  # ── NaN/Infinity validation in setters ─────────────────────

  def test_lat_setter_rejects_nan
    lla = LLA.new(lat: 47.0, lng: -122.0, alt: 100.0)
    error = assert_raises(ArgumentError) { lla.lat = Float::NAN }
    assert_match(/Latitude/, error.message)
    assert_in_delta 47.0, lla.lat, 1e-6
  end

  def test_lat_setter_rejects_infinity
    lla = LLA.new(lat: 47.0, lng: -122.0, alt: 100.0)
    error = assert_raises(ArgumentError) { lla.lat = Float::INFINITY }
    assert_match(/Latitude/, error.message)
    assert_in_delta 47.0, lla.lat, 1e-6
  end

  def test_lng_setter_rejects_nan
    lla = LLA.new(lat: 47.0, lng: -122.0, alt: 100.0)
    error = assert_raises(ArgumentError) { lla.lng = Float::NAN }
    assert_match(/Longitude/, error.message)
    assert_in_delta(-122.0, lla.lng, 1e-6)
  end

  def test_lng_setter_rejects_infinity
    lla = LLA.new(lat: 47.0, lng: -122.0, alt: 100.0)
    error = assert_raises(ArgumentError) { lla.lng = Float::INFINITY }
    assert_match(/Longitude/, error.message)
    assert_in_delta(-122.0, lla.lng, 1e-6)
  end

  def test_alt_setter_rejects_nan
    lla = LLA.new(lat: 47.0, lng: -122.0, alt: 100.0)
    error = assert_raises(ArgumentError) { lla.alt = Float::NAN }
    assert_match(/Altitude/, error.message)
    assert_in_delta 100.0, lla.alt, 1e-6
  end

  def test_alt_setter_rejects_infinity
    lla = LLA.new(lat: 47.0, lng: -122.0, alt: 100.0)
    error = assert_raises(ArgumentError) { lla.alt = Float::INFINITY }
    assert_match(/Altitude/, error.message)
    assert_in_delta 100.0, lla.alt, 1e-6
  end

  # ── to_gh36 / from_gh36 ───────────────────────────────────

  GH36 = Geodetic::Coordinate::GH36

  def test_to_gh36_returns_gh36_instance
    lla = LLA.new(lat: 37.7749, lng: -122.4194, alt: 15.0)
    gh36 = lla.to_gh36
    assert_instance_of GH36, gh36
  end

  def test_to_gh36_with_precision
    lla = LLA.new(lat: 37.7749, lng: -122.4194, alt: 15.0)
    gh36 = lla.to_gh36(precision: 6)
    assert_instance_of GH36, gh36
  end

  def test_gh36_roundtrip
    original = LLA.new(lat: 37.7749, lng: -122.4194, alt: 0.0)
    gh36 = original.to_gh36(precision: 10)
    restored = LLA.from_gh36(gh36)
    assert_in_delta original.lat, restored.lat, 1e-4
    assert_in_delta original.lng, restored.lng, 1e-4
  end

  # ── from_ecef with invalid argument ────────────────────────

  def test_from_ecef_rejects_non_ecef
    assert_raises(ArgumentError) { LLA.from_ecef("not an ECEF") }
  end

  def test_from_ecef_rejects_lla
    lla = LLA.new(lat: 47.0, lng: -122.0, alt: 0.0)
    assert_raises(ArgumentError) { LLA.from_ecef(lla) }
  end

  # ── from_utm with invalid argument ─────────────────────────

  def test_from_utm_rejects_non_utm
    assert_raises(ArgumentError) { LLA.from_utm("not a UTM") }
  end

  def test_from_utm_rejects_lla
    lla = LLA.new(lat: 47.0, lng: -122.0, alt: 0.0)
    assert_raises(ArgumentError) { LLA.from_utm(lla) }
  end

  # ── from_enu with invalid arguments ────────────────────────

  def test_from_enu_rejects_non_enu
    ref = LLA.new(lat: 47.0, lng: -122.0, alt: 0.0)
    assert_raises(ArgumentError) { LLA.from_enu("not an ENU", ref) }
  end

  def test_from_enu_rejects_non_lla_reference
    enu = ENU.new(e: 100.0, n: 200.0, u: 50.0)
    assert_raises(ArgumentError) { LLA.from_enu(enu, "not an LLA") }
  end

  # ── from_ned with invalid arguments ────────────────────────

  def test_from_ned_rejects_non_ned
    ref = LLA.new(lat: 47.0, lng: -122.0, alt: 0.0)
    assert_raises(ArgumentError) { LLA.from_ned("not a NED", ref) }
  end

  def test_from_ned_rejects_non_lla_reference
    ned = NED.new(n: 200.0, e: 100.0, d: -50.0)
    assert_raises(ArgumentError) { LLA.from_ned(ned, "not an LLA") }
  end

  # ── to_enu with invalid reference ──────────────────────────

  def test_to_enu_rejects_non_lla_reference
    lla = LLA.new(lat: 47.0, lng: -122.0, alt: 100.0)
    assert_raises(ArgumentError) { lla.to_enu("not an LLA") }
  end

  def test_to_enu_rejects_ecef_reference
    lla = LLA.new(lat: 47.0, lng: -122.0, alt: 100.0)
    ecef = lla.to_ecef
    assert_raises(ArgumentError) { lla.to_enu(ecef) }
  end

  # ── to_ned with invalid reference ──────────────────────────

  def test_to_ned_rejects_non_lla_reference
    lla = LLA.new(lat: 47.0, lng: -122.0, alt: 100.0)
    assert_raises(ArgumentError) { lla.to_ned("not an LLA") }
  end

  def test_to_ned_rejects_ecef_reference
    lla = LLA.new(lat: 47.0, lng: -122.0, alt: 100.0)
    ecef = lla.to_ecef
    assert_raises(ArgumentError) { lla.to_ned(ecef) }
  end

  # ── from_dms with invalid format ───────────────────────────

  def test_from_dms_rejects_invalid_format
    assert_raises(ArgumentError) { LLA.from_dms("not a valid DMS string") }
  end

  def test_from_dms_rejects_empty_string
    assert_raises(ArgumentError) { LLA.from_dms("") }
  end

  def test_from_dms_rejects_partial_format
    assert_raises(ArgumentError) { LLA.from_dms("47° 37' 13.80\" N") }
  end

  # ── Southern hemisphere to_utm ─────────────────────────────

  def test_to_utm_southern_hemisphere
    lla = LLA.new(lat: -33.8688, lng: 151.2093, alt: 50.0)
    utm = lla.to_utm
    assert_instance_of UTM, utm
    assert_equal "S", utm.hemisphere
    assert_in_delta 50.0, utm.altitude, 1e-6
    assert utm.easting > 0, "Easting should be positive"
    assert utm.northing > 0, "Northing should be positive"
    # Southern hemisphere adds 10_000_000 false northing
    assert utm.northing > 5_000_000, "Southern hemisphere northing should include false northing offset"
  end

  def test_to_utm_southern_hemisphere_roundtrip
    original = LLA.new(lat: -33.8688, lng: 151.2093, alt: 50.0)
    utm = original.to_utm
    restored = LLA.from_utm(utm)
    assert_in_delta original.lat, restored.lat, 1e-4
    assert_in_delta original.lng, restored.lng, 1e-4
    assert_in_delta original.alt, restored.alt, 1e-4
  end

  # ── to_s altitude precision capping ────────────────────────

  def test_to_s_caps_altitude_precision_at_2
    coord = LLA.new(lat: 47.6205, lng: -122.3493, alt: 184.123456)
    # With precision=6, lat/lng get 6 decimals but alt is capped at 2
    result = coord.to_s(6)
    parts = result.split(", ")
    assert_equal 6, parts[0].split(".")[1].length  # lat has 6 decimals
    assert_equal 6, parts[1].split(".")[1].length  # lng has 6 decimals
    assert_equal 2, parts[2].split(".")[1].length  # alt capped at 2
  end

  def test_to_s_precision_1_caps_altitude_at_1
    coord = LLA.new(lat: 47.6205, lng: -122.3493, alt: 184.123456)
    # With precision=1, alt precision is min(1, 2) = 1
    result = coord.to_s(1)
    parts = result.split(", ")
    assert_equal 1, parts[0].split(".")[1].length  # lat has 1 decimal
    assert_equal 1, parts[1].split(".")[1].length  # lng has 1 decimal
    assert_equal 1, parts[2].split(".")[1].length  # alt gets min(1, 2) = 1
  end

  def test_to_s_precision_10_still_caps_altitude_at_2
    coord = LLA.new(lat: 47.6205, lng: -122.3493, alt: 184.123456)
    result = coord.to_s(10)
    parts = result.split(", ")
    assert_equal 10, parts[0].split(".")[1].length  # lat has 10 decimals
    assert_equal 10, parts[1].split(".")[1].length  # lng has 10 decimals
    assert_equal 2, parts[2].split(".")[1].length   # alt still capped at 2
  end
end
