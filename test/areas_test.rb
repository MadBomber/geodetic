# frozen_string_literal: true

require "test_helper"
require_relative "../lib/geodetic/areas/circle"
require_relative "../lib/geodetic/areas/polygon"
require_relative "../lib/geodetic/areas/bounding_box"
require_relative "../lib/geodetic/coordinate/lla"

class CircleAreaTest < Minitest::Test
  Circle = Geodetic::Areas::Circle
  LLA    = Geodetic::Coordinate::LLA

  # -- Constructor ----------------------------------------------------------

  def test_constructor
    centroid = LLA.new(lat: 40.0, lng: -74.0, alt: 0.0)
    circle = Circle.new(centroid: centroid, radius: 5000.0)
    assert_instance_of Circle, circle
  end

  # -- Accessors ------------------------------------------------------------

  def test_centroid_accessor
    centroid = LLA.new(lat: 40.0, lng: -74.0, alt: 0.0)
    circle = Circle.new(centroid: centroid, radius: 5000.0)
    assert_in_delta 40.0, circle.centroid.lat, 1e-6
    assert_in_delta(-74.0, circle.centroid.lng, 1e-6)
  end

  def test_radius_accessor
    centroid = LLA.new(lat: 40.0, lng: -74.0, alt: 0.0)
    circle = Circle.new(centroid: centroid, radius: 5000.0)
    assert_in_delta 5000.0, circle.radius, 1e-6
  end

  # -- includes?/excludes? --------------------------------------------------

  def test_includes_point_inside_circle
    centroid = LLA.new(lat: 47.6205, lng: -122.3493, alt: 0.0)
    circle = Circle.new(centroid: centroid, radius: 10_000.0) # 10km
    nearby = LLA.new(lat: 47.6300, lng: -122.3400, alt: 0.0)
    assert circle.includes?(nearby)
  end

  def test_excludes_point_outside_circle
    centroid = LLA.new(lat: 47.6205, lng: -122.3493, alt: 0.0)
    circle = Circle.new(centroid: centroid, radius: 1000.0) # 1km
    far = LLA.new(lat: 45.5152, lng: -122.6784, alt: 0.0) # Portland
    assert circle.excludes?(far)
  end

  def test_inside_and_outside_aliases
    centroid = LLA.new(lat: 47.6205, lng: -122.3493, alt: 0.0)
    circle = Circle.new(centroid: centroid, radius: 10_000.0)
    nearby = LLA.new(lat: 47.6300, lng: -122.3400, alt: 0.0)
    far = LLA.new(lat: 45.5152, lng: -122.6784, alt: 0.0)
    assert circle.inside?(nearby)
    assert circle.outside?(far)
  end

  def test_attributes_are_read_only
    centroid = LLA.new(lat: 40.0, lng: -74.0, alt: 0.0)
    circle = Circle.new(centroid: centroid, radius: 5000.0)
    assert_raises(NoMethodError) { circle.radius = 99.0 }
    assert_raises(NoMethodError) { circle.centroid = nil }
  end
end

class PolygonAreaTest < Minitest::Test
  Polygon = Geodetic::Areas::Polygon
  LLA     = Geodetic::Coordinate::LLA

  # -- Constructor ----------------------------------------------------------

  def test_constructor_with_triangle
    boundary = [
      LLA.new(lat: 0.0, lng: 0.0),
      LLA.new(lat: 1.0, lng: 0.0),
      LLA.new(lat: 0.0, lng: 1.0),
    ]
    polygon = Polygon.new(boundary: boundary)
    assert_instance_of Polygon, polygon
  end

  def test_constructor_auto_closes_polygon
    boundary = [
      LLA.new(lat: 0.0, lng: 0.0),
      LLA.new(lat: 1.0, lng: 0.0),
      LLA.new(lat: 0.0, lng: 1.0),
    ]
    polygon = Polygon.new(boundary: boundary)
    # Polygon should auto-close: first and last points should be equal
    assert_equal polygon.boundary.first, polygon.boundary.last
  end

  def test_constructor_does_not_double_close
    first = LLA.new(lat: 0.0, lng: 0.0)
    boundary = [
      first,
      LLA.new(lat: 1.0, lng: 0.0),
      LLA.new(lat: 0.0, lng: 1.0),
      LLA.new(lat: 0.0, lng: 0.0),
    ]
    polygon = Polygon.new(boundary: boundary)
    # Should not add another closing point
    assert_equal 4, polygon.boundary.size
  end

  # -- Accessors ------------------------------------------------------------

  def test_boundary_accessor
    boundary = [
      LLA.new(lat: 0.0, lng: 0.0),
      LLA.new(lat: 1.0, lng: 0.0),
      LLA.new(lat: 0.0, lng: 1.0),
    ]
    polygon = Polygon.new(boundary: boundary)
    assert_kind_of Array, polygon.boundary
    assert polygon.boundary.size >= 3
  end

  def test_centroid_accessor
    boundary = [
      LLA.new(lat: 0.0, lng: 0.0),
      LLA.new(lat: 1.0, lng: 0.0),
      LLA.new(lat: 0.0, lng: 1.0),
    ]
    polygon = Polygon.new(boundary: boundary)
    assert_instance_of LLA, polygon.centroid
  end

  # -- Centroid calculation -------------------------------------------------

  def test_centroid_simple_triangle
    boundary = [
      LLA.new(lat: 0.0, lng: 0.0),
      LLA.new(lat: 3.0, lng: 0.0),
      LLA.new(lat: 0.0, lng: 3.0),
    ]
    polygon = Polygon.new(boundary: boundary)
    # Centroid of right triangle (0,0), (3,0), (0,3) is (1, 1)
    assert_in_delta 1.0, polygon.centroid.lat, 0.1
    assert_in_delta 1.0, polygon.centroid.lng, 0.1
  end

  # -- Raises for < 3 points -----------------------------------------------

  def test_raises_for_fewer_than_3_points
    boundary = [
      LLA.new(lat: 0.0, lng: 0.0),
      LLA.new(lat: 1.0, lng: 0.0),
    ]
    assert_raises(ArgumentError) { Polygon.new(boundary: boundary) }
  end

  # -- edges ----------------------------------------------------------------

  def test_edges_returns_segments
    boundary = [
      LLA.new(lat: 0.0, lng: 0.0),
      LLA.new(lat: 1.0, lng: 0.0),
      LLA.new(lat: 0.0, lng: 1.0),
    ]
    polygon = Polygon.new(boundary: boundary)
    edges = polygon.edges
    assert_equal 3, edges.size
    edges.each { |e| assert_kind_of Geodetic::Segment, e }
  end

  def test_edges_are_consecutive
    a = LLA.new(lat: 0.0, lng: 0.0)
    b = LLA.new(lat: 1.0, lng: 0.0)
    c = LLA.new(lat: 0.0, lng: 1.0)
    polygon = Polygon.new(boundary: [a, b, c])
    edges = polygon.edges

    assert_equal a, edges[0].start_point
    assert_equal b, edges[0].end_point
    assert_equal b, edges[1].start_point
    assert_equal c, edges[1].end_point
    assert_equal c, edges[2].start_point
    assert_equal a, edges[2].end_point
  end

  def test_edges_are_cached
    boundary = [
      LLA.new(lat: 0.0, lng: 0.0),
      LLA.new(lat: 1.0, lng: 0.0),
      LLA.new(lat: 0.0, lng: 1.0),
    ]
    polygon = Polygon.new(boundary: boundary)
    assert_same polygon.edges, polygon.edges
  end

  # -- Self-intersection validation ----------------------------------------

  def test_raises_on_self_intersecting_boundary
    # A bowtie shape: edges cross in the middle
    boundary = [
      LLA.new(lat: 0.0, lng: 0.0),
      LLA.new(lat: 1.0, lng: 1.0),
      LLA.new(lat: 1.0, lng: 0.0),
      LLA.new(lat: 0.0, lng: 1.0),
    ]
    err = assert_raises(ArgumentError) { Polygon.new(boundary: boundary) }
    assert_match(/self-intersect/, err.message)
  end

  def test_accepts_valid_convex_polygon
    boundary = [
      LLA.new(lat: 0.0, lng: 0.0),
      LLA.new(lat: 1.0, lng: 0.0),
      LLA.new(lat: 1.0, lng: 1.0),
      LLA.new(lat: 0.0, lng: 1.0),
    ]
    polygon = Polygon.new(boundary: boundary)
    assert_instance_of Polygon, polygon
  end

  def test_accepts_valid_concave_polygon
    # L-shaped concave polygon
    boundary = [
      LLA.new(lat: 0.0, lng: 0.0),
      LLA.new(lat: 2.0, lng: 0.0),
      LLA.new(lat: 2.0, lng: 1.0),
      LLA.new(lat: 1.0, lng: 1.0),
      LLA.new(lat: 1.0, lng: 2.0),
      LLA.new(lat: 0.0, lng: 2.0),
    ]
    polygon = Polygon.new(boundary: boundary)
    assert_instance_of Polygon, polygon
  end

  def test_validate_false_skips_check
    # A figure-eight that crosses but has computable area.
    # With validate: true this would raise; with false it skips the check.
    boundary = [
      LLA.new(lat: 0.0, lng: 0.0),
      LLA.new(lat: 2.0, lng: 1.0),
      LLA.new(lat: 0.0, lng: 1.0),
      LLA.new(lat: 2.0, lng: 0.0),
    ]
    # Confirm it raises with validation
    assert_raises(ArgumentError) { Polygon.new(boundary: boundary) }
    # Confirm it does not raise without validation
    polygon = Polygon.new(boundary: boundary, validate: false)
    assert_instance_of Polygon, polygon
  end

  # -- includes?/excludes? --------------------------------------------------

  def test_includes_point_inside_polygon
    boundary = [
      LLA.new(lat: 47.60, lng: -122.35),
      LLA.new(lat: 47.65, lng: -122.35),
      LLA.new(lat: 47.65, lng: -122.30),
      LLA.new(lat: 47.60, lng: -122.30),
    ]
    polygon = Polygon.new(boundary: boundary)
    inside = LLA.new(lat: 47.625, lng: -122.325)
    assert polygon.includes?(inside)
  end

  def test_excludes_point_outside_polygon
    boundary = [
      LLA.new(lat: 47.60, lng: -122.35),
      LLA.new(lat: 47.65, lng: -122.35),
      LLA.new(lat: 47.65, lng: -122.30),
      LLA.new(lat: 47.60, lng: -122.30),
    ]
    polygon = Polygon.new(boundary: boundary)
    outside = LLA.new(lat: 45.0, lng: -120.0)
    assert polygon.excludes?(outside)
  end

  def test_inside_and_outside_aliases
    boundary = [
      LLA.new(lat: 47.60, lng: -122.35),
      LLA.new(lat: 47.65, lng: -122.35),
      LLA.new(lat: 47.65, lng: -122.30),
      LLA.new(lat: 47.60, lng: -122.30),
    ]
    polygon = Polygon.new(boundary: boundary)
    inside = LLA.new(lat: 47.625, lng: -122.325)
    outside = LLA.new(lat: 45.0, lng: -120.0)
    assert polygon.inside?(inside)
    assert polygon.outside?(outside)
  end

  def test_attributes_are_read_only
    boundary = [
      LLA.new(lat: 0.0, lng: 0.0),
      LLA.new(lat: 1.0, lng: 0.0),
      LLA.new(lat: 0.0, lng: 1.0),
    ]
    polygon = Polygon.new(boundary: boundary)
    assert_raises(NoMethodError) { polygon.boundary = [] }
    assert_raises(NoMethodError) { polygon.centroid = nil }
  end
end

class BoundingBoxAreaTest < Minitest::Test
  BoundingBox = Geodetic::Areas::BoundingBox
  LLA         = Geodetic::Coordinate::LLA

  # -- Constructor ----------------------------------------------------------

  def test_constructor
    nw = LLA.new(lat: 41.0, lng: -75.0)
    se = LLA.new(lat: 40.0, lng: -74.0)
    rect = BoundingBox.new(nw: nw, se: se)
    assert_instance_of BoundingBox, rect
  end

  def test_raises_when_nw_lat_below_se_lat
    nw = LLA.new(lat: 39.0, lng: -75.0)
    se = LLA.new(lat: 40.0, lng: -74.0)
    assert_raises(ArgumentError) { BoundingBox.new(nw: nw, se: se) }
  end

  def test_raises_when_nw_lng_above_se_lng
    nw = LLA.new(lat: 41.0, lng: -73.0)
    se = LLA.new(lat: 40.0, lng: -74.0)
    assert_raises(ArgumentError) { BoundingBox.new(nw: nw, se: se) }
  end

  def test_constructor_converts_non_lla_coordinates
    nw_lla = LLA.new(lat: 41.0, lng: -75.0)
    se_lla = LLA.new(lat: 40.0, lng: -74.0)
    nw_wm = Geodetic::Coordinate::WebMercator.from_lla(nw_lla)
    se_wm = Geodetic::Coordinate::WebMercator.from_lla(se_lla)
    rect = BoundingBox.new(nw: nw_wm, se: se_wm)
    assert_instance_of BoundingBox, rect
    assert_instance_of LLA, rect.nw
    assert_in_delta 41.0, rect.nw.lat, 0.01
    assert_in_delta(-74.0, rect.se.lng, 0.01)
  end

  # -- Accessors ------------------------------------------------------------

  def test_nw_accessor
    nw = LLA.new(lat: 41.0, lng: -75.0)
    se = LLA.new(lat: 40.0, lng: -74.0)
    rect = BoundingBox.new(nw: nw, se: se)
    assert_in_delta 41.0, rect.nw.lat, 1e-6
    assert_in_delta(-75.0, rect.nw.lng, 1e-6)
  end

  def test_se_accessor
    nw = LLA.new(lat: 41.0, lng: -75.0)
    se = LLA.new(lat: 40.0, lng: -74.0)
    rect = BoundingBox.new(nw: nw, se: se)
    assert_in_delta 40.0, rect.se.lat, 1e-6
    assert_in_delta(-74.0, rect.se.lng, 1e-6)
  end

  def test_ne_corner
    nw = LLA.new(lat: 41.0, lng: -75.0)
    se = LLA.new(lat: 40.0, lng: -74.0)
    rect = BoundingBox.new(nw: nw, se: se)
    assert_in_delta 41.0, rect.ne.lat, 1e-6
    assert_in_delta(-74.0, rect.ne.lng, 1e-6)
  end

  def test_sw_corner
    nw = LLA.new(lat: 41.0, lng: -75.0)
    se = LLA.new(lat: 40.0, lng: -74.0)
    rect = BoundingBox.new(nw: nw, se: se)
    assert_in_delta 40.0, rect.sw.lat, 1e-6
    assert_in_delta(-75.0, rect.sw.lng, 1e-6)
  end

  # -- Centroid -------------------------------------------------------------

  def test_centroid
    nw = LLA.new(lat: 41.0, lng: -75.0)
    se = LLA.new(lat: 40.0, lng: -74.0)
    rect = BoundingBox.new(nw: nw, se: se)
    assert_in_delta 40.5, rect.centroid.lat, 1e-6
    assert_in_delta(-74.5, rect.centroid.lng, 1e-6)
  end

  # -- includes?/excludes? -------------------------------------------------

  def test_includes_center_point
    nw = LLA.new(lat: 41.0, lng: -75.0)
    se = LLA.new(lat: 40.0, lng: -74.0)
    rect = BoundingBox.new(nw: nw, se: se)
    assert rect.includes?(LLA.new(lat: 40.5, lng: -74.5))
  end

  def test_includes_corner_points
    nw = LLA.new(lat: 41.0, lng: -75.0)
    se = LLA.new(lat: 40.0, lng: -74.0)
    rect = BoundingBox.new(nw: nw, se: se)
    assert rect.includes?(nw)
    assert rect.includes?(se)
  end

  def test_excludes_point_outside
    nw = LLA.new(lat: 41.0, lng: -75.0)
    se = LLA.new(lat: 40.0, lng: -74.0)
    rect = BoundingBox.new(nw: nw, se: se)
    assert rect.excludes?(LLA.new(lat: 0.0, lng: 0.0))
  end

  def test_includes_any_coordinate_with_to_lla
    nw = LLA.new(lat: 41.0, lng: -75.0)
    se = LLA.new(lat: 40.0, lng: -74.0)
    rect = BoundingBox.new(nw: nw, se: se)
    wm = Geodetic::Coordinate::WebMercator.from_lla(LLA.new(lat: 40.5, lng: -74.5))
    assert rect.includes?(wm)
  end

  def test_inside_and_outside_aliases
    nw = LLA.new(lat: 41.0, lng: -75.0)
    se = LLA.new(lat: 40.0, lng: -74.0)
    rect = BoundingBox.new(nw: nw, se: se)
    inside = LLA.new(lat: 40.5, lng: -74.5)
    outside = LLA.new(lat: 0.0, lng: 0.0)
    assert rect.inside?(inside)
    assert rect.outside?(outside)
  end

  def test_include_and_exclude_aliases
    nw = LLA.new(lat: 41.0, lng: -75.0)
    se = LLA.new(lat: 40.0, lng: -74.0)
    rect = BoundingBox.new(nw: nw, se: se)
    inside = LLA.new(lat: 40.5, lng: -74.5)
    outside = LLA.new(lat: 0.0, lng: 0.0)
    assert rect.include?(inside)
    assert rect.exclude?(outside)
  end

  def test_excludes_point_north_of_rectangle
    nw = LLA.new(lat: 41.0, lng: -75.0)
    se = LLA.new(lat: 40.0, lng: -74.0)
    rect = BoundingBox.new(nw: nw, se: se)
    assert rect.excludes?(LLA.new(lat: 42.0, lng: -74.5))
  end

  def test_excludes_point_east_of_rectangle
    nw = LLA.new(lat: 41.0, lng: -75.0)
    se = LLA.new(lat: 40.0, lng: -74.0)
    rect = BoundingBox.new(nw: nw, se: se)
    assert rect.excludes?(LLA.new(lat: 40.5, lng: -73.0))
  end

  def test_attributes_are_read_only
    nw = LLA.new(lat: 41.0, lng: -75.0)
    se = LLA.new(lat: 40.0, lng: -74.0)
    rect = BoundingBox.new(nw: nw, se: se)
    assert_raises(NoMethodError) { rect.nw = nil }
    assert_raises(NoMethodError) { rect.se = nil }
    assert_raises(NoMethodError) { rect.centroid = nil }
  end
end
