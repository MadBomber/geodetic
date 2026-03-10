# frozen_string_literal: true

require "test_helper"

class VectorTest < Minitest::Test
  LLA = Geodetic::Coordinate::LLA

  SEATTLE = LLA.new(lat: 47.6205, lng: -122.3493, alt: 0.0)

  # --- Construction ---

  def test_accepts_distance_and_bearing_objects
    v = Geodetic::Vector.new(
      distance: Geodetic::Distance.new(1000),
      bearing:  Geodetic::Bearing.new(90.0)
    )
    assert_instance_of Geodetic::Distance, v.distance
    assert_instance_of Geodetic::Bearing, v.bearing
  end

  def test_coerces_numeric_distance_and_bearing
    v = Geodetic::Vector.new(distance: 1000, bearing: 90.0)
    assert_instance_of Geodetic::Distance, v.distance
    assert_instance_of Geodetic::Bearing, v.bearing
    assert_in_delta 1000.0, v.distance.meters, 1e-6
    assert_in_delta 90.0, v.bearing.degrees, 1e-6
  end

  # --- Components ---

  def test_north_component_due_north
    v = Geodetic::Vector.new(distance: 1000, bearing: 0.0)
    assert_in_delta 1000.0, v.north, 1e-6
    assert_in_delta 0.0, v.east, 1e-6
  end

  def test_east_component_due_east
    v = Geodetic::Vector.new(distance: 1000, bearing: 90.0)
    assert_in_delta 0.0, v.north, 1e-6
    assert_in_delta 1000.0, v.east, 1e-6
  end

  def test_components_at_45_degrees
    v = Geodetic::Vector.new(distance: 1000, bearing: 45.0)
    expected = 1000.0 * Math.cos(45 * Geodetic::RAD_PER_DEG)
    assert_in_delta expected, v.north, 1e-6
    assert_in_delta expected, v.east, 1e-6
  end

  # --- from_components ---

  def test_from_components_due_north
    v = Geodetic::Vector.from_components(north: 1000, east: 0)
    assert_in_delta 1000.0, v.distance.meters, 1e-6
    assert_in_delta 0.0, v.bearing.degrees, 1e-6
  end

  def test_from_components_due_east
    v = Geodetic::Vector.from_components(north: 0, east: 1000)
    assert_in_delta 1000.0, v.distance.meters, 1e-6
    assert_in_delta 90.0, v.bearing.degrees, 1e-6
  end

  def test_from_components_round_trip
    v = Geodetic::Vector.new(distance: 5000, bearing: 135.0)
    v2 = Geodetic::Vector.from_components(north: v.north, east: v.east)
    assert_in_delta v.distance.meters, v2.distance.meters, 1e-6
    assert_in_delta v.bearing.degrees, v2.bearing.degrees, 1e-6
  end

  # --- from_segment ---

  def test_from_segment
    a = LLA.new(lat: 40.0, lng: -74.0, alt: 0)
    b = LLA.new(lat: 41.0, lng: -74.0, alt: 0)
    seg = Geodetic::Segment.new(a, b)
    v = Geodetic::Vector.from_segment(seg)
    assert_in_delta seg.length_meters, v.distance.meters, 1e-6
    assert_in_delta seg.bearing.degrees, v.bearing.degrees, 1e-6
  end

  def test_segment_to_vector
    a = LLA.new(lat: 40.0, lng: -74.0, alt: 0)
    b = LLA.new(lat: 41.0, lng: -74.0, alt: 0)
    seg = Geodetic::Segment.new(a, b)
    v = seg.to_vector
    assert_instance_of Geodetic::Vector, v
    assert_in_delta seg.length_meters, v.distance.meters, 1e-6
  end

  # --- Addition ---

  def test_vector_plus_vector
    v1 = Geodetic::Vector.new(distance: 1000, bearing: 0.0)   # north
    v2 = Geodetic::Vector.new(distance: 1000, bearing: 90.0)  # east
    result = v1 + v2
    assert_instance_of Geodetic::Vector, result
    expected_dist = Math.sqrt(1000**2 + 1000**2)
    assert_in_delta expected_dist, result.distance.meters, 1e-6
    assert_in_delta 45.0, result.bearing.degrees, 1e-6
  end

  def test_vector_plus_opposite_vectors_cancel
    v1 = Geodetic::Vector.new(distance: 1000, bearing: 0.0)
    v2 = Geodetic::Vector.new(distance: 1000, bearing: 180.0)
    result = v1 + v2
    assert_in_delta 0.0, result.distance.meters, 1e-6
  end

  def test_vector_plus_non_vector_raises
    v = Geodetic::Vector.new(distance: 1000, bearing: 0.0)
    assert_raises(ArgumentError) { v + 5 }
  end

  # --- Subtraction ---

  def test_vector_minus_vector
    v1 = Geodetic::Vector.new(distance: 1000, bearing: 45.0)
    v2 = Geodetic::Vector.new(distance: 1000, bearing: 45.0)
    result = v1 - v2
    assert_in_delta 0.0, result.distance.meters, 1e-6
  end

  def test_vector_minus_different_vector
    v1 = Geodetic::Vector.new(distance: 1000, bearing: 0.0)   # north
    v2 = Geodetic::Vector.new(distance: 1000, bearing: 90.0)  # east
    result = v1 - v2
    expected_dist = Math.sqrt(1000**2 + 1000**2)
    assert_in_delta expected_dist, result.distance.meters, 1e-6
  end

  def test_vector_minus_non_vector_raises
    v = Geodetic::Vector.new(distance: 1000, bearing: 0.0)
    assert_raises(ArgumentError) { v - 5 }
  end

  # --- Scalar multiplication ---

  def test_vector_times_scalar
    v = Geodetic::Vector.new(distance: 1000, bearing: 45.0)
    result = v * 3
    assert_in_delta 3000.0, result.distance.meters, 1e-6
    assert_in_delta 45.0, result.bearing.degrees, 1e-6
  end

  def test_vector_times_negative_reverses_bearing
    v = Geodetic::Vector.new(distance: 1000, bearing: 45.0)
    result = v * -1
    assert_in_delta 1000.0, result.distance.meters, 1e-6
    assert_in_delta 225.0, result.bearing.degrees, 1e-6
  end

  def test_vector_times_zero
    v = Geodetic::Vector.new(distance: 1000, bearing: 90.0)
    result = v * 0
    assert_in_delta 0.0, result.distance.meters, 1e-6
  end

  def test_scalar_times_vector_via_coerce
    v = Geodetic::Vector.new(distance: 1000, bearing: 90.0)
    result = 2 * v
    assert_instance_of Geodetic::Vector, result
    assert_in_delta 2000.0, result.distance.meters, 1e-6
  end

  def test_vector_times_non_numeric_raises
    v = Geodetic::Vector.new(distance: 1000, bearing: 0.0)
    assert_raises(ArgumentError) { v * "foo" }
  end

  # --- Scalar division ---

  def test_vector_divided_by_scalar
    v = Geodetic::Vector.new(distance: 3000, bearing: 90.0)
    result = v / 3
    assert_in_delta 1000.0, result.distance.meters, 1e-6
    assert_in_delta 90.0, result.bearing.degrees, 1e-6
  end

  def test_vector_divided_by_negative_reverses
    v = Geodetic::Vector.new(distance: 1000, bearing: 0.0)
    result = v / -2
    assert_in_delta 500.0, result.distance.meters, 1e-6
    assert_in_delta 180.0, result.bearing.degrees, 1e-6
  end

  def test_vector_divided_by_zero_raises
    v = Geodetic::Vector.new(distance: 1000, bearing: 0.0)
    assert_raises(ZeroDivisionError) { v / 0 }
  end

  def test_vector_divided_by_non_numeric_raises
    v = Geodetic::Vector.new(distance: 1000, bearing: 0.0)
    assert_raises(ArgumentError) { v / "foo" }
  end

  # --- Unary minus / reverse ---

  def test_unary_minus
    v = Geodetic::Vector.new(distance: 1000, bearing: 45.0)
    result = -v
    assert_in_delta 1000.0, result.distance.meters, 1e-6
    assert_in_delta 225.0, result.bearing.degrees, 1e-6
  end

  def test_reverse
    v = Geodetic::Vector.new(distance: 1000, bearing: 270.0)
    result = v.reverse
    assert_in_delta 1000.0, result.distance.meters, 1e-6
    assert_in_delta 90.0, result.bearing.degrees, 1e-6
  end

  # --- Properties ---

  def test_magnitude
    v = Geodetic::Vector.new(distance: 5000, bearing: 0.0)
    assert_in_delta 5000.0, v.magnitude, 1e-6
  end

  def test_zero?
    v = Geodetic::Vector.new(distance: 0, bearing: 90.0)
    assert v.zero?
  end

  def test_not_zero?
    v = Geodetic::Vector.new(distance: 1, bearing: 0.0)
    refute v.zero?
  end

  def test_normalize
    v = Geodetic::Vector.new(distance: 5000, bearing: 135.0)
    n = v.normalize
    assert_in_delta 1.0, n.distance.meters, 1e-6
    assert_in_delta 135.0, n.bearing.degrees, 1e-6
  end

  def test_normalize_zero_vector
    v = Geodetic::Vector.new(distance: 0, bearing: 0.0)
    assert v.normalize.zero?
  end

  # --- Dot product ---

  def test_dot_parallel
    v = Geodetic::Vector.new(distance: 100, bearing: 0.0)
    assert_in_delta 10_000.0, v.dot(v), 1e-6
  end

  def test_dot_perpendicular
    v1 = Geodetic::Vector.new(distance: 100, bearing: 0.0)
    v2 = Geodetic::Vector.new(distance: 100, bearing: 90.0)
    assert_in_delta 0.0, v1.dot(v2), 1e-6
  end

  def test_dot_non_vector_raises
    v = Geodetic::Vector.new(distance: 100, bearing: 0.0)
    assert_raises(ArgumentError) { v.dot(5) }
  end

  # --- Cross product ---

  def test_cross_parallel
    v = Geodetic::Vector.new(distance: 100, bearing: 0.0)
    assert_in_delta 0.0, v.cross(v), 1e-6
  end

  def test_cross_perpendicular
    v1 = Geodetic::Vector.new(distance: 100, bearing: 0.0)
    v2 = Geodetic::Vector.new(distance: 100, bearing: 90.0)
    assert_in_delta 10_000.0, v1.cross(v2), 1e-6
  end

  def test_cross_non_vector_raises
    v = Geodetic::Vector.new(distance: 100, bearing: 0.0)
    assert_raises(ArgumentError) { v.cross(5) }
  end

  # --- angle_between ---

  def test_angle_between
    v1 = Geodetic::Vector.new(distance: 100, bearing: 0.0)
    v2 = Geodetic::Vector.new(distance: 100, bearing: 90.0)
    angle = v1.angle_between(v2)
    assert_instance_of Geodetic::Bearing, angle
    assert_in_delta 90.0, angle.degrees, 1e-6
  end

  # --- Comparable ---

  def test_comparable_less_than
    v1 = Geodetic::Vector.new(distance: 100, bearing: 0.0)
    v2 = Geodetic::Vector.new(distance: 200, bearing: 0.0)
    assert v1 < v2
  end

  def test_comparable_equal_magnitude
    v1 = Geodetic::Vector.new(distance: 100, bearing: 0.0)
    v2 = Geodetic::Vector.new(distance: 100, bearing: 90.0)
    assert_equal 0, v1 <=> v2
  end

  # --- Vincenty direct: destination_from ---

  def test_destination_due_north
    v = Geodetic::Vector.new(distance: 10_000, bearing: 0.0)
    dest = v.destination_from(SEATTLE)
    assert_instance_of LLA, dest
    assert dest.lat > SEATTLE.lat, "destination should be north"
    assert_in_delta SEATTLE.lng, dest.lng, 1e-4
  end

  def test_destination_due_east
    v = Geodetic::Vector.new(distance: 10_000, bearing: 90.0)
    dest = v.destination_from(SEATTLE)
    assert dest.lng > SEATTLE.lng, "destination should be east"
    assert_in_delta SEATTLE.lat, dest.lat, 0.01
  end

  def test_destination_round_trip
    v = Geodetic::Vector.new(distance: 50_000, bearing: 135.0)
    dest = v.destination_from(SEATTLE)
    actual_dist = SEATTLE.distance_to(dest).meters
    assert_in_delta 50_000, actual_dist, 1.0
  end

  def test_destination_from_non_lla
    ecef = SEATTLE.to_ecef
    v = Geodetic::Vector.new(distance: 5000, bearing: 45.0)
    dest = v.destination_from(ecef)
    assert_instance_of LLA, dest
  end

  def test_zero_distance_returns_origin
    v = Geodetic::Vector.new(distance: 0, bearing: 90.0)
    dest = v.destination_from(SEATTLE)
    assert_in_delta SEATTLE.lat, dest.lat, 1e-6
    assert_in_delta SEATTLE.lng, dest.lng, 1e-6
  end

  # --- Equality ---

  def test_equality
    a = Geodetic::Vector.new(distance: 1000, bearing: 45.0)
    b = Geodetic::Vector.new(distance: 1000, bearing: 45.0)
    assert_equal a, b
  end

  def test_inequality
    a = Geodetic::Vector.new(distance: 1000, bearing: 45.0)
    b = Geodetic::Vector.new(distance: 1000, bearing: 90.0)
    refute_equal a, b
  end

  # --- Display ---

  def test_to_s
    v = Geodetic::Vector.new(distance: 1000, bearing: 90.0)
    assert_match(/Vector/, v.to_s)
  end

  def test_inspect
    v = Geodetic::Vector.new(distance: 1000, bearing: 90.0)
    assert_match(/Geodetic::Vector/, v.inspect)
  end
end
