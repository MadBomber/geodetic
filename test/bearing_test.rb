# frozen_string_literal: true

require "test_helper"

class BearingTest < Minitest::Test
  Bearing = Geodetic::Bearing

  # ── Construction ──────────────────────────────────────────────

  def test_new_normalizes_to_0_360
    assert_in_delta 0.0, Bearing.new(0).degrees, 1e-10
    assert_in_delta 90.0, Bearing.new(90).degrees, 1e-10
    assert_in_delta 270.0, Bearing.new(-90).degrees, 1e-10
    assert_in_delta 180.0, Bearing.new(540).degrees, 1e-10
    assert_in_delta 0.0, Bearing.new(360).degrees, 1e-10
  end

  # ── to_f / to_i / to_s / inspect ─────────────────────────────

  def test_to_f
    assert_in_delta 45.0, Bearing.new(45).to_f, 1e-10
  end

  def test_to_i
    assert_equal 45, Bearing.new(45.7).to_i
  end

  def test_to_s_includes_degree_symbol
    assert_match(/°/, Bearing.new(90).to_s)
    assert_match(/90/, Bearing.new(90).to_s)
  end

  def test_inspect
    b = Bearing.new(45)
    assert_match(/Geodetic::Bearing/, b.inspect)
    assert_match(/45/, b.inspect)
  end

  # ── to_radians ───────────────────────────────────────────────

  def test_to_radians
    assert_in_delta Math::PI / 2, Bearing.new(90).to_radians, 1e-10
    assert_in_delta Math::PI, Bearing.new(180).to_radians, 1e-10
    assert_in_delta 0.0, Bearing.new(0).to_radians, 1e-10
  end

  # ── reverse ──────────────────────────────────────────────────

  def test_reverse
    assert_in_delta 180.0, Bearing.new(0).reverse.degrees, 1e-10
    assert_in_delta 0.0, Bearing.new(180).reverse.degrees, 1e-10
    assert_in_delta 270.0, Bearing.new(90).reverse.degrees, 1e-10
    assert_in_delta 135.0, Bearing.new(315).reverse.degrees, 1e-10
  end

  def test_reverse_returns_bearing
    assert_instance_of Bearing, Bearing.new(45).reverse
  end

  # ── to_compass ───────────────────────────────────────────────

  def test_to_compass_4_points
    assert_equal "N", Bearing.new(0).to_compass(points: 4)
    assert_equal "E", Bearing.new(90).to_compass(points: 4)
    assert_equal "S", Bearing.new(180).to_compass(points: 4)
    assert_equal "W", Bearing.new(270).to_compass(points: 4)
  end

  def test_to_compass_8_points
    assert_equal "N",  Bearing.new(0).to_compass(points: 8)
    assert_equal "NE", Bearing.new(45).to_compass(points: 8)
    assert_equal "E",  Bearing.new(90).to_compass(points: 8)
    assert_equal "SE", Bearing.new(135).to_compass(points: 8)
    assert_equal "SW", Bearing.new(225).to_compass(points: 8)
    assert_equal "NW", Bearing.new(315).to_compass(points: 8)
  end

  def test_to_compass_16_points
    assert_equal "N",   Bearing.new(0).to_compass(points: 16)
    assert_equal "NNE", Bearing.new(22.5).to_compass(points: 16)
    assert_equal "NE",  Bearing.new(45).to_compass(points: 16)
    assert_equal "ENE", Bearing.new(67.5).to_compass(points: 16)
    assert_equal "E",   Bearing.new(90).to_compass(points: 16)
    assert_equal "SSW", Bearing.new(202.5).to_compass(points: 16)
  end

  def test_to_compass_default_is_16
    assert_equal Bearing.new(45).to_compass(points: 16), Bearing.new(45).to_compass
  end

  def test_to_compass_invalid_points_raises
    assert_raises(ArgumentError) { Bearing.new(0).to_compass(points: 5) }
  end

  # ── Comparison ───────────────────────────────────────────────

  def test_equal_bearings
    assert_equal Bearing.new(90), Bearing.new(90)
  end

  def test_less_than
    assert Bearing.new(45) < Bearing.new(90)
  end

  def test_greater_than
    assert Bearing.new(270) > Bearing.new(90)
  end

  def test_compare_with_numeric
    assert Bearing.new(90) > 45
    assert Bearing.new(90) < 180
  end

  # ── Arithmetic ───────────────────────────────────────────────

  def test_subtract_two_bearings_returns_float
    result = Bearing.new(90) - Bearing.new(45)
    assert_instance_of Float, result
    assert_in_delta 45.0, result, 1e-10
  end

  def test_subtract_bearings_can_be_negative
    result = Bearing.new(45) - Bearing.new(90)
    assert_in_delta(-45.0, result, 1e-10)
  end

  def test_subtract_numeric_returns_bearing
    result = Bearing.new(90) - 45
    assert_instance_of Bearing, result
    assert_in_delta 45.0, result.degrees, 1e-10
  end

  def test_subtract_numeric_wraps
    result = Bearing.new(10) - 20
    assert_in_delta 350.0, result.degrees, 1e-10
  end

  def test_add_numeric_returns_bearing
    result = Bearing.new(90) + 45
    assert_instance_of Bearing, result
    assert_in_delta 135.0, result.degrees, 1e-10
  end

  def test_add_numeric_wraps
    result = Bearing.new(350) + 20
    assert_in_delta 10.0, result.degrees, 1e-10
  end

  def test_coerce_numeric_plus_bearing
    result = 10 + Bearing.new(90)
    assert_in_delta 100.0, result, 1e-10
  end

  # ── zero? ────────────────────────────────────────────────────

  def test_zero
    assert Bearing.new(0).zero?
    assert Bearing.new(360).zero?
    refute Bearing.new(1).zero?
  end

  # ── Integration with coordinate bearing_to ───────────────────

  def test_bearing_between_two_coordinates
    seattle  = GCS::LLA.new(lat: 47.6205, lng: -122.3493, alt: 0.0)
    portland = GCS::LLA.new(lat: 45.5152, lng: -122.6784, alt: 0.0)

    bearing = seattle.bearing_to(portland)
    assert_instance_of Bearing, bearing
    # Portland is south-southwest of Seattle
    assert bearing.degrees > 170 && bearing.degrees < 200
    assert_equal "S", bearing.to_compass(points: 4)
  end

  def test_bearing_between_class_method
    seattle  = GCS::LLA.new(lat: 47.6205, lng: -122.3493, alt: 0.0)
    portland = GCS::LLA.new(lat: 45.5152, lng: -122.6784, alt: 0.0)

    bearing = GCS.bearing_between(seattle, portland)
    assert_instance_of Bearing, bearing
  end

  def test_bearing_between_chain
    seattle  = GCS::LLA.new(lat: 47.6205, lng: -122.3493, alt: 0.0)
    portland = GCS::LLA.new(lat: 45.5152, lng: -122.6784, alt: 0.0)
    sf       = GCS::LLA.new(lat: 37.7749, lng: -122.4194, alt: 0.0)

    bearings = GCS.bearing_between(seattle, portland, sf)
    assert_instance_of Array, bearings
    assert_equal 2, bearings.length
    bearings.each { |b| assert_instance_of Bearing, b }
  end

  def test_cross_system_bearing
    seattle_lla = GCS::LLA.new(lat: 47.6205, lng: -122.3493, alt: 0.0)
    portland_utm = GCS::LLA.new(lat: 45.5152, lng: -122.6784, alt: 0.0).to_utm

    bearing = seattle_lla.bearing_to(portland_utm)
    assert_instance_of Bearing, bearing
  end

  def test_elevation_to
    a = GCS::LLA.new(lat: 47.6205, lng: -122.3493, alt: 0.0)
    b = GCS::LLA.new(lat: 47.6205, lng: -122.3493, alt: 5000.0)

    elev = a.elevation_to(b)
    assert_instance_of Float, elev
    assert elev > 80.0  # nearly straight up
  end
end
