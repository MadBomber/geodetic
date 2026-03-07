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

  # -- includes?/excludes? aliases -----------------------------------------
  # Note: includes? relies on LLA#distance_to which is not yet implemented.
  # These tests verify the alias methods exist on the class.

  def test_includes_method_exists
    assert Circle.instance_method(:includes?)
  end

  def test_excludes_method_exists
    assert Circle.instance_method(:excludes?)
  end

  def test_include_alias_exists
    assert Circle.instance_method(:include?)
  end

  def test_exclude_alias_exists
    assert Circle.instance_method(:exclude?)
  end

  def test_inside_alias_exists
    assert Circle.instance_method(:inside?)
  end

  def test_outside_alias_exists
    assert Circle.instance_method(:outside?)
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
    assert_raises(UncaughtThrowError) { Polygon.new(boundary: boundary) }
  end

  # -- includes?/excludes? aliases -----------------------------------------
  # Note: includes? relies on LLA#heading_to which is not yet implemented.
  # These tests verify the alias methods exist on the class.

  def test_includes_method_exists
    assert Polygon.instance_method(:includes?)
  end

  def test_excludes_method_exists
    assert Polygon.instance_method(:excludes?)
  end

  def test_include_alias_exists
    assert Polygon.instance_method(:include?)
  end

  def test_exclude_alias_exists
    assert Polygon.instance_method(:exclude?)
  end

  def test_inside_alias_exists
    assert Polygon.instance_method(:inside?)
  end

  def test_outside_alias_exists
    assert Polygon.instance_method(:outside?)
  end
end
