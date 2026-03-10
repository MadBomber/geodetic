# frozen_string_literal: true

require "test_helper"

class PathTest < Minitest::Test
  LLA      = Geodetic::Coordinate::LLA
  Path     = Geodetic::Path
  Distance = Geodetic::Distance

  def setup
    @a = LLA.new(lat: 40.6892, lng: -74.0445, alt: 0)  # Statue of Liberty
    @b = LLA.new(lat: 40.7061, lng: -73.9969, alt: 0)  # Brooklyn Bridge
    @c = LLA.new(lat: 40.7484, lng: -73.9857, alt: 0)  # Empire State
    @d = LLA.new(lat: 40.7580, lng: -73.9855, alt: 0)  # Times Square
    @e = LLA.new(lat: 40.7829, lng: -73.9654, alt: 0)  # Central Park
  end

  # ── Construction ──────────────────────────────────────────────

  def test_empty_path
    path = Path.new
    assert path.empty?
    assert_equal 0, path.size
    assert_nil path.first
    assert_nil path.last
  end

  def test_new_from_array
    path = Path.new(coordinates: [@a, @b, @c])
    assert_equal 3, path.size
    assert_equal @a, path.first
    assert_equal @c, path.last
  end

  def test_new_raises_on_duplicate
    assert_raises(ArgumentError) do
      Path.new(coordinates: [@a, @b, @a])
    end
  end

  def test_single_coordinate
    path = Path.new(coordinates: [@a])
    assert_equal 1, path.size
    assert_equal @a, path.first
    assert_equal @a, path.last
  end

  # ── Navigation ────────────────────────────────────────────────

  def test_next
    path = Path.new(coordinates: [@a, @b, @c])
    assert_equal @b, path.next(@a)
    assert_equal @c, path.next(@b)
    assert_nil path.next(@c)
  end

  def test_prev
    path = Path.new(coordinates: [@a, @b, @c])
    assert_nil path.prev(@a)
    assert_equal @a, path.prev(@b)
    assert_equal @b, path.prev(@c)
  end

  def test_next_raises_for_missing_coordinate
    path = Path.new(coordinates: [@a, @b])
    assert_raises(ArgumentError) { path.next(@c) }
  end

  def test_prev_raises_for_missing_coordinate
    path = Path.new(coordinates: [@a, @b])
    assert_raises(ArgumentError) { path.prev(@c) }
  end

  def test_segments
    path = Path.new(coordinates: [@a, @b, @c])
    segs = path.segments
    assert_equal 2, segs.size
    assert_kind_of Geodetic::Segment, segs[0]
    assert_equal @a, segs[0].start_point
    assert_equal @b, segs[0].end_point
    assert_equal @b, segs[1].start_point
    assert_equal @c, segs[1].end_point
  end

  def test_segments_empty_path
    path = Path.new
    assert_equal [], path.segments
  end

  def test_segments_single_coordinate
    path = Path.new(coordinates: [@a])
    assert_equal [], path.segments
  end

  def test_include
    path = Path.new(coordinates: [@a, @b])
    assert path.include?(@a)
    assert path.include?(@b)
    refute path.include?(@c)
  end

  # ── Containment (on segment) ───────────────────────────────

  def test_contains_waypoint
    path = Path.new(coordinates: [@a, @b, @c])
    assert path.contains?(@b)
  end

  def test_contains_point_on_segment
    path = Path.new(coordinates: [@a, @b])

    # Midpoint between Statue of Liberty and Brooklyn Bridge
    mid_lat = (@a.lat + @b.lat) / 2.0
    mid_lng = (@a.lng + @b.lng) / 2.0
    midpoint = LLA.new(lat: mid_lat, lng: mid_lng, alt: 0)

    assert path.contains?(midpoint)
  end

  def test_contains_point_near_segment
    path = Path.new(coordinates: [@a, @b])

    # Point very close to the midpoint but slightly offset
    mid_lat = (@a.lat + @b.lat) / 2.0
    mid_lng = (@a.lng + @b.lng) / 2.0
    nearby = LLA.new(lat: mid_lat + 0.00001, lng: mid_lng, alt: 0)

    assert path.contains?(nearby)
  end

  def test_excludes_point_far_from_path
    path = Path.new(coordinates: [@a, @b])

    far_away = LLA.new(lat: 41.0, lng: -74.5, alt: 0)
    assert path.excludes?(far_away)
  end

  def test_excludes_point_beyond_segment_end
    path = Path.new(coordinates: [@b, @c])

    # Statue of Liberty is beyond Brooklyn Bridge, not between B and C
    assert path.excludes?(@a)
  end

  def test_contains_on_second_segment
    path = Path.new(coordinates: [@a, @b, @c])

    # Midpoint on second segment (Brooklyn Bridge to Empire State)
    mid_lat = (@b.lat + @c.lat) / 2.0
    mid_lng = (@b.lng + @c.lng) / 2.0
    midpoint = LLA.new(lat: mid_lat, lng: mid_lng, alt: 0)

    assert path.contains?(midpoint)
  end

  def test_contains_with_tight_tolerance
    path = Path.new(coordinates: [@a, @b])

    mid_lat = (@a.lat + @b.lat) / 2.0
    mid_lng = (@a.lng + @b.lng) / 2.0
    # Offset ~100m laterally
    offset = LLA.new(lat: mid_lat + 0.001, lng: mid_lng, alt: 0)

    # Should be outside with tight tolerance
    refute path.contains?(offset, tolerance: 1.0)
  end

  def test_contains_with_loose_tolerance
    path = Path.new(coordinates: [@a, @b])

    mid_lat = (@a.lat + @b.lat) / 2.0
    mid_lng = (@a.lng + @b.lng) / 2.0
    # Offset ~100m laterally
    offset = LLA.new(lat: mid_lat + 0.001, lng: mid_lng, alt: 0)

    # Should be inside with loose tolerance
    assert path.contains?(offset, tolerance: 500.0)
  end

  def test_inside_is_alias_for_contains
    path = Path.new(coordinates: [@a, @b])
    mid_lat = (@a.lat + @b.lat) / 2.0
    mid_lng = (@a.lng + @b.lng) / 2.0
    midpoint = LLA.new(lat: mid_lat, lng: mid_lng, alt: 0)

    assert path.inside?(midpoint)
  end

  def test_outside_is_alias_for_excludes
    path = Path.new(coordinates: [@a, @b])
    far_away = LLA.new(lat: 41.0, lng: -74.5, alt: 0)

    assert path.outside?(far_away)
  end

  def test_contains_empty_path
    path = Path.new
    refute path.contains?(@a)
  end

  def test_contains_single_waypoint_path
    path = Path.new(coordinates: [@a])
    assert path.contains?(@a)
    refute path.contains?(@b)
  end

  # ── Computed ──────────────────────────────────────────────────

  def test_reverse
    path = Path.new(coordinates: [@a, @b, @c])
    rev = path.reverse

    assert_equal @c, rev.first
    assert_equal @a, rev.last
    assert_equal [@c, @b, @a], rev.coordinates

    # original unchanged
    assert_equal @a, path.first
  end

  def test_total_distance
    path = Path.new(coordinates: [@a, @b, @c])
    total = path.total_distance

    assert_instance_of Distance, total

    expected = @a.distance_to(@b).meters + @b.distance_to(@c).meters
    assert_in_delta expected, total.meters, 1.0
  end

  def test_total_distance_empty_path
    path = Path.new
    assert_in_delta 0.0, path.total_distance.meters, 0.001
  end

  def test_segment_distances
    path = Path.new(coordinates: [@a, @b, @c])
    dists = path.segment_distances

    assert_equal 2, dists.size
    assert_instance_of Distance, dists[0]
    assert_in_delta @a.distance_to(@b).meters, dists[0].meters, 1.0
    assert_in_delta @b.distance_to(@c).meters, dists[1].meters, 1.0
  end

  def test_segment_bearings
    path = Path.new(coordinates: [@a, @b, @c])
    bearings = path.segment_bearings

    assert_equal 2, bearings.size
    assert_instance_of Geodetic::Bearing, bearings[0]
    assert_in_delta @a.bearing_to(@b).degrees, bearings[0].degrees, 0.01
    assert_in_delta @b.bearing_to(@c).degrees, bearings[1].degrees, 0.01
  end

  # ── Non-mutating: + ──────────────────────────────────────────

  def test_plus_returns_new_path
    path = Path.new(coordinates: [@a, @b])
    path2 = path + @c

    assert_equal 3, path2.size
    assert_equal @c, path2.last
    assert_equal 2, path.size  # original unchanged
  end

  def test_plus_chaining
    path = Path.new
    path2 = path + @a + @b + @c

    assert_equal 3, path2.size
    assert_equal @a, path2.first
    assert_equal @c, path2.last
    assert path.empty?  # original unchanged
  end

  def test_plus_raises_on_duplicate
    path = Path.new(coordinates: [@a, @b])
    assert_raises(ArgumentError) { path + @a }
  end

  # ── Non-mutating: - ──────────────────────────────────────────

  def test_minus_returns_new_path
    path = Path.new(coordinates: [@a, @b, @c])
    path2 = path - @b

    assert_equal 2, path2.size
    assert_equal [@a, @c], path2.coordinates
    assert_equal 3, path.size  # original unchanged
  end

  def test_minus_removes_first
    path = Path.new(coordinates: [@a, @b, @c])
    path2 = path - @a

    assert_equal 2, path2.size
    assert_equal @b, path2.first
  end

  def test_minus_removes_last
    path = Path.new(coordinates: [@a, @b, @c])
    path2 = path - @c

    assert_equal 2, path2.size
    assert_equal @b, path2.last
  end

  def test_minus_raises_for_missing
    path = Path.new(coordinates: [@a, @b])
    assert_raises(ArgumentError) { path - @c }
  end

  # ── Mutating: << ─────────────────────────────────────────────

  def test_shovel_appends
    path = Path.new
    path << @a << @b << @c

    assert_equal 3, path.size
    assert_equal @a, path.first
    assert_equal @c, path.last
  end

  def test_shovel_returns_self
    path = Path.new
    result = path << @a

    assert_same path, result
  end

  def test_shovel_raises_on_duplicate
    path = Path.new(coordinates: [@a])
    assert_raises(ArgumentError) { path << @a }
  end

  # ── Mutating: >> ─────────────────────────────────────────────

  def test_right_shift_prepends
    path = Path.new(coordinates: [@b, @c])
    path >> @a

    assert_equal 3, path.size
    assert_equal @a, path.first
  end

  def test_right_shift_returns_self
    path = Path.new
    result = path >> @a

    assert_same path, result
  end

  def test_right_shift_raises_on_duplicate
    path = Path.new(coordinates: [@a])
    assert_raises(ArgumentError) { path >> @a }
  end

  # ── Mutating: prepend ────────────────────────────────────────

  def test_prepend
    path = Path.new(coordinates: [@b, @c])
    path.prepend(@a)

    assert_equal @a, path.first
    assert_equal 3, path.size
  end

  def test_prepend_returns_self
    path = Path.new
    result = path.prepend(@a)

    assert_same path, result
  end

  def test_prepend_raises_on_duplicate
    path = Path.new(coordinates: [@a])
    assert_raises(ArgumentError) { path.prepend(@a) }
  end

  # ── Mutating: insert ─────────────────────────────────────────

  def test_insert_after
    path = Path.new(coordinates: [@a, @c])
    path.insert(@b, after: @a)

    assert_equal [@a, @b, @c], path.coordinates
  end

  def test_insert_before
    path = Path.new(coordinates: [@a, @c])
    path.insert(@b, before: @c)

    assert_equal [@a, @b, @c], path.coordinates
  end

  def test_insert_after_last
    path = Path.new(coordinates: [@a, @b])
    path.insert(@c, after: @b)

    assert_equal @c, path.last
  end

  def test_insert_before_first
    path = Path.new(coordinates: [@b, @c])
    path.insert(@a, before: @b)

    assert_equal @a, path.first
  end

  def test_insert_returns_self
    path = Path.new(coordinates: [@a, @c])
    result = path.insert(@b, after: @a)

    assert_same path, result
  end

  def test_insert_raises_on_duplicate
    path = Path.new(coordinates: [@a, @b])
    assert_raises(ArgumentError) { path.insert(@a, after: @b) }
  end

  def test_insert_raises_on_missing_reference
    path = Path.new(coordinates: [@a, @b])
    assert_raises(ArgumentError) { path.insert(@d, after: @c) }
  end

  def test_insert_raises_without_after_or_before
    path = Path.new(coordinates: [@a, @b])
    assert_raises(ArgumentError) { path.insert(@c) }
  end

  def test_insert_raises_with_both_after_and_before
    path = Path.new(coordinates: [@a, @c])
    assert_raises(ArgumentError) { path.insert(@b, after: @a, before: @c) }
  end

  # ── Mutating: delete / remove ────────────────────────────────

  def test_delete_middle
    path = Path.new(coordinates: [@a, @b, @c])
    path.delete(@b)

    assert_equal [@a, @c], path.coordinates
  end

  def test_delete_first
    path = Path.new(coordinates: [@a, @b, @c])
    path.delete(@a)

    assert_equal @b, path.first
  end

  def test_delete_last
    path = Path.new(coordinates: [@a, @b, @c])
    path.delete(@c)

    assert_equal @b, path.last
  end

  def test_delete_returns_self
    path = Path.new(coordinates: [@a, @b])
    result = path.delete(@a)

    assert_same path, result
  end

  def test_delete_raises_for_missing
    path = Path.new(coordinates: [@a, @b])
    assert_raises(ArgumentError) { path.delete(@c) }
  end

  def test_remove_is_alias_for_delete
    path = Path.new(coordinates: [@a, @b, @c])
    path.remove(@b)

    assert_equal [@a, @c], path.coordinates
  end

  def test_delete_to_empty
    path = Path.new(coordinates: [@a])
    path.delete(@a)

    assert path.empty?
  end

  # ── Display ──────────────────────────────────────────────────

  def test_to_s
    path = Path.new(coordinates: [@a, @b])
    str = path.to_s

    assert_includes str, "Path(2)"
    assert_includes str, "->"
  end

  def test_to_s_empty
    path = Path.new
    assert_includes path.to_s, "Path(0)"
  end

  def test_inspect
    path = Path.new(coordinates: [@a, @b])

    assert_includes path.inspect, "Geodetic::Path"
    assert_includes path.inspect, "size=2"
  end

  # ── Spatial: nearest_waypoint, distance_to, bearing_to ──────

  def test_nearest_waypoint
    path = Path.new(coordinates: [@a, @b, @c])

    # Empire State (@c) is closest to Times Square (@d)
    assert_equal @c, path.nearest_waypoint(@d)
  end

  def test_nearest_waypoint_exact_match
    path = Path.new(coordinates: [@a, @b, @c])
    assert_equal @b, path.nearest_waypoint(@b)
  end

  def test_nearest_waypoint_raises_on_empty
    path = Path.new
    assert_raises(ArgumentError) { path.nearest_waypoint(@a) }
  end

  def test_closest_coordinate_to_at_waypoint
    path = Path.new(coordinates: [@a, @b, @c])

    # Target is exactly a waypoint
    closest = path.closest_coordinate_to(@b)
    assert_in_delta 0.0, closest.distance_to(@b).meters, 1.0
  end

  def test_closest_coordinate_to_between_waypoints
    # Create a path where the closest approach is clearly mid-segment
    west  = LLA.new(lat: 40.75, lng: -74.05, alt: 0)
    east  = LLA.new(lat: 40.75, lng: -73.95, alt: 0)
    path  = Path.new(coordinates: [west, east])

    # Target is directly north of the segment midpoint
    target = LLA.new(lat: 40.76, lng: -74.00, alt: 0)

    closest = path.closest_coordinate_to(target)

    # Closest point should be near lng -74.00 (the midpoint longitude)
    assert_in_delta(-74.00, closest.lng, 0.001)

    # And closer than either endpoint
    assert closest.distance_to(target).meters < west.distance_to(target).meters
    assert closest.distance_to(target).meters < east.distance_to(target).meters
  end

  def test_closest_coordinate_to_improves_on_nearest_waypoint
    # Path with widely spaced waypoints
    south = LLA.new(lat: 40.70, lng: -74.00, alt: 0)
    north = LLA.new(lat: 40.80, lng: -74.00, alt: 0)
    path  = Path.new(coordinates: [south, north])

    # Target off to the side, midway along the segment
    target = LLA.new(lat: 40.75, lng: -73.98, alt: 0)

    waypoint_dist = path.nearest_waypoint(target).distance_to(target).meters
    closest_dist  = path.distance_to(target).meters

    # Bisection should find a closer point than either waypoint
    assert closest_dist < waypoint_dist
  end

  def test_distance_to_coordinate
    path = Path.new(coordinates: [@a, @b, @c])
    dist = path.distance_to(@d)

    assert_instance_of Distance, dist
    # Should be at least as close as nearest waypoint
    waypoint_dist = @c.distance_to(@d).meters
    assert dist.meters <= waypoint_dist + 1.0
  end

  def test_bearing_to_coordinate
    path = Path.new(coordinates: [@a, @b, @c])
    bearing = path.bearing_to(@d)

    assert_instance_of Geodetic::Bearing, bearing
  end

  def test_distance_to_feature
    path = Path.new(coordinates: [@a, @b, @c])
    feature = Geodetic::Feature.new(label: "Times Square", geometry: @d)

    dist = path.distance_to(feature)
    assert_instance_of Distance, dist
  end

  def test_distance_to_area
    path = Path.new(coordinates: [@a, @b, @c])
    center = LLA.new(lat: 40.7829, lng: -73.9654, alt: 0)
    circle = Geodetic::Areas::Circle.new(centroid: center, radius: 500)

    dist = path.distance_to(circle)
    assert_instance_of Distance, dist
  end

  def test_closest_coordinate_to_single_waypoint
    path = Path.new(coordinates: [@a])
    closest = path.closest_coordinate_to(@b)
    assert_equal @a, closest
  end

  def test_closest_coordinate_to_raises_on_empty
    path = Path.new
    assert_raises(ArgumentError) { path.closest_coordinate_to(@a) }
  end

  # ── Closest points to Area ─────────────────────────────────

  def test_closest_points_to_polygon
    # Path runs east-west, polygon is to the north
    west = LLA.new(lat: 40.70, lng: -74.01, alt: 0)
    east = LLA.new(lat: 40.70, lng: -73.98, alt: 0)
    path = Path.new(coordinates: [west, east])

    polygon = Geodetic::Areas::Polygon.new(boundary: [
      LLA.new(lat: 40.72, lng: -74.00, alt: 0),
      LLA.new(lat: 40.73, lng: -73.99, alt: 0),
      LLA.new(lat: 40.72, lng: -73.98, alt: 0),
    ])

    result = path.closest_points_to(polygon)

    assert result[:path_point], "should have a path_point"
    assert result[:area_point], "should have an area_point"
    assert_instance_of Distance, result[:distance]
    assert result[:distance].meters > 0

    # The closest pair should be closer than centroid-based distance
    centroid_dist = path.nearest_waypoint(polygon.centroid).distance_to(polygon.centroid).meters
    assert result[:distance].meters < centroid_dist
  end

  def test_closest_points_to_rectangle
    west = LLA.new(lat: 40.70, lng: -74.01, alt: 0)
    east = LLA.new(lat: 40.70, lng: -73.98, alt: 0)
    path = Path.new(coordinates: [west, east])

    rect = Geodetic::Areas::BoundingBox.new(
      nw: LLA.new(lat: 40.73, lng: -74.00),
      se: LLA.new(lat: 40.72, lng: -73.99)
    )

    result = path.closest_points_to(rect)

    assert result[:path_point]
    assert result[:area_point]
    assert_instance_of Distance, result[:distance]
    assert result[:distance].meters > 0
  end

  def test_closest_points_to_circle
    west = LLA.new(lat: 40.70, lng: -74.01, alt: 0)
    east = LLA.new(lat: 40.70, lng: -73.98, alt: 0)
    path = Path.new(coordinates: [west, east])

    center = LLA.new(lat: 40.72, lng: -73.995, alt: 0)
    circle = Geodetic::Areas::Circle.new(centroid: center, radius: 500)

    result = path.closest_points_to(circle)

    assert result[:path_point]
    assert result[:area_point]
    assert_instance_of Distance, result[:distance]

    # Distance should be less than distance to centroid minus radius
    centroid_dist = path.closest_coordinate_to(center).distance_to(center).meters
    assert result[:distance].meters < centroid_dist
  end

  def test_distance_to_polygon
    path = Path.new(coordinates: [@a, @b, @c])

    polygon = Geodetic::Areas::Polygon.new(boundary: [
      LLA.new(lat: 40.72, lng: -74.00, alt: 0),
      LLA.new(lat: 40.73, lng: -73.99, alt: 0),
      LLA.new(lat: 40.72, lng: -73.98, alt: 0),
    ])

    dist = path.distance_to(polygon)
    assert_instance_of Distance, dist

    # Should be closer than centroid-based distance
    centroid_dist = path.nearest_waypoint(polygon.centroid).distance_to(polygon.centroid)
    assert dist.meters <= centroid_dist.meters
  end

  def test_bearing_to_polygon
    path = Path.new(coordinates: [@a, @b, @c])

    polygon = Geodetic::Areas::Polygon.new(boundary: [
      LLA.new(lat: 40.72, lng: -74.00, alt: 0),
      LLA.new(lat: 40.73, lng: -73.99, alt: 0),
      LLA.new(lat: 40.72, lng: -73.98, alt: 0),
    ])

    bearing = path.bearing_to(polygon)
    assert_instance_of Geodetic::Bearing, bearing
  end

  def test_closest_points_to_via_feature
    path = Path.new(coordinates: [@a, @b, @c])

    polygon = Geodetic::Areas::Polygon.new(boundary: [
      LLA.new(lat: 40.72, lng: -74.00, alt: 0),
      LLA.new(lat: 40.73, lng: -73.99, alt: 0),
      LLA.new(lat: 40.72, lng: -73.98, alt: 0),
    ])

    feature = Geodetic::Feature.new(label: "Zone", geometry: polygon)

    result = path.closest_points_to(feature)
    assert result[:path_point]
    assert result[:area_point]
  end

  # ── Feature integration ──────────────────────────────────────

  def test_feature_with_path_geometry
    path = Path.new(coordinates: [@a, @b, @c])
    feature = Geodetic::Feature.new(
      label:    "Route",
      geometry: path,
      metadata: { type: "walking" }
    )

    assert_equal "Route", feature.label
    assert_equal path, feature.geometry
    assert_equal "walking", feature.metadata[:type]
  end

  def test_feature_distance_to_with_path_geometry
    path = Path.new(coordinates: [@a, @b, @c])
    route = Geodetic::Feature.new(label: "Route", geometry: path)
    target = Geodetic::Feature.new(label: "Times Square", geometry: @d)

    dist = route.distance_to(target)
    expected = @c.distance_to(@d)
    assert_in_delta expected.meters, dist.meters, 1.0
  end

  def test_feature_bearing_to_with_path_geometry
    path = Path.new(coordinates: [@a, @b, @c])
    route = Geodetic::Feature.new(label: "Route", geometry: path)
    target = Geodetic::Feature.new(label: "Times Square", geometry: @d)

    bearing = route.bearing_to(target)
    expected = @c.bearing_to(@d)
    assert_in_delta expected.degrees, bearing.degrees, 0.01
  end

  # ── Path-to-Path closest points ──────────────────────────────

  def test_closest_points_to_path
    path1 = Path.new(coordinates: [@a, @b])        # Statue of Liberty -> Brooklyn Bridge
    path2 = Path.new(coordinates: [@c, @d, @e])     # Empire State -> Times Square -> Central Park

    result = path1.closest_points_to(path2)

    assert result[:path_point], "should have a path_point"
    assert result[:area_point], "should have an area_point"
    assert_kind_of Distance, result[:distance]
    assert result[:distance].meters > 0
  end

  def test_closest_points_to_path_returns_close_points
    # Two parallel-ish paths — closest points should be nearer than the endpoints
    path1 = Path.new(coordinates: [@a, @b, @c])
    path2 = Path.new(coordinates: [@d, @e])

    result = path1.closest_points_to(path2)

    # The closest pair should be closer than @c to @d (the nearest endpoints)
    endpoint_dist = @c.distance_to(@d).meters
    assert result[:distance].meters <= endpoint_dist + 1.0
  end

  def test_closest_points_to_path_symmetric
    path1 = Path.new(coordinates: [@a, @b])
    path2 = Path.new(coordinates: [@d, @e])

    result1 = path1.closest_points_to(path2)
    result2 = path2.closest_points_to(path1)

    # Distances should be the same regardless of direction
    assert_in_delta result1[:distance].meters, result2[:distance].meters, 1.0
  end

  def test_distance_to_path
    path1 = Path.new(coordinates: [@a, @b])
    path2 = Path.new(coordinates: [@d, @e])

    dist = path1.distance_to(path2)
    assert_kind_of Distance, dist
    assert dist.meters > 0
  end

  def test_bearing_to_path
    path1 = Path.new(coordinates: [@a, @b])
    path2 = Path.new(coordinates: [@d, @e])

    bearing = path1.bearing_to(path2)
    assert_kind_of Geodetic::Bearing, bearing
    assert bearing.degrees >= 0
    assert bearing.degrees < 360
  end

  # ── Path + Path, << Path, >> Path ────────────────────────────

  def test_plus_path_concatenates
    p1 = Path.new(coordinates: [@a, @b])
    p2 = Path.new(coordinates: [@c, @d])

    p3 = p1 + p2

    assert_equal 4, p3.size
    assert_equal @a, p3.first
    assert_equal @d, p3.last
    # originals unchanged
    assert_equal 2, p1.size
    assert_equal 2, p2.size
  end

  def test_shovel_left_path_appends
    p1 = Path.new(coordinates: [@a, @b])
    p2 = Path.new(coordinates: [@c, @d])

    p1 << p2

    assert_equal 4, p1.size
    assert_equal @a, p1.first
    assert_equal @d, p1.last
  end

  def test_shovel_right_path_prepends
    p1 = Path.new(coordinates: [@c, @d])
    p2 = Path.new(coordinates: [@a, @b])

    p1 >> p2

    assert_equal 4, p1.size
    assert_equal @a, p1.first
    assert_equal @d, p1.last
  end

  def test_plus_path_raises_on_duplicate
    p1 = Path.new(coordinates: [@a, @b])
    p2 = Path.new(coordinates: [@b, @c])

    assert_raises(ArgumentError) { p1 + p2 }
  end

  def test_shovel_left_path_raises_on_duplicate
    p1 = Path.new(coordinates: [@a, @b])
    p2 = Path.new(coordinates: [@b, @c])

    assert_raises(ArgumentError) { p1 << p2 }
  end

  def test_shovel_right_path_raises_on_duplicate
    p1 = Path.new(coordinates: [@a, @b])
    p2 = Path.new(coordinates: [@b, @c])

    assert_raises(ArgumentError) { p1 >> p2 }
  end

  def test_prepend_path
    p1 = Path.new(coordinates: [@c, @d])
    p2 = Path.new(coordinates: [@a, @b])

    p1.prepend(p2)

    assert_equal 4, p1.size
    assert_equal @a, p1.first
    assert_equal @d, p1.last
  end

  def test_minus_path_removes_coordinates
    p1 = Path.new(coordinates: [@a, @b, @c, @d, @e])
    p2 = Path.new(coordinates: [@b, @d])

    p3 = p1 - p2

    assert_equal 3, p3.size
    assert_equal [@a, @c, @e], p3.coordinates
    # original unchanged
    assert_equal 5, p1.size
  end

  def test_minus_path_raises_if_coordinate_not_in_path
    p1 = Path.new(coordinates: [@a, @b])
    p2 = Path.new(coordinates: [@c, @d])

    assert_raises(ArgumentError) { p1 - p2 }
  end

  # ── Enumerable ───────────────────────────────────────────────

  def test_each_iterates_coordinates
    path = Path.new(coordinates: [@a, @b, @c])
    collected = []
    path.each { |c| collected << c }
    assert_equal [@a, @b, @c], collected
  end

  def test_enumerable_map
    path = Path.new(coordinates: [@a, @b, @c])
    lats = path.map { |c| c.lat }
    assert_equal [@a.lat, @b.lat, @c.lat], lats
  end

  def test_enumerable_to_a
    path = Path.new(coordinates: [@a, @b, @c])
    assert_equal [@a, @b, @c], path.to_a
  end

  # ── Equality ─────────────────────────────────────────────────

  def test_equality_same_coordinates
    p1 = Path.new(coordinates: [@a, @b, @c])
    p2 = Path.new(coordinates: [@a, @b, @c])
    assert_equal p1, p2
  end

  def test_equality_different_order
    p1 = Path.new(coordinates: [@a, @b, @c])
    p2 = Path.new(coordinates: [@c, @b, @a])
    refute_equal p1, p2
  end

  def test_equality_different_size
    p1 = Path.new(coordinates: [@a, @b])
    p2 = Path.new(coordinates: [@a, @b, @c])
    refute_equal p1, p2
  end

  def test_equality_not_a_path
    path = Path.new(coordinates: [@a, @b])
    refute_equal path, [@a, @b]
  end

  # ── Between ──────────────────────────────────────────────────

  def test_between_extracts_subpath
    path = Path.new(coordinates: [@a, @b, @c, @d, @e])
    sub = path.between(@b, @d)

    assert_equal 3, sub.size
    assert_equal @b, sub.first
    assert_equal @d, sub.last
    assert sub.include?(@c)
  end

  def test_between_single_point
    path = Path.new(coordinates: [@a, @b, @c])
    sub = path.between(@b, @b)

    assert_equal 1, sub.size
    assert_equal @b, sub.first
  end

  def test_between_raises_if_from_after_to
    path = Path.new(coordinates: [@a, @b, @c])
    assert_raises(ArgumentError) { path.between(@c, @a) }
  end

  def test_between_raises_if_not_in_path
    path = Path.new(coordinates: [@a, @b])
    assert_raises(ArgumentError) { path.between(@a, @c) }
  end

  # ── Split ────────────────────────────────────────────────────

  def test_split_at_returns_two_paths
    path = Path.new(coordinates: [@a, @b, @c, @d, @e])
    left, right = path.split_at(@c)

    assert_equal 3, left.size
    assert_equal @a, left.first
    assert_equal @c, left.last

    assert_equal 3, right.size
    assert_equal @c, right.first
    assert_equal @e, right.last
  end

  def test_split_at_start
    path = Path.new(coordinates: [@a, @b, @c])
    left, right = path.split_at(@a)

    assert_equal 1, left.size
    assert_equal 3, right.size
  end

  def test_split_at_end
    path = Path.new(coordinates: [@a, @b, @c])
    left, right = path.split_at(@c)

    assert_equal 3, left.size
    assert_equal 1, right.size
  end

  def test_split_at_raises_if_not_in_path
    path = Path.new(coordinates: [@a, @b])
    assert_raises(ArgumentError) { path.split_at(@c) }
  end

  # ── Interpolate (at_distance) ────────────────────────────────

  def test_at_distance_zero_returns_first
    path = Path.new(coordinates: [@a, @b, @c])
    result = path.at_distance(Distance.new(0))
    assert_in_delta @a.lat, result.lat, 1e-6
    assert_in_delta @a.lng, result.lng, 1e-6
  end

  def test_at_distance_total_returns_last
    path = Path.new(coordinates: [@a, @b, @c])
    result = path.at_distance(path.total_distance)
    assert_in_delta @c.lat, result.lat, 1e-6
    assert_in_delta @c.lng, result.lng, 1e-6
  end

  def test_at_distance_beyond_total_returns_last
    path = Path.new(coordinates: [@a, @b, @c])
    result = path.at_distance(Distance.new(999_999))
    assert_in_delta @c.lat, result.lat, 1e-6
    assert_in_delta @c.lng, result.lng, 1e-6
  end

  def test_at_distance_midpoint
    path = Path.new(coordinates: [@a, @b])
    half = Distance.new(path.total_distance.meters / 2.0)
    mid = path.at_distance(half)

    dist_a = @a.distance_to(mid).meters
    dist_b = mid.distance_to(@b).meters
    assert_in_delta dist_a, dist_b, 1.0
  end

  def test_at_distance_negative_raises
    path = Path.new(coordinates: [@a, @b])
    assert_raises(ArgumentError) { path.at_distance(Distance.new(-1)) }
  end

  def test_at_distance_empty_raises
    path = Path.new
    assert_raises(ArgumentError) { path.at_distance(Distance.new(100)) }
  end

  # ── Bounds ───────────────────────────────────────────────────

  def test_bounds_returns_rectangle
    path = Path.new(coordinates: [@a, @b, @c, @d, @e])
    rect = path.bounds

    assert_kind_of Geodetic::Areas::BoundingBox, rect

    lats = [@a, @b, @c, @d, @e].map(&:lat)
    lngs = [@a, @b, @c, @d, @e].map(&:lng)

    assert_in_delta lats.max, rect.nw.lat, 1e-6
    assert_in_delta lngs.min, rect.nw.lng, 1e-6
    assert_in_delta lats.min, rect.se.lat, 1e-6
    assert_in_delta lngs.max, rect.se.lng, 1e-6
  end

  def test_bounds_empty_raises
    path = Path.new
    assert_raises(ArgumentError) { path.bounds }
  end

  # ── to_polygon ───────────────────────────────────────────────

  def test_to_polygon_returns_polygon
    path = Path.new(coordinates: [@a, @b, @c])
    poly = path.to_polygon

    assert_kind_of Geodetic::Areas::Polygon, poly
    assert poly.boundary.length >= 3
  end

  def test_to_polygon_raises_with_fewer_than_3
    path = Path.new(coordinates: [@a, @b])
    assert_raises(ArgumentError) { path.to_polygon }
  end

  def test_to_polygon_raises_when_closing_intersects
    # Create a path shaped like a figure-8 where closing would cross
    # Points arranged so closing last→first crosses an interior segment
    nw = LLA.new(lat: 40.76, lng: -74.01, alt: 0)
    se = LLA.new(lat: 40.70, lng: -73.97, alt: 0)
    ne = LLA.new(lat: 40.76, lng: -73.97, alt: 0)
    sw = LLA.new(lat: 40.70, lng: -74.01, alt: 0)

    # nw → se → ne → sw: closing sw→nw won't cross, but
    # nw → se → sw → ne: closing ne→nw is fine, but
    # nw → ne → sw → se: closing se→nw crosses ne→sw
    path = Path.new(coordinates: [nw, ne, sw, se])
    assert_raises(ArgumentError) { path.to_polygon }
  end

  # ── Intersects ───────────────────────────────────────────────

  def test_intersects_crossing_paths
    # Path going SW to NE
    sw = LLA.new(lat: 40.70, lng: -74.01, alt: 0)
    ne = LLA.new(lat: 40.76, lng: -73.97, alt: 0)
    # Path going NW to SE (crosses the first)
    nw = LLA.new(lat: 40.76, lng: -74.01, alt: 0)
    se = LLA.new(lat: 40.70, lng: -73.97, alt: 0)

    p1 = Path.new(coordinates: [sw, ne])
    p2 = Path.new(coordinates: [nw, se])

    assert p1.intersects?(p2)
  end

  def test_intersects_parallel_paths
    a1 = LLA.new(lat: 40.70, lng: -74.01, alt: 0)
    b1 = LLA.new(lat: 40.76, lng: -74.01, alt: 0)
    a2 = LLA.new(lat: 40.70, lng: -74.00, alt: 0)
    b2 = LLA.new(lat: 40.76, lng: -74.00, alt: 0)

    p1 = Path.new(coordinates: [a1, b1])
    p2 = Path.new(coordinates: [a2, b2])

    refute p1.intersects?(p2)
  end

  def test_intersects_non_overlapping
    p1 = Path.new(coordinates: [@a, @b])
    p2 = Path.new(coordinates: [@d, @e])

    refute p1.intersects?(p2)
  end

  def test_intersects_raises_for_non_path
    path = Path.new(coordinates: [@a, @b])
    assert_raises(ArgumentError) { path.intersects?(@c) }
  end

  # ── to_corridor ──────────────────────────────────────────────

  def test_to_corridor_returns_polygon
    path = Path.new(coordinates: [@a, @b, @c])
    corridor = path.to_corridor(width: 100)
    assert_instance_of Geodetic::Areas::Polygon, corridor
  end

  def test_to_corridor_has_correct_vertex_count
    path = Path.new(coordinates: [@a, @b, @c])
    corridor = path.to_corridor(width: 100)
    # 3 left + 3 right = 6 input points + 1 closing point = 7
    assert_equal 7, corridor.boundary.size
  end

  def test_to_corridor_accepts_distance_object
    path = Path.new(coordinates: [@a, @b])
    corridor = path.to_corridor(width: Distance.new(200))
    assert_instance_of Geodetic::Areas::Polygon, corridor
  end

  def test_to_corridor_encloses_interior_points
    path = Path.new(coordinates: [@a, @b, @c])
    corridor = path.to_corridor(width: 1000)
    # Interior path points should be inside the corridor
    assert corridor.includes?(@b), "corridor should contain interior point"
  end

  def test_to_corridor_too_few_points_raises
    path = Path.new(coordinates: [@a])
    assert_raises(ArgumentError) { path.to_corridor(width: 100) }
  end
end
