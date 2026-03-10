# frozen_string_literal: true

require "test_helper"

class SegmentTest < Minitest::Test
  LLA = Geodetic::Coordinate::LLA

  def setup
    @a = LLA.new(lat: 40.7484, lng: -73.9857, alt: 0)
    @b = LLA.new(lat: 40.7580, lng: -73.9855, alt: 0)
    @seg = Geodetic::Segment.new(@a, @b)
  end

  # --- Construction ---

  def test_start_and_end_points
    assert_equal @a, @seg.start_point
    assert_equal @b, @seg.end_point
  end

  def test_accepts_non_lla_coordinates
    ecef = @a.to_ecef
    seg = Geodetic::Segment.new(ecef, @b)
    assert_kind_of LLA, seg.start_point
  end

  # --- Properties ---

  def test_length_returns_distance
    assert_kind_of Geodetic::Distance, @seg.length
    assert_operator @seg.length.meters, :>, 0
  end

  def test_length_meters
    assert_in_delta @seg.length.meters, @seg.length_meters, 1e-6
  end

  def test_bearing_returns_bearing
    assert_kind_of Geodetic::Bearing, @seg.bearing
  end

  def test_midpoint
    mid = @seg.midpoint
    assert_kind_of LLA, mid
    assert_in_delta (@a.lat + @b.lat) / 2.0, mid.lat, 1e-6
    assert_in_delta (@a.lng + @b.lng) / 2.0, mid.lng, 1e-6
  end

  # --- Geometry ---

  def test_reverse
    rev = @seg.reverse
    assert_equal @b, rev.start_point
    assert_equal @a, rev.end_point
  end

  def test_interpolate_zero
    pt = @seg.interpolate(0.0)
    assert_in_delta @a.lat, pt.lat, 1e-6
    assert_in_delta @a.lng, pt.lng, 1e-6
  end

  def test_interpolate_one
    pt = @seg.interpolate(1.0)
    assert_in_delta @b.lat, pt.lat, 1e-6
    assert_in_delta @b.lng, pt.lng, 1e-6
  end

  def test_interpolate_half_equals_midpoint
    half = @seg.interpolate(0.5)
    mid  = @seg.midpoint
    assert_in_delta mid.lat, half.lat, 1e-6
    assert_in_delta mid.lng, half.lng, 1e-6
  end

  # --- Projection ---

  def test_project_point_onto_segment
    # A point slightly east of the segment midpoint
    target = LLA.new(lat: (@a.lat + @b.lat) / 2.0, lng: -73.980, alt: 0)
    foot, dist = @seg.project(target)

    assert_kind_of LLA, foot
    assert_operator dist, :>, 0
    assert_operator dist, :<, target.distance_to(@a).meters
  end

  def test_project_returns_start_for_zero_length_segment
    seg = Geodetic::Segment.new(@a, @a)
    foot, dist = seg.project(@b)
    assert_equal @a, foot
    assert_in_delta @a.distance_to(@b).meters, dist, 1.0
  end

  def test_project_returns_start_when_target_is_start
    foot, dist = @seg.project(@a)
    assert_equal @a, foot
    assert_in_delta 0.0, dist, 1e-6
  end

  def test_project_clamps_before_start
    # Point far behind start
    behind = LLA.new(lat: 40.730, lng: -73.9857, alt: 0)
    foot, _dist = @seg.project(behind)
    assert_equal @a, foot
  end

  def test_project_clamps_past_end
    # Point far beyond end
    beyond = LLA.new(lat: 40.780, lng: -73.9855, alt: 0)
    foot, _dist = @seg.project(beyond)
    assert_equal @b, foot
  end

  # --- Includes (vertex check only) ---

  def test_includes_start_point
    assert @seg.includes?(@a)
  end

  def test_includes_end_point
    assert @seg.includes?(@b)
  end

  def test_includes_rejects_midpoint
    refute @seg.includes?(@seg.midpoint)
  end

  def test_includes_rejects_distant_point
    far = LLA.new(lat: 41.0, lng: -74.0, alt: 0)
    refute @seg.includes?(far)
  end

  # --- Contains (on-segment check) ---

  def test_contains_start_point
    assert @seg.contains?(@a)
  end

  def test_contains_end_point
    assert @seg.contains?(@b)
  end

  def test_contains_midpoint
    assert @seg.contains?(@seg.midpoint, tolerance: 1.0)
  end

  def test_excludes_distant_point
    far = LLA.new(lat: 41.0, lng: -74.0, alt: 0)
    refute @seg.contains?(far)
    assert @seg.excludes?(far)
  end

  # --- Intersection ---

  def test_intersects_crossing_segments
    c = LLA.new(lat: 40.750, lng: -73.990, alt: 0)
    d = LLA.new(lat: 40.750, lng: -73.980, alt: 0)
    other = Geodetic::Segment.new(c, d)

    assert @seg.intersects?(other)
  end

  def test_no_intersection_parallel_segments
    c = LLA.new(lat: 40.7484, lng: -73.980, alt: 0)
    d = LLA.new(lat: 40.7580, lng: -73.980, alt: 0)
    other = Geodetic::Segment.new(c, d)

    refute @seg.intersects?(other)
  end

  def test_no_intersection_disjoint_segments
    c = LLA.new(lat: 41.0, lng: -74.0, alt: 0)
    d = LLA.new(lat: 41.1, lng: -74.1, alt: 0)
    other = Geodetic::Segment.new(c, d)

    refute @seg.intersects?(other)
  end

  # --- Conversion ---

  def test_to_path
    path = @seg.to_path
    assert_kind_of Geodetic::Path, path
    assert_equal 2, path.size
    assert_equal @a, path.first
    assert_equal @b, path.last
  end

  def test_to_a
    arr = @seg.to_a
    assert_equal [@a, @b], arr
  end

  # --- Equality / Display ---

  def test_equality
    other = Geodetic::Segment.new(@a, @b)
    assert_equal @seg, other
  end

  def test_inequality_different_points
    other = Geodetic::Segment.new(@b, @a)
    refute_equal @seg, other
  end

  def test_inequality_non_segment
    refute_equal @seg, "not a segment"
  end

  def test_to_s
    s = @seg.to_s
    assert_match(/Segment\(/, s)
  end

  def test_inspect
    s = @seg.inspect
    assert_match(/Geodetic::Segment/, s)
    assert_match(/length=/, s)
  end

  # --- Caching ---

  def test_length_is_cached
    l1 = @seg.length
    l2 = @seg.length
    assert_same l1, l2
  end

  def test_bearing_is_cached
    b1 = @seg.bearing
    b2 = @seg.bearing
    assert_same b1, b2
  end

  def test_midpoint_is_cached
    m1 = @seg.midpoint
    m2 = @seg.midpoint
    assert_same m1, m2
  end
end
