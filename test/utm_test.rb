# frozen_string_literal: true

require "test_helper"
require_relative "../lib/geodetic/coordinates/utm"
require_relative "../lib/geodetic/coordinates/lla"

class UtmTest < Minitest::Test
  UTM = Geodetic::Coordinates::UTM
  LLA = Geodetic::Coordinates::LLA

  # --- Constructor ---

  def test_default_constructor
    utm = UTM.new
    assert_in_delta 0.0, utm.easting, 1e-10
    assert_in_delta 0.0, utm.northing, 1e-10
    assert_in_delta 0.0, utm.altitude, 1e-10
    assert_equal 1, utm.zone
    assert_equal "N", utm.hemisphere
  end

  def test_keyword_args_constructor
    utm = UTM.new(easting: 500000.0, northing: 5000000.0, altitude: 100.0, zone: 10, hemisphere: 'N')
    assert_in_delta 500000.0, utm.easting, 1e-10
    assert_in_delta 5000000.0, utm.northing, 1e-10
    assert_in_delta 100.0, utm.altitude, 1e-10
    assert_equal 10, utm.zone
    assert_equal "N", utm.hemisphere
  end

  def test_validates_zone_too_low
    assert_raises(ArgumentError) { UTM.new(zone: 0) }
  end

  def test_validates_zone_too_high
    assert_raises(ArgumentError) { UTM.new(zone: 61) }
  end

  def test_validates_zone_boundaries
    assert UTM.new(zone: 1)
    assert UTM.new(zone: 60)
  end

  def test_validates_hemisphere_invalid
    assert_raises(ArgumentError) { UTM.new(hemisphere: 'X') }
  end

  def test_validates_hemisphere_n_and_s
    assert UTM.new(hemisphere: 'N')
    assert UTM.new(hemisphere: 'S')
  end

  def test_validates_hemisphere_case_insensitive
    utm = UTM.new(hemisphere: 'n')
    assert_equal "N", utm.hemisphere
  end

  def test_validates_easting_negative
    assert_raises(ArgumentError) { UTM.new(easting: -1.0) }
  end

  def test_validates_northing_negative
    assert_raises(ArgumentError) { UTM.new(northing: -1.0) }
  end

  # --- Accessors and aliases ---

  def test_easting_alias_x
    utm = UTM.new(easting: 500000.0)
    assert_in_delta 500000.0, utm.x, 1e-10
  end

  def test_northing_alias_y
    utm = UTM.new(northing: 5000000.0)
    assert_in_delta 5000000.0, utm.y, 1e-10
  end

  def test_altitude_alias_z
    utm = UTM.new(altitude: 100.0)
    assert_in_delta 100.0, utm.z, 1e-10
  end

  def test_zone_accessor
    utm = UTM.new(zone: 15)
    assert_equal 15, utm.zone
  end

  def test_hemisphere_accessor
    utm = UTM.new(hemisphere: 'S')
    assert_equal "S", utm.hemisphere
  end

  # --- to_s ---

  def test_to_s
    utm = UTM.new(easting: 500000.0, northing: 5000000.0, altitude: 100.0, zone: 10, hemisphere: 'N')
    assert_equal "500000.0, 5000000.0, 100.0, 10, N", utm.to_s
  end

  # --- to_a ---

  def test_to_a
    utm = UTM.new(easting: 500000.0, northing: 5000000.0, altitude: 100.0, zone: 10, hemisphere: 'N')
    assert_equal [500000.0, 5000000.0, 100.0, 10, "N"], utm.to_a
  end

  # --- from_array ---

  def test_from_array_roundtrip
    original = UTM.new(easting: 500000.0, northing: 5000000.0, altitude: 100.0, zone: 10, hemisphere: 'N')
    arr = original.to_a
    restored = UTM.from_array(arr)
    assert_equal original, restored
  end

  # --- from_string ---

  def test_from_string_roundtrip
    original = UTM.new(easting: 500000.0, northing: 5000000.0, altitude: 100.0, zone: 10, hemisphere: 'N')
    str = original.to_s
    restored = UTM.from_string(str)
    assert_equal original, restored
  end

  # --- == ---

  def test_equality_equal
    a = UTM.new(easting: 500000.0, northing: 5000000.0, altitude: 100.0, zone: 10, hemisphere: 'N')
    b = UTM.new(easting: 500000.0, northing: 5000000.0, altitude: 100.0, zone: 10, hemisphere: 'N')
    assert_equal a, b
  end

  def test_equality_unequal
    a = UTM.new(easting: 500000.0, northing: 5000000.0, altitude: 100.0, zone: 10, hemisphere: 'N')
    b = UTM.new(easting: 600000.0, northing: 5000000.0, altitude: 100.0, zone: 10, hemisphere: 'N')
    refute_equal a, b
  end

  def test_equality_different_zones
    a = UTM.new(easting: 500000.0, northing: 5000000.0, altitude: 100.0, zone: 10, hemisphere: 'N')
    b = UTM.new(easting: 500000.0, northing: 5000000.0, altitude: 100.0, zone: 11, hemisphere: 'N')
    refute_equal a, b
  end

  def test_equality_non_utm
    a = UTM.new(easting: 500000.0, northing: 5000000.0, altitude: 100.0, zone: 10, hemisphere: 'N')
    refute_equal a, "not a utm"
  end

  # --- to_lla roundtrip ---

  def test_to_lla_roundtrip
    # Create a UTM, convert to LLA, convert back to UTM
    # Use a known UTM point in zone 31N (near prime meridian, low latitude)
    utm_original = UTM.new(easting: 500000.0, northing: 0.0, altitude: 50.0, zone: 31, hemisphere: 'N')
    lla = utm_original.to_lla
    utm_back = lla.to_utm

    assert_in_delta utm_original.easting, utm_back.easting, 1.0
    assert_in_delta utm_original.northing, utm_back.northing, 1.0
    assert_in_delta utm_original.altitude, utm_back.altitude, 1.0
    assert_equal utm_original.zone, utm_back.zone
    assert_equal utm_original.hemisphere, utm_back.hemisphere
  end

  # --- same_zone? ---

  def test_same_zone_true
    a = UTM.new(easting: 500000.0, northing: 5000000.0, zone: 10, hemisphere: 'N')
    b = UTM.new(easting: 600000.0, northing: 5100000.0, zone: 10, hemisphere: 'N')
    assert a.same_zone?(b)
  end

  def test_same_zone_different_zone
    a = UTM.new(easting: 500000.0, northing: 5000000.0, zone: 10, hemisphere: 'N')
    b = UTM.new(easting: 500000.0, northing: 5000000.0, zone: 11, hemisphere: 'N')
    refute a.same_zone?(b)
  end

  def test_same_zone_different_hemisphere
    a = UTM.new(easting: 500000.0, northing: 5000000.0, zone: 10, hemisphere: 'N')
    b = UTM.new(easting: 500000.0, northing: 5000000.0, zone: 10, hemisphere: 'S')
    refute a.same_zone?(b)
  end

  # --- central_meridian ---

  def test_central_meridian_zone_1
    utm = UTM.new(zone: 1)
    assert_equal(-177, utm.central_meridian)
  end

  def test_central_meridian_zone_10
    utm = UTM.new(zone: 10)
    assert_equal(-123, utm.central_meridian)
  end

  def test_central_meridian_zone_31
    utm = UTM.new(zone: 31)
    assert_equal 3, utm.central_meridian
  end

  # --- distance_to ---

  def test_distance_to_same_zone
    a = UTM.new(easting: 500000.0, northing: 5000000.0, altitude: 0.0, zone: 10, hemisphere: 'N')
    b = UTM.new(easting: 500003.0, northing: 5000004.0, altitude: 0.0, zone: 10, hemisphere: 'N')
    assert_in_delta 5.0, a.distance_to(b), 1e-10
  end

  def test_distance_to_with_altitude
    a = UTM.new(easting: 500000.0, northing: 5000000.0, altitude: 0.0, zone: 10, hemisphere: 'N')
    b = UTM.new(easting: 500000.0, northing: 5000000.0, altitude: 100.0, zone: 10, hemisphere: 'N')
    assert_in_delta 100.0, a.distance_to(b), 1e-10
  end

  def test_distance_to_different_zone_raises
    a = UTM.new(easting: 500000.0, northing: 5000000.0, zone: 10, hemisphere: 'N')
    b = UTM.new(easting: 500000.0, northing: 5000000.0, zone: 11, hemisphere: 'N')
    assert_raises(ArgumentError) { a.distance_to(b) }
  end

  # --- horizontal_distance_to ---

  def test_horizontal_distance_to_same_zone
    a = UTM.new(easting: 500000.0, northing: 5000000.0, altitude: 0.0, zone: 10, hemisphere: 'N')
    b = UTM.new(easting: 500003.0, northing: 5000004.0, altitude: 999.0, zone: 10, hemisphere: 'N')
    # horizontal_distance ignores altitude
    assert_in_delta 5.0, a.horizontal_distance_to(b), 1e-10
  end

  def test_horizontal_distance_to_different_zone_raises
    a = UTM.new(easting: 500000.0, northing: 5000000.0, zone: 10, hemisphere: 'N')
    b = UTM.new(easting: 500000.0, northing: 5000000.0, zone: 11, hemisphere: 'N')
    assert_raises(ArgumentError) { a.horizontal_distance_to(b) }
  end
end
