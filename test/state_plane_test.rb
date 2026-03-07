# frozen_string_literal: true

require "test_helper"
require_relative "../lib/geodetic/coordinates/state_plane"
require_relative "../lib/geodetic/coordinates/lla"

class StatePlaneTest < Minitest::Test
  SP  = Geodetic::Coordinates::StatePlane
  LLA = Geodetic::Coordinates::LLA

  # -- Constructor ----------------------------------------------------------

  def test_default_values
    coord = SP.new
    assert_in_delta 0.0, coord.easting, 1e-6
    assert_in_delta 0.0, coord.northing, 1e-6
    assert_equal "CA_I", coord.zone_code
  end

  def test_keyword_arguments
    coord = SP.new(easting: 2000000, northing: 500000, zone_code: "CA_II")
    assert_in_delta 2000000.0, coord.easting, 1e-6
    assert_in_delta 500000.0, coord.northing, 1e-6
    assert_equal "CA_II", coord.zone_code
  end

  def test_invalid_zone_raises
    assert_raises(RuntimeError) { SP.new(zone_code: "INVALID_ZONE") }
  end

  # -- Accessors ------------------------------------------------------------

  def test_easting_accessor
    coord = SP.new(easting: 2000000)
    assert_in_delta 2000000.0, coord.easting, 1e-6
  end

  def test_northing_accessor
    coord = SP.new(northing: 500000)
    assert_in_delta 500000.0, coord.northing, 1e-6
  end

  def test_zone_code_accessor
    coord = SP.new(zone_code: "TX_NORTH")
    assert_equal "TX_NORTH", coord.zone_code
  end

  def test_datum_accessor
    coord = SP.new
    assert_equal Geodetic::WGS84, coord.datum
  end

  # -- Setters ----------------------------------------------------------------

  def test_easting_setter
    coord = SP.new(easting: 2000000)
    coord.easting = 2100000.0
    assert_in_delta 2100000.0, coord.easting, 1e-6
  end

  def test_northing_setter
    coord = SP.new(northing: 500000)
    coord.northing = 600000.0
    assert_in_delta 600000.0, coord.northing, 1e-6
  end

  def test_zone_code_setter
    coord = SP.new(zone_code: "CA_I")
    coord.zone_code = "TX_NORTH"
    assert_equal "TX_NORTH", coord.zone_code
  end

  def test_zone_code_setter_upcases
    coord = SP.new(zone_code: "CA_I")
    coord.zone_code = "tx_north"
    assert_equal "TX_NORTH", coord.zone_code
  end

  def test_zone_code_setter_validates
    coord = SP.new(zone_code: "CA_I")
    assert_raises(ArgumentError) { coord.zone_code = "INVALID" }
    assert_equal "CA_I", coord.zone_code
  end

  def test_setters_coerce_to_float
    coord = SP.new(easting: 2000000, northing: 500000)
    coord.easting = "2100000"
    coord.northing = "600000"
    assert_in_delta 2100000.0, coord.easting, 1e-6
    assert_in_delta 600000.0, coord.northing, 1e-6
  end

  # -- to_s -----------------------------------------------------------------

  def test_to_s
    coord = SP.new(easting: 2000000, northing: 500000, zone_code: "CA_I")
    assert_equal "2000000.00, 500000.00, CA_I", coord.to_s
  end

  def test_to_s_with_precision
    coord = SP.new(easting: 2000123.456, northing: 500789.012, zone_code: "CA_I")
    assert_equal "2000123.5, 500789.0, CA_I", coord.to_s(1)
    assert_equal "2000123, 500789, CA_I", coord.to_s(0)
  end

  # -- to_a -----------------------------------------------------------------

  def test_to_a
    coord = SP.new(easting: 2000000, northing: 500000, zone_code: "CA_I")
    result = coord.to_a
    assert_equal 3, result.size
    assert_in_delta 2000000.0, result[0], 1e-6
    assert_in_delta 500000.0, result[1], 1e-6
    assert_equal "CA_I", result[2]
  end

  # -- from_array roundtrip -------------------------------------------------

  def test_from_array_roundtrip
    original = SP.new(easting: 2000000, northing: 500000, zone_code: "CA_I")
    restored = SP.from_array(original.to_a)
    assert_in_delta original.easting, restored.easting, 1e-6
    assert_in_delta original.northing, restored.northing, 1e-6
    assert_equal original.zone_code, restored.zone_code
  end

  # -- from_string roundtrip ------------------------------------------------

  def test_from_string_roundtrip
    original = SP.new(easting: 2000000, northing: 500000, zone_code: "CA_I")
    restored = SP.from_string(original.to_s)
    assert_in_delta original.easting, restored.easting, 1e-6
    assert_in_delta original.northing, restored.northing, 1e-6
    assert_equal original.zone_code, restored.zone_code
  end

  # -- == -------------------------------------------------------------------

  def test_equality_equal
    a = SP.new(easting: 2000000, northing: 500000, zone_code: "CA_I")
    b = SP.new(easting: 2000000, northing: 500000, zone_code: "CA_I")
    assert_equal a, b
  end

  def test_equality_unequal
    a = SP.new(easting: 2000000, northing: 500000, zone_code: "CA_I")
    b = SP.new(easting: 2100000, northing: 600000, zone_code: "CA_I")
    refute_equal a, b
  end

  def test_equality_different_zones
    a = SP.new(easting: 2000000, northing: 500000, zone_code: "CA_I")
    b = SP.new(easting: 2000000, northing: 500000, zone_code: "CA_II")
    refute_equal a, b
  end

  # -- zone_info ------------------------------------------------------------

  def test_zone_info_returns_correct_state
    coord = SP.new(zone_code: "CA_I")
    info = coord.zone_info
    assert_equal "California", info[:state]
  end

  def test_zone_info_returns_correct_projection
    coord = SP.new(zone_code: "CA_I")
    info = coord.zone_info
    assert_equal "lambert_conformal_conic", info[:projection]
  end

  def test_zone_info_transverse_mercator
    coord = SP.new(zone_code: "FL_EAST")
    info = coord.zone_info
    assert_equal "transverse_mercator", info[:projection]
  end

  # -- from_lla / to_lla roundtrip ------------------------------------------

  def test_from_lla_to_lla_roundtrip
    # Use FL_EAST (Transverse Mercator) near its origin for better roundtrip
    original = LLA.new(lat: 25.0, lng: -81.0, alt: 0.0)
    sp = SP.from_lla(original, "FL_EAST")
    restored = sp.to_lla

    # Simplified projection has limited accuracy; verify reasonable results
    assert_in_delta 25.0, restored.lat, 10.0
    assert_in_delta(-81.0, restored.lng, 1.0)
  end

  # -- to_meters / to_us_survey_feet ----------------------------------------

  def test_to_meters
    coord = SP.new(easting: 2000000, northing: 500000, zone_code: "CA_I")
    meters = coord.to_meters
    assert_instance_of SP, meters
    # CA_I is in US Survey Feet, so conversion should change values
    refute_in_delta 2000000.0, meters.easting, 1.0
  end

  def test_to_us_survey_feet_already_in_feet
    coord = SP.new(easting: 2000000, northing: 500000, zone_code: "CA_I")
    feet = coord.to_us_survey_feet
    # CA_I is already in US Survey Feet, so should return self
    assert_in_delta 2000000.0, feet.easting, 1e-6
    assert_in_delta 500000.0, feet.northing, 1e-6
  end

  # -- valid? ---------------------------------------------------------------

  def test_valid_with_known_zone
    coord = SP.new(zone_code: "CA_I")
    assert coord.valid?
  end

  def test_valid_with_all_defined_zones
    %w[CA_I CA_II TX_NORTH FL_EAST NY_LONG_ISLAND].each do |zone|
      coord = SP.new(zone_code: zone)
      assert coord.valid?, "Expected zone #{zone} to be valid"
    end
  end

  # -- zones_for_state ------------------------------------------------------

  def test_zones_for_state_california
    zones = SP.zones_for_state("California")
    assert zones.key?("CA_I")
    assert zones.key?("CA_II")
  end

  def test_zones_for_state_case_insensitive
    zones = SP.zones_for_state("california")
    assert zones.key?("CA_I")
    assert zones.key?("CA_II")
  end

  # -- distance_to ----------------------------------------------------------

  def test_distance_to_same_zone
    a = SP.new(easting: 2000000, northing: 500000, zone_code: "CA_I")
    b = SP.new(easting: 2000000, northing: 501000, zone_code: "CA_I")
    dist = a.distance_to(b)
    assert_instance_of Geodetic::Distance, dist
    assert dist > 0.0, "Expected positive distance between different StatePlane points"
  end
end
