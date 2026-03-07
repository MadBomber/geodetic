# frozen_string_literal: true

require "test_helper"
require_relative "../lib/geodetic/areas/circle"
require_relative "../lib/geodetic/areas/polygon"
require_relative "../lib/geodetic/coordinates/lla"

class CircleAreaTest < Minitest::Test
  Circle = Geodetic::Areas::Circle
  LLA    = Geodetic::Coordinates::LLA

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
  LLA     = Geodetic::Coordinates::LLA

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
