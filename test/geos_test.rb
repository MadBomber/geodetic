# frozen_string_literal: true

require "test_helper"

class GeosTest < Minitest::Test
  LLA     = Geodetic::Coordinate::LLA
  Polygon = Geodetic::Areas::Polygon
  Path    = Geodetic::Path
  Segment = Geodetic::Segment
  Geos    = Geodetic::Geos

  def setup
    skip "libgeos_c not available" unless Geos.available?
  end

  # -- Availability -----------------------------------------------------------

  def test_available
    assert Geos.available?
  end

  # -- Predicates: contains? --------------------------------------------------

  def test_contains_point_inside_polygon
    polygon = make_unit_polygon
    inside  = LLA.new(lat: 0.5, lng: 0.5, alt: 0.0)

    assert Geos.contains?(polygon, inside)
  end

  def test_does_not_contain_point_outside_polygon
    polygon = make_unit_polygon
    outside = LLA.new(lat: 5.0, lng: 5.0, alt: 0.0)

    refute Geos.contains?(polygon, outside)
  end

  # -- Predicates: intersects? ------------------------------------------------

  def test_intersecting_segments
    seg1 = Segment.new(
      LLA.new(lat: 0.0, lng: 0.0, alt: 0.0),
      LLA.new(lat: 2.0, lng: 2.0, alt: 0.0)
    )
    seg2 = Segment.new(
      LLA.new(lat: 0.0, lng: 2.0, alt: 0.0),
      LLA.new(lat: 2.0, lng: 0.0, alt: 0.0)
    )

    assert Geos.intersects?(seg1, seg2)
  end

  def test_non_intersecting_segments
    seg1 = Segment.new(
      LLA.new(lat: 0.0, lng: 0.0, alt: 0.0),
      LLA.new(lat: 1.0, lng: 0.0, alt: 0.0)
    )
    seg2 = Segment.new(
      LLA.new(lat: 0.0, lng: 5.0, alt: 0.0),
      LLA.new(lat: 1.0, lng: 5.0, alt: 0.0)
    )

    refute Geos.intersects?(seg1, seg2)
  end

  def test_overlapping_polygons_intersect
    poly_a = make_unit_polygon
    poly_b = Polygon.new(boundary: [
      LLA.new(lat: 0.5, lng: 0.5, alt: 0.0),
      LLA.new(lat: 2.5, lng: 0.5, alt: 0.0),
      LLA.new(lat: 2.5, lng: 2.5, alt: 0.0),
      LLA.new(lat: 0.5, lng: 2.5, alt: 0.0),
    ])

    assert Geos.intersects?(poly_a, poly_b)
  end

  # -- Predicates: is_valid? --------------------------------------------------

  def test_valid_polygon
    assert Geos.is_valid?(make_unit_polygon)
  end

  def test_is_valid_reason_for_valid_polygon
    reason = Geos.is_valid_reason(make_unit_polygon)
    assert_equal "Valid Geometry", reason
  end

  # -- Operations: buffer -----------------------------------------------------

  def test_buffer_point
    point    = LLA.new(lat: 0.0, lng: 0.0, alt: 0.0)
    buffered = Geos.buffer(point, 1.0)

    assert_instance_of Polygon, buffered
    # The buffered polygon should contain the original point
    assert Geos.contains?(buffered, point)
  end

  def test_buffer_path
    path = Path.new(coordinates: [
      LLA.new(lat: 0.0, lng: 0.0, alt: 0.0),
      LLA.new(lat: 0.0, lng: 1.0, alt: 0.0),
    ])
    buffered = Geos.buffer(path, 0.5)

    assert_instance_of Polygon, buffered
    midpoint = LLA.new(lat: 0.0, lng: 0.5, alt: 0.0)
    assert Geos.contains?(buffered, midpoint)
  end

  def test_buffer_with_style
    path = Path.new(coordinates: [
      LLA.new(lat: 0.0, lng: 0.0, alt: 0.0),
      LLA.new(lat: 0.0, lng: 1.0, alt: 0.0),
    ])
    buffered = Geos.buffer_with_style(path, 0.5, end_cap_style: 2, join_style: 2)

    assert_instance_of Polygon, buffered
  end

  # -- Operations: convex_hull ------------------------------------------------

  def test_convex_hull
    # Create a concave set of points as a path
    points = [
      LLA.new(lat: 0.0, lng: 0.0, alt: 0.0),
      LLA.new(lat: 2.0, lng: 1.0, alt: 0.0),
      LLA.new(lat: 0.0, lng: 2.0, alt: 0.0),
      LLA.new(lat: 1.0, lng: 1.0, alt: 0.0), # interior point
    ]
    polygon = Polygon.new(boundary: [points[0], points[1], points[2]])
    hull = Geos.convex_hull(polygon)

    assert_instance_of Polygon, hull
  end

  # -- Operations: intersection -----------------------------------------------

  def test_intersection_of_overlapping_polygons
    poly_a = make_unit_polygon
    poly_b = Polygon.new(boundary: [
      LLA.new(lat: 1.0, lng: 1.0, alt: 0.0),
      LLA.new(lat: 3.0, lng: 1.0, alt: 0.0),
      LLA.new(lat: 3.0, lng: 3.0, alt: 0.0),
      LLA.new(lat: 1.0, lng: 3.0, alt: 0.0),
    ])

    result = Geos.intersection(poly_a, poly_b)
    assert_instance_of Polygon, result

    # Intersection of [0,2]x[0,2] and [1,3]x[1,3] is [1,2]x[1,2] => area = 1.0
    assert_in_delta 1.0, Geos.area(result), 1e-6
  end

  # -- Operations: difference -------------------------------------------------

  def test_difference_of_overlapping_polygons
    poly_a = make_unit_polygon # [0,2]x[0,2], area = 4.0
    poly_b = Polygon.new(boundary: [
      LLA.new(lat: 1.0, lng: 1.0, alt: 0.0),
      LLA.new(lat: 3.0, lng: 1.0, alt: 0.0),
      LLA.new(lat: 3.0, lng: 3.0, alt: 0.0),
      LLA.new(lat: 1.0, lng: 3.0, alt: 0.0),
    ])

    diff = Geos.difference(poly_a, poly_b)
    # 4.0 - 1.0 = 3.0
    assert_in_delta 3.0, Geos.area(diff), 1e-6
  end

  # -- Operations: symmetric_difference ---------------------------------------

  def test_symmetric_difference
    poly_a = make_unit_polygon
    poly_b = Polygon.new(boundary: [
      LLA.new(lat: 1.0, lng: 1.0, alt: 0.0),
      LLA.new(lat: 3.0, lng: 1.0, alt: 0.0),
      LLA.new(lat: 3.0, lng: 3.0, alt: 0.0),
      LLA.new(lat: 1.0, lng: 3.0, alt: 0.0),
    ])

    result = Geos.symmetric_difference(poly_a, poly_b)
    # (4.0 - 1.0) + (4.0 - 1.0) = 6.0
    assert_in_delta 6.0, Geos.area(result), 1e-6
  end

  # -- Operations: simplify ---------------------------------------------------

  def test_simplify_path
    # Create a noisy path that can be simplified
    coords = 20.times.map do |i|
      lat = 40.0 + i * 0.01 + (i.even? ? 0.001 : -0.001)
      lng = -74.0 + i * 0.01
      LLA.new(lat: lat, lng: lng, alt: 0.0)
    end
    path = Path.new(coordinates: coords)

    result = Geos.simplify(path, 0.005)
    # Should have fewer points than original
    result_size = result.respond_to?(:size) ? result.size : 2
    assert result_size < coords.size, "Simplified should have fewer points"
  end

  # -- Operations: make_valid -------------------------------------------------

  def test_make_valid_on_valid_polygon
    result = Geos.make_valid(make_unit_polygon)
    assert Geos.is_valid?(result)
  end

  # -- Operations: union ------------------------------------------------------

  def test_union
    polygon = make_unit_polygon
    result = Geos.union(polygon)
    assert Geos.is_valid?(result)
  end

  # -- Measurements -----------------------------------------------------------

  def test_area_of_unit_polygon
    # [0,2]x[0,2] in degrees => area = 4.0 sq degrees
    assert_in_delta 4.0, Geos.area(make_unit_polygon), 1e-6
  end

  def test_length_of_path
    path = Path.new(coordinates: [
      LLA.new(lat: 0.0, lng: 0.0, alt: 0.0),
      LLA.new(lat: 0.0, lng: 3.0, alt: 0.0),
      LLA.new(lat: 4.0, lng: 3.0, alt: 0.0),
    ])
    # Length = 3 + 4 = 7 degrees
    assert_in_delta 7.0, Geos.length(path), 1e-6
  end

  def test_distance_between_points
    pt1 = LLA.new(lat: 0.0, lng: 0.0, alt: 0.0)
    pt2 = LLA.new(lat: 3.0, lng: 4.0, alt: 0.0)
    # Euclidean distance in degree space = 5.0
    assert_in_delta 5.0, Geos.distance(pt1, pt2), 1e-6
  end

  # -- Nearest points --------------------------------------------------------

  def test_nearest_points_between_polygon_and_point
    polygon  = make_unit_polygon
    far_point = LLA.new(lat: 5.0, lng: 1.0, alt: 0.0)

    nearest = Geos.nearest_points(polygon, far_point)
    assert_equal 2, nearest.length

    # Nearest point on polygon should be on the top edge at lat=2
    assert_in_delta 2.0, nearest[0].lat, 1e-6
    assert_in_delta 1.0, nearest[0].lng, 1e-6
    # Nearest point on the far_point is itself
    assert_in_delta 5.0, nearest[1].lat, 1e-6
    assert_in_delta 1.0, nearest[1].lng, 1e-6
  end

  # -- Prepared geometry ------------------------------------------------------

  def test_prepared_contains
    polygon  = make_unit_polygon
    prepared = Geos.prepare(polygon)

    inside  = LLA.new(lat: 1.0, lng: 1.0, alt: 0.0)
    outside = LLA.new(lat: 5.0, lng: 5.0, alt: 0.0)

    assert prepared.contains?(inside)
    refute prepared.contains?(outside)
  ensure
    prepared&.release
  end

  def test_prepared_intersects
    polygon  = make_unit_polygon
    prepared = Geos.prepare(polygon)

    crossing_seg = Segment.new(
      LLA.new(lat: 1.0, lng: -1.0, alt: 0.0),
      LLA.new(lat: 1.0, lng: 3.0, alt: 0.0)
    )
    distant_seg = Segment.new(
      LLA.new(lat: 10.0, lng: 10.0, alt: 0.0),
      LLA.new(lat: 11.0, lng: 11.0, alt: 0.0)
    )

    assert prepared.intersects?(crossing_seg)
    refute prepared.intersects?(distant_seg)
  ensure
    prepared&.release
  end

  def test_prepared_release_prevents_reuse
    polygon  = make_unit_polygon
    prepared = Geos.prepare(polygon)
    prepared.release

    assert_raises(Geodetic::Error) do
      prepared.contains?(LLA.new(lat: 1.0, lng: 1.0, alt: 0.0))
    end
  end

  # -- Error handling ---------------------------------------------------------

  def test_to_geos_geom_and_release
    point = LLA.new(lat: 1.0, lng: 2.0, alt: 0.0)
    geom  = Geos.to_geos_geom(point)
    refute geom.null?
    Geos.release(geom)
  end

  def test_with_geom_block
    point = LLA.new(lat: 1.0, lng: 2.0, alt: 0.0)
    result = Geos.with_geom(point) do |g|
      refute g.null?
      :ok
    end
    assert_equal :ok, result
  end

  private

  # A 2x2 degree polygon: [(0,0), (2,0), (2,2), (0,2)]
  def make_unit_polygon
    Polygon.new(boundary: [
      LLA.new(lat: 0.0, lng: 0.0, alt: 0.0),
      LLA.new(lat: 2.0, lng: 0.0, alt: 0.0),
      LLA.new(lat: 2.0, lng: 2.0, alt: 0.0),
      LLA.new(lat: 0.0, lng: 2.0, alt: 0.0),
    ])
  end
end
