# frozen_string_literal: true

require "test_helper"

class CoordinatesTest < Minitest::Test
  LLA  = Geodetic::Coordinate::LLA
  ECEF = Geodetic::Coordinate::ECEF
  ENU  = Geodetic::Coordinate::ENU
  NED  = Geodetic::Coordinate::NED
  UTM  = Geodetic::Coordinate::UTM

  SEATTLE = LLA.new(lat: 47.6205, lng: -122.3493, alt: 184.0)
  SF      = LLA.new(lat: 37.7749, lng: -122.4194, alt: 0.0)
  NYC     = LLA.new(lat: 40.7128, lng: -74.0060, alt: 0.0)

  # --- Geodetic::Coordinate.distance_between ---

  def test_distance_between_two_points_returns_distance
    dist = Geodetic::Coordinate.distance_between(SEATTLE, SF)
    assert_instance_of Geodetic::Distance, dist
    assert dist > 0.0
  end

  def test_distance_between_three_points_returns_array
    result = Geodetic::Coordinate.distance_between(SEATTLE, SF, NYC)
    assert_instance_of Array, result
    assert_equal 2, result.length
    result.each { |d| assert_instance_of Geodetic::Distance, d }
  end

  def test_distance_between_fewer_than_two_raises
    assert_raises(ArgumentError) { Geodetic::Coordinate.distance_between(SEATTLE) }
  end

  # --- Geodetic::Coordinate.straight_line_distance_between ---

  def test_straight_line_distance_between_two_points_returns_distance
    dist = Geodetic::Coordinate.straight_line_distance_between(SEATTLE, SF)
    assert_instance_of Geodetic::Distance, dist
    assert dist > 0.0
  end

  def test_straight_line_distance_between_three_points_returns_array
    result = Geodetic::Coordinate.straight_line_distance_between(SEATTLE, SF, NYC)
    assert_instance_of Array, result
    assert_equal 2, result.length
    result.each { |d| assert_instance_of Geodetic::Distance, d }
  end

  def test_straight_line_distance_between_fewer_than_two_raises
    assert_raises(ArgumentError) { Geodetic::Coordinate.straight_line_distance_between(SEATTLE) }
  end

  # --- Geodetic::Coordinate.bearing_between ---

  def test_bearing_between_two_points_returns_bearing
    bearing = Geodetic::Coordinate.bearing_between(SEATTLE, SF)
    assert_instance_of Geodetic::Bearing, bearing
  end

  def test_bearing_between_three_points_returns_array
    result = Geodetic::Coordinate.bearing_between(SEATTLE, SF, NYC)
    assert_instance_of Array, result
    assert_equal 2, result.length
    result.each { |b| assert_instance_of Geodetic::Bearing, b }
  end

  def test_bearing_between_fewer_than_two_raises
    assert_raises(ArgumentError) { Geodetic::Coordinate.bearing_between(SEATTLE) }
  end

  # --- ENU/NED raise ArgumentError for distance/bearing ---

  def test_distance_to_with_enu_raises
    enu = ENU.new(e: 100.0, n: 200.0, u: 50.0)
    assert_raises(ArgumentError) { SEATTLE.distance_to(enu) }
  end

  def test_straight_line_distance_to_with_ned_raises
    ned = NED.new(n: 200.0, e: 100.0, d: -50.0)
    assert_raises(ArgumentError) { SEATTLE.straight_line_distance_to(ned) }
  end

  def test_bearing_to_with_enu_raises
    enu = ENU.new(e: 100.0, n: 200.0, u: 50.0)
    assert_raises(ArgumentError) { SEATTLE.bearing_to(enu) }
  end

  # --- elevation_to across different coordinate types ---

  def test_elevation_to_across_types
    utm = SF.to_utm
    elevation = SEATTLE.elevation_to(utm)
    assert_kind_of Numeric, elevation
    # Seattle is higher altitude than SF (184m vs 0m), so elevation should be negative
    # (target is below observer) at long distance, but the angle depends on curvature
    assert elevation.is_a?(Float)
  end

  # --- distance_to with multiple targets ---

  def test_distance_to_with_multiple_targets_returns_array
    result = SEATTLE.distance_to(SF, NYC)
    assert_instance_of Array, result
    assert_equal 2, result.length
    result.each { |d| assert_instance_of Geodetic::Distance, d }
  end

  # --- straight_line_distance_to with multiple targets ---

  def test_straight_line_distance_to_with_multiple_targets_returns_array
    result = SEATTLE.straight_line_distance_to(SF, NYC)
    assert_instance_of Array, result
    assert_equal 2, result.length
    result.each { |d| assert_instance_of Geodetic::Distance, d }
  end
end
