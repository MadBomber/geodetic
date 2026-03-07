# frozen_string_literal: true

require "test_helper"
require "geodetic/coordinates/lla"
require "geodetic/coordinates/ecef"
require "geodetic/coordinates/utm"
require "geodetic/coordinates/enu"
require "geodetic/coordinates/ned"

class LlaTest < Minitest::Test
  LLA  = Geodetic::Coordinates::LLA
  ECEF = Geodetic::Coordinates::ECEF
  UTM  = Geodetic::Coordinates::UTM
  ENU  = Geodetic::Coordinates::ENU
  NED  = Geodetic::Coordinates::NED

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

  def test_alt_altitude_alias
    coord = LLA.new(alt: 184.0)
    assert_equal coord.alt, coord.altitude
  end

  # ── to_s ─────────────────────────────────────────────────────

  def test_to_s
    coord = LLA.new(lat: 47.6205, lng: -122.3493, alt: 184.0)
    assert_equal "47.6205, -122.3493, 184.0", coord.to_s
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

  # -- heading_to -----------------------------------------------------------

  def test_heading_to_due_north
    a = LLA.new(lat: 0.0, lng: 0.0)
    b = LLA.new(lat: 1.0, lng: 0.0)
    assert_in_delta 0.0, a.heading_to(b), 0.01
  end

  def test_heading_to_due_east
    a = LLA.new(lat: 0.0, lng: 0.0)
    b = LLA.new(lat: 0.0, lng: 1.0)
    assert_in_delta 90.0, a.heading_to(b), 0.01
  end

  def test_heading_to_due_south
    a = LLA.new(lat: 1.0, lng: 0.0)
    b = LLA.new(lat: 0.0, lng: 0.0)
    assert_in_delta 180.0, a.heading_to(b), 0.01
  end

  def test_heading_to_due_west
    a = LLA.new(lat: 0.0, lng: 0.0)
    b = LLA.new(lat: 0.0, lng: -1.0)
    assert_in_delta 270.0, a.heading_to(b), 0.01
  end

  def test_heading_to_returns_0_to_360
    a = LLA.new(lat: 47.6205, lng: -122.3493)
    b = LLA.new(lat: 45.5152, lng: -122.6784)
    heading = a.heading_to(b)
    assert heading >= 0.0 && heading < 360.0
  end

  def test_heading_to_raises_for_non_lla
    a = LLA.new(lat: 0.0, lng: 0.0)
    assert_raises(ArgumentError) { a.heading_to("not an LLA") }
  end

  # -- immutability ---------------------------------------------------------

  def test_attributes_are_read_only
    lla = LLA.new(lat: 47.0, lng: -122.0, alt: 100.0)
    assert_raises(NoMethodError) { lla.lat = 0.0 }
    assert_raises(NoMethodError) { lla.lng = 0.0 }
    assert_raises(NoMethodError) { lla.alt = 0.0 }
  end
end
