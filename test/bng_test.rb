# frozen_string_literal: true

require "test_helper"
require_relative "../lib/geodetic/coordinates/bng"
require_relative "../lib/geodetic/coordinates/lla"

class BngTest < Minitest::Test
  BNG = Geodetic::Coordinates::BNG
  LLA = Geodetic::Coordinates::LLA

  # -- Constructor from easting/northing ------------------------------------

  def test_constructor_from_easting_northing
    coord = BNG.new(easting: 530000, northing: 180000)
    assert_in_delta 530000.0, coord.easting, 1e-6
    assert_in_delta 180000.0, coord.northing, 1e-6
  end

  # -- Constructor from grid_ref --------------------------------------------

  def test_constructor_from_grid_ref
    coord = BNG.new(grid_ref: "JQ 300000 800000")
    assert_in_delta 530000.0, coord.easting, 1e-1
    assert_in_delta 180000.0, coord.northing, 1e-1
  end

  # -- Accessors ------------------------------------------------------------

  def test_easting_accessor
    coord = BNG.new(easting: 530000, northing: 180000)
    assert_in_delta 530000.0, coord.easting, 1e-6
  end

  def test_northing_accessor
    coord = BNG.new(easting: 530000, northing: 180000)
    assert_in_delta 180000.0, coord.northing, 1e-6
  end

  def test_grid_ref_accessor
    coord = BNG.new(easting: 530000, northing: 180000)
    assert_kind_of String, coord.grid_ref
  end

  # -- to_s -----------------------------------------------------------------

  def test_to_s
    coord = BNG.new(easting: 530000, northing: 180000)
    assert_equal "530000.0, 180000.0", coord.to_s
  end

  # -- to_a -----------------------------------------------------------------

  def test_to_a
    coord = BNG.new(easting: 530000, northing: 180000)
    result = coord.to_a
    assert_equal 2, result.size
    assert_in_delta 530000.0, result[0], 1e-6
    assert_in_delta 180000.0, result[1], 1e-6
  end

  # -- from_array roundtrip -------------------------------------------------

  def test_from_array_roundtrip
    original = BNG.new(easting: 530000, northing: 180000)
    restored = BNG.from_array(original.to_a)
    assert_in_delta original.easting, restored.easting, 1e-6
    assert_in_delta original.northing, restored.northing, 1e-6
  end

  # -- from_string roundtrip ------------------------------------------------

  def test_from_string_roundtrip
    original = BNG.new(easting: 530000, northing: 180000)
    restored = BNG.from_string(original.to_s)
    assert_in_delta original.easting, restored.easting, 1e-6
    assert_in_delta original.northing, restored.northing, 1e-6
  end

  # -- == -------------------------------------------------------------------

  def test_equality_equal
    a = BNG.new(easting: 530000, northing: 180000)
    b = BNG.new(easting: 530000, northing: 180000)
    assert_equal a, b
  end

  def test_equality_unequal
    a = BNG.new(easting: 530000, northing: 180000)
    b = BNG.new(easting: 540000, northing: 190000)
    refute_equal a, b
  end

  # -- to_grid_reference ---------------------------------------------------

  def test_to_grid_reference_precision_0
    coord = BNG.new(easting: 530000, northing: 180000)
    ref = coord.to_grid_reference(0)
    assert_equal 2, ref.length
    assert_match(/\A[A-Z]{2}\z/, ref)
  end

  def test_to_grid_reference_precision_6
    coord = BNG.new(easting: 530000, northing: 180000)
    ref = coord.to_grid_reference(6)
    assert_match(/\A[A-Z]{2}\s\d{6}\s\d{6}\z/, ref)
  end

  # -- from_lla / to_lla roundtrip ------------------------------------------

  def test_from_lla_to_lla_roundtrip
    london = LLA.new(lat: 51.5007, lng: -0.1246, alt: 0.0)
    bng = BNG.from_lla(london)
    restored = bng.to_lla

    assert_in_delta 51.5007, restored.lat, 0.1
    assert_in_delta(-0.1246, restored.lng, 0.1)
  end

  # -- valid? ---------------------------------------------------------------

  def test_valid_within_great_britain
    coord = BNG.new(easting: 530000, northing: 180000)
    assert coord.valid?
  end

  def test_valid_outside_great_britain
    coord = BNG.new(easting: 800000, northing: 180000)
    refute coord.valid?
  end

  # -- distance_to ----------------------------------------------------------

  def test_distance_to
    a = BNG.new(easting: 530000, northing: 180000)
    b = BNG.new(easting: 530000, northing: 181000)
    dist = a.distance_to(b)
    assert_instance_of Geodetic::Distance, dist
    assert dist > 0.0, "Expected positive distance between different BNG points"
  end

  # -- bearing_to -----------------------------------------------------------

  def test_bearing_to
    a = BNG.new(easting: 530000, northing: 180000)
    b = BNG.new(easting: 530000, northing: 181000)
    # Due north
    assert_in_delta 0.0, a.bearing_to(b), 1e-6
  end

  def test_bearing_to_east
    a = BNG.new(easting: 530000, northing: 180000)
    b = BNG.new(easting: 531000, northing: 180000)
    # Due east
    assert_in_delta 90.0, a.bearing_to(b), 1e-6
  end
end
