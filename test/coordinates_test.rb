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

  # --- Arithmetic: + returns Segment ---

  def test_plus_two_lla_returns_segment
    seg = SEATTLE + SF
    assert_instance_of Geodetic::Segment, seg
    assert_equal SEATTLE, seg.start_point
    assert_equal SF, seg.end_point
  end

  def test_plus_mixed_coordinate_types_returns_segment
    utm = SF.to_utm
    seg = SEATTLE + utm
    assert_instance_of Geodetic::Segment, seg
    # Segment converts to LLA internally
    assert_in_delta SF.lat, seg.end_point.lat, 1e-4
    assert_in_delta SF.lng, seg.end_point.lng, 1e-4
  end

  def test_plus_from_non_lla_coordinate
    ecef = SEATTLE.to_ecef
    seg = ecef + SF
    assert_instance_of Geodetic::Segment, seg
    assert_in_delta SEATTLE.lat, seg.start_point.lat, 1e-4
  end

  # --- Arithmetic: P1 + P2 + P3 returns Path ---

  def test_segment_plus_coordinate_returns_path
    seg = SEATTLE + SF
    path = seg + NYC
    assert_instance_of Geodetic::Path, path
    assert_equal 3, path.size
  end

  def test_chained_plus_returns_path
    path = SEATTLE + SF + NYC
    assert_instance_of Geodetic::Path, path
    assert_equal 3, path.size
    assert_equal SEATTLE, path.first
    assert_equal NYC, path.last
  end

  def test_chained_plus_four_points_returns_path
    dc = LLA.new(lat: 38.9072, lng: -77.0369, alt: 0)
    path = SEATTLE + SF + NYC + dc
    assert_instance_of Geodetic::Path, path
    assert_equal 4, path.size
  end

  # --- Arithmetic: Coordinate + Segment returns Path ---

  def test_coordinate_plus_segment_returns_path
    seg = Geodetic::Segment.new(SF, NYC)
    path = SEATTLE + seg
    assert_instance_of Geodetic::Path, path
    assert_equal 3, path.size
    assert_equal SEATTLE, path.first
    assert_equal NYC, path.last
  end

  # --- Arithmetic: Segment + Segment returns Path ---

  def test_segment_plus_segment_returns_path
    seg1 = Geodetic::Segment.new(SEATTLE, SF)
    seg2 = Geodetic::Segment.new(NYC, LLA.new(lat: 38.9072, lng: -77.0369, alt: 0))
    path = seg1 + seg2
    assert_instance_of Geodetic::Path, path
    assert_equal 4, path.size
  end

  # --- Arithmetic: Coordinate + Distance returns Circle ---

  def test_coordinate_plus_distance_returns_circle
    radius = Geodetic::Distance.new(5000)
    circle = SEATTLE + radius
    assert_instance_of Geodetic::Areas::Circle, circle
    assert_equal SEATTLE, circle.centroid
    assert_in_delta 5000.0, circle.radius, 1e-6
  end

  def test_coordinate_plus_distance_with_unit_conversion
    radius = Geodetic::Distance.new(1000)
    circle = SF + radius
    assert_instance_of Geodetic::Areas::Circle, circle
    assert_in_delta 1000.0, circle.radius, 1e-6
  end

  def test_non_lla_coordinate_plus_distance_returns_circle
    ecef = SEATTLE.to_ecef
    radius = Geodetic::Distance.new(500)
    circle = ecef + radius
    assert_instance_of Geodetic::Areas::Circle, circle
  end

  # --- Arithmetic: Coordinate + Vector returns Segment ---

  def test_coordinate_plus_vector_returns_segment
    v = Geodetic::Vector.new(distance: 10_000, bearing: 90.0)
    seg = SEATTLE + v
    assert_instance_of Geodetic::Segment, seg
    assert_equal SEATTLE, seg.start_point
    assert_in_delta 10_000, seg.length_meters, 1.0
  end

  def test_coordinate_plus_vector_bearing_preserved
    v = Geodetic::Vector.new(distance: 50_000, bearing: 45.0)
    seg = SF + v
    assert_instance_of Geodetic::Segment, seg
    assert_in_delta 45.0, seg.bearing.degrees, 0.2
  end

  # --- Arithmetic: Segment + Vector returns Path ---

  def test_segment_plus_vector_returns_path
    seg = SEATTLE + SF
    v = Geodetic::Vector.new(distance: 50_000, bearing: 90.0)
    path = seg + v
    assert_instance_of Geodetic::Path, path
    assert_equal 3, path.size
    assert_equal SEATTLE, path.first
  end

  def test_segment_plus_vector_extends_from_endpoint
    seg = SEATTLE + SF
    v = Geodetic::Vector.new(distance: 10_000, bearing: 90.0)
    path = seg + v
    # Last point should be east of SF
    assert path.last.lng > SF.lng
  end

  # --- Arithmetic: Vector + Segment returns Path ---

  def test_vector_plus_segment_returns_path
    v = Geodetic::Vector.new(distance: 50_000, bearing: 90.0)
    seg = SEATTLE + SF
    path = v + seg
    assert_instance_of Geodetic::Path, path
    assert_equal 3, path.size
    assert_equal SEATTLE, path.coordinates[1]
    assert_equal SF, path.last
  end

  def test_vector_plus_segment_prepends_via_reverse
    v = Geodetic::Vector.new(distance: 10_000, bearing: 90.0)
    seg = SEATTLE + SF
    path = v + seg
    # First point should be west of Seattle (reversed 90° = 270° = west)
    assert path.first.lng < SEATTLE.lng
  end

  # --- Arithmetic: Path + Vector returns Path ---

  def test_path_plus_vector_returns_path
    path = SEATTLE + SF + NYC
    v = Geodetic::Vector.new(distance: 50_000, bearing: 180.0)
    path2 = path + v
    assert_instance_of Geodetic::Path, path2
    assert_equal 4, path2.size
    assert_equal SEATTLE, path2.first
    # Last point should be south of NYC
    assert path2.last.lat < NYC.lat
  end

  # --- Arithmetic: Vector + Coordinate returns Segment ---

  def test_vector_plus_coordinate_returns_segment
    v = Geodetic::Vector.new(distance: 10_000, bearing: 90.0)
    seg = v + SEATTLE
    assert_instance_of Geodetic::Segment, seg
    assert_equal SEATTLE, seg.end_point
    # Start point should be west of Seattle (reversed 90° = west)
    assert seg.start_point.lng < SEATTLE.lng
  end

  def test_vector_plus_coordinate_distance_preserved
    v = Geodetic::Vector.new(distance: 10_000, bearing: 0.0)
    seg = v + SF
    assert_in_delta 10_000, seg.length_meters, 1.0
  end

  # --- Arithmetic: Distance + Coordinate returns Circle ---

  def test_distance_plus_coordinate_returns_circle
    radius = Geodetic::Distance.new(5000)
    circle = radius + SEATTLE
    assert_instance_of Geodetic::Areas::Circle, circle
    assert_equal SEATTLE, circle.centroid
    assert_in_delta 5000.0, circle.radius, 1e-6
  end

  # --- Translation: * and translate/shift ---

  def test_coordinate_times_vector_returns_coordinate
    v = Geodetic::Vector.new(distance: 10_000, bearing: 0.0)
    p2 = SEATTLE * v
    assert_kind_of LLA, p2
    assert p2.lat > SEATTLE.lat
    assert_in_delta 10_000, SEATTLE.distance_to(p2).meters, 1.0
  end

  def test_coordinate_translate_alias
    v = Geodetic::Vector.new(distance: 10_000, bearing: 90.0)
    p2 = SEATTLE.translate(v)
    assert_kind_of LLA, p2
    assert p2.lng > SEATTLE.lng
  end

  def test_segment_times_vector
    seg = Geodetic::Segment.new(SEATTLE, SF)
    v = Geodetic::Vector.new(distance: 100_000, bearing: 90.0)
    shifted = seg * v
    assert_instance_of Geodetic::Segment, shifted
    # Both endpoints should have moved east
    assert shifted.start_point.lng > SEATTLE.lng
    assert shifted.end_point.lng > SF.lng
    # Length should be preserved
    assert_in_delta seg.length_meters, shifted.length_meters, 100
  end

  def test_path_times_vector
    path = SEATTLE + SF + NYC
    v = Geodetic::Vector.new(distance: 50_000, bearing: 0.0)
    shifted = path * v
    assert_instance_of Geodetic::Path, shifted
    assert_equal 3, shifted.size
    # All points should have moved north
    shifted.each_with_index do |pt, i|
      assert pt.lat > path.coordinates[i].lat
    end
  end

  def test_circle_times_vector
    circle = Geodetic::Areas::Circle.new(centroid: SEATTLE, radius: 5000)
    v = Geodetic::Vector.new(distance: 10_000, bearing: 180.0)
    shifted = circle * v
    assert_instance_of Geodetic::Areas::Circle, shifted
    assert_in_delta 5000.0, shifted.radius, 1e-6
    assert shifted.centroid.lat < SEATTLE.lat
  end

  def test_polygon_times_vector
    a = LLA.new(lat: 40.0, lng: -74.0, alt: 0)
    b = LLA.new(lat: 40.0, lng: -73.0, alt: 0)
    c = LLA.new(lat: 41.0, lng: -73.5, alt: 0)
    poly = Geodetic::Areas::Polygon.new(boundary: [a, b, c])
    v = Geodetic::Vector.new(distance: 100_000, bearing: 0.0)
    shifted = poly * v
    assert_instance_of Geodetic::Areas::Polygon, shifted
    # All vertices should have moved north (excluding closing point)
    shifted.boundary[0...-1].each_with_index do |pt, i|
      assert pt.lat > poly.boundary[i].lat
    end
  end

  def test_coordinate_times_non_vector_raises
    assert_raises(ArgumentError) { SEATTLE * 5 }
  end
end
