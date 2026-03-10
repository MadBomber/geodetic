# frozen_string_literal: true

require "test_helper"

class RegularPolygonBaseTest < Minitest::Test
  LLA = Geodetic::Coordinate::LLA

  def setup
    @center = LLA.new(lat: 40.7484, lng: -73.9857, alt: 0)
  end

  # ── Triangle ─────────────────────────────────────────────────

  def test_triangle_is_polygon
    tri = Geodetic::Areas::Triangle.new(center: @center, width: 400, height: 600)
    assert_kind_of Geodetic::Areas::Polygon, tri
  end

  def test_triangle_has_3_sides
    tri = Geodetic::Areas::Triangle.new(center: @center, width: 400, height: 600)
    assert_equal 3, tri.sides
  end

  def test_triangle_boundary_is_closed
    tri = Geodetic::Areas::Triangle.new(center: @center, width: 400, height: 600)
    assert_equal tri.boundary.first, tri.boundary.last
    assert_equal 4, tri.boundary.size  # 3 vertices + closing point
  end

  def test_triangle_center_inside
    tri = Geodetic::Areas::Triangle.new(center: @center, width: 400, height: 600)
    assert tri.includes?(@center)
  end

  def test_triangle_far_point_outside
    tri = Geodetic::Areas::Triangle.new(center: @center, width: 400, height: 600)
    far = LLA.new(lat: 41.0, lng: -74.0, alt: 0)
    assert tri.excludes?(far)
  end

  def test_triangle_with_bearing
    tri0 = Geodetic::Areas::Triangle.new(center: @center, width: 400, height: 600, bearing: 0)
    tri45 = Geodetic::Areas::Triangle.new(center: @center, width: 400, height: 600, bearing: 45)

    # Different bearings produce different vertex positions
    refute_equal tri0.boundary[0].lng, tri45.boundary[0].lng
  end

  def test_triangle_vertices
    tri = Geodetic::Areas::Triangle.new(center: @center, width: 400, height: 600)
    assert_equal 3, tri.vertices.size
  end

  def test_triangle_base
    tri = Geodetic::Areas::Triangle.new(center: @center, width: 400, height: 600)
    assert_in_delta 400.0, tri.base, 1e-6
  end

  def test_triangle_attributes
    tri = Geodetic::Areas::Triangle.new(center: @center, width: 400, height: 600, bearing: 15)
    assert_in_delta 400.0, tri.width, 1e-6
    assert_in_delta 600.0, tri.height, 1e-6
    assert_in_delta 15.0, tri.bearing, 1e-6
  end

  def test_triangle_to_bounding_box
    tri = Geodetic::Areas::Triangle.new(center: @center, width: 400, height: 600, bearing: 30)
    bbox = tri.to_bounding_box
    assert_kind_of Geodetic::Areas::BoundingBox, bbox
    tri.vertices.each do |v|
      assert bbox.includes?(v), "BoundingBox should contain vertex #{v}"
    end
  end

  def test_triangle_raises_on_zero_width
    assert_raises(ArgumentError) do
      Geodetic::Areas::Triangle.new(center: @center, width: 0, height: 100)
    end
  end

  def test_triangle_raises_on_negative_height
    assert_raises(ArgumentError) do
      Geodetic::Areas::Triangle.new(center: @center, width: 100, height: -50)
    end
  end

  def test_triangle_north_aligned_symmetry
    tri = Geodetic::Areas::Triangle.new(center: @center, width: 400, height: 600, bearing: 0)
    verts = tri.vertices

    # Base-left and base-right should have same lat
    assert_in_delta verts[0].lat, verts[1].lat, 1e-6
    # Apex should be north of base
    assert_operator verts[2].lat, :>, verts[0].lat
    # Apex lng should equal center lng (symmetric)
    assert_in_delta @center.lng, verts[2].lng, 1e-6
  end

  # ── Triangle equilateral by radius ─────────────────────────

  def test_equilateral_by_radius
    tri = Geodetic::Areas::Triangle.new(center: @center, radius: 500)
    assert tri.equilateral?
    assert_equal 3, tri.sides
    assert_in_delta 500 * Math.sqrt(3), tri.width, 1e-6
    assert_in_delta 500 * 1.5, tri.height, 1e-6
  end

  def test_equilateral_by_radius_center_inside
    tri = Geodetic::Areas::Triangle.new(center: @center, radius: 500)
    assert tri.includes?(@center)
  end

  def test_equilateral_by_radius_with_bearing
    tri0  = Geodetic::Areas::Triangle.new(center: @center, radius: 500, bearing: 0)
    tri45 = Geodetic::Areas::Triangle.new(center: @center, radius: 500, bearing: 45)
    refute_equal tri0.boundary[0].lng, tri45.boundary[0].lng
  end

  def test_equilateral_by_radius_raises_on_zero
    assert_raises(ArgumentError) do
      Geodetic::Areas::Triangle.new(center: @center, radius: 0)
    end
  end

  def test_equilateral_by_radius_rejects_extra_args
    assert_raises(ArgumentError) do
      Geodetic::Areas::Triangle.new(center: @center, radius: 500, width: 100)
    end
  end

  # ── Triangle equilateral by side ───────────────────────────

  def test_equilateral_by_side
    tri = Geodetic::Areas::Triangle.new(center: @center, side: 600)
    assert tri.equilateral?
    assert_in_delta 600.0, tri.width, 1e-6
    assert_in_delta 600 * Math.sqrt(3) / 2.0, tri.height, 1e-6
  end

  def test_equilateral_by_side_center_inside
    tri = Geodetic::Areas::Triangle.new(center: @center, side: 600)
    assert tri.includes?(@center)
  end

  def test_equilateral_by_side_raises_on_negative
    assert_raises(ArgumentError) do
      Geodetic::Areas::Triangle.new(center: @center, side: -10)
    end
  end

  def test_equilateral_by_side_rejects_extra_args
    assert_raises(ArgumentError) do
      Geodetic::Areas::Triangle.new(center: @center, side: 600, height: 300)
    end
  end

  def test_triangle_raises_without_valid_args
    assert_raises(ArgumentError) do
      Geodetic::Areas::Triangle.new(center: @center)
    end
  end

  def test_isosceles_not_equilateral
    tri = Geodetic::Areas::Triangle.new(center: @center, width: 400, height: 600)
    refute tri.equilateral?
    assert tri.isosceles?
  end

  def test_equilateral_not_isosceles
    tri = Geodetic::Areas::Triangle.new(center: @center, radius: 500)
    assert tri.equilateral?
    refute tri.isosceles?
    refute tri.scalene?
  end

  def test_isosceles_predicates
    tri = Geodetic::Areas::Triangle.new(center: @center, width: 400, height: 600)
    assert tri.isosceles?
    refute tri.equilateral?
    refute tri.scalene?
  end

  # ── Triangle from arbitrary vertices ───────────────────────

  def test_triangle_from_vertices
    p1 = LLA.new(lat: 40.74, lng: -73.99, alt: 0)
    p2 = LLA.new(lat: 40.75, lng: -73.98, alt: 0)
    p3 = LLA.new(lat: 40.76, lng: -73.995, alt: 0)
    tri = Geodetic::Areas::Triangle.new(vertices: [p1, p2, p3])

    assert_kind_of Geodetic::Areas::Polygon, tri
    assert_equal 3, tri.sides
    assert_equal 3, tri.vertices.size
  end

  def test_triangle_from_vertices_boundary_closed
    p1 = LLA.new(lat: 40.74, lng: -73.99, alt: 0)
    p2 = LLA.new(lat: 40.75, lng: -73.98, alt: 0)
    p3 = LLA.new(lat: 40.76, lng: -73.995, alt: 0)
    tri = Geodetic::Areas::Triangle.new(vertices: [p1, p2, p3])

    assert_equal tri.boundary.first, tri.boundary.last
    assert_equal 4, tri.boundary.size
  end

  def test_triangle_from_vertices_center_is_centroid
    p1 = LLA.new(lat: 40.74, lng: -73.99, alt: 0)
    p2 = LLA.new(lat: 40.75, lng: -73.98, alt: 0)
    p3 = LLA.new(lat: 40.76, lng: -73.995, alt: 0)
    tri = Geodetic::Areas::Triangle.new(vertices: [p1, p2, p3])

    expected_lat = (40.74 + 40.75 + 40.76) / 3.0
    expected_lng = (-73.99 + -73.98 + -73.995) / 3.0
    assert_in_delta expected_lat, tri.center.lat, 1e-6
    assert_in_delta expected_lng, tri.center.lng, 1e-6
  end

  def test_scalene_triangle_from_vertices
    p1 = LLA.new(lat: 40.74, lng: -73.99, alt: 0)
    p2 = LLA.new(lat: 40.75, lng: -73.98, alt: 0)
    p3 = LLA.new(lat: 40.76, lng: -73.995, alt: 0)
    tri = Geodetic::Areas::Triangle.new(vertices: [p1, p2, p3])

    assert tri.scalene?
    refute tri.equilateral?
    refute tri.isosceles?
  end

  def test_triangle_side_lengths
    tri = Geodetic::Areas::Triangle.new(center: @center, side: 600)
    lengths = tri.side_lengths
    assert_equal 3, lengths.size
    lengths.each { |l| assert_in_delta 600.0, l, 2.0 }
  end

  def test_triangle_from_vertices_base_is_nil
    p1 = LLA.new(lat: 40.74, lng: -73.99, alt: 0)
    p2 = LLA.new(lat: 40.75, lng: -73.98, alt: 0)
    p3 = LLA.new(lat: 40.76, lng: -73.995, alt: 0)
    tri = Geodetic::Areas::Triangle.new(vertices: [p1, p2, p3])
    assert_nil tri.base
  end

  def test_triangle_from_vertices_raises_on_wrong_count
    p1 = LLA.new(lat: 40.74, lng: -73.99, alt: 0)
    p2 = LLA.new(lat: 40.75, lng: -73.98, alt: 0)
    assert_raises(ArgumentError) do
      Geodetic::Areas::Triangle.new(vertices: [p1, p2])
    end
  end

  def test_triangle_from_vertices_rejects_extra_args
    p1 = LLA.new(lat: 40.74, lng: -73.99, alt: 0)
    p2 = LLA.new(lat: 40.75, lng: -73.98, alt: 0)
    p3 = LLA.new(lat: 40.76, lng: -73.995, alt: 0)
    assert_raises(ArgumentError) do
      Geodetic::Areas::Triangle.new(vertices: [p1, p2, p3], center: @center)
    end
  end

  def test_triangle_to_bounding_box_from_vertices
    p1 = LLA.new(lat: 40.74, lng: -73.99, alt: 0)
    p2 = LLA.new(lat: 40.75, lng: -73.98, alt: 0)
    p3 = LLA.new(lat: 40.76, lng: -73.995, alt: 0)
    tri = Geodetic::Areas::Triangle.new(vertices: [p1, p2, p3])
    bbox = tri.to_bounding_box

    assert_kind_of Geodetic::Areas::BoundingBox, bbox
    tri.vertices.each do |v|
      assert bbox.includes?(v), "BoundingBox should contain vertex #{v}"
    end
  end

  # ── Rectangle ────────────────────────────────────────────────

  def test_rectangle_is_polygon
    rect = Geodetic::Areas::Rectangle.new(center: @center, width: 400, height: 800)
    assert_kind_of Geodetic::Areas::Polygon, rect
  end

  def test_rectangle_has_4_sides
    rect = Geodetic::Areas::Rectangle.new(center: @center, width: 400, height: 800)
    assert_equal 4, rect.sides
  end

  def test_rectangle_boundary_is_closed
    rect = Geodetic::Areas::Rectangle.new(center: @center, width: 400, height: 800)
    assert_equal rect.boundary.first, rect.boundary.last
    assert_equal 5, rect.boundary.size  # 4 vertices + closing point
  end

  def test_rectangle_center_inside
    rect = Geodetic::Areas::Rectangle.new(center: @center, width: 400, height: 800)
    assert rect.includes?(@center)
  end

  def test_rectangle_corners_count
    rect = Geodetic::Areas::Rectangle.new(center: @center, width: 400, height: 800)
    assert_equal 4, rect.corners.size
  end

  def test_rectangle_attributes
    rect = Geodetic::Areas::Rectangle.new(center: @center, width: 400, height: 800, bearing: 29)
    assert_in_delta 400.0, rect.width, 1e-6
    assert_in_delta 800.0, rect.height, 1e-6
    assert_in_delta 29.0, rect.bearing, 1e-6
  end

  def test_rectangle_north_aligned_symmetry
    rect = Geodetic::Areas::Rectangle.new(center: @center, width: 400, height: 800, bearing: 0)
    corners = rect.corners

    # Front-left and front-right should have same lat (north edge)
    assert_in_delta corners[0].lat, corners[1].lat, 1e-6
    # Back-left and back-right should have same lat (south edge)
    assert_in_delta corners[2].lat, corners[3].lat, 1e-6
    # Left corners should have same lng
    assert_in_delta corners[0].lng, corners[3].lng, 1e-6
    # Right corners should have same lng
    assert_in_delta corners[1].lng, corners[2].lng, 1e-6
  end

  def test_rectangle_rotated_corners_differ
    rect0 = Geodetic::Areas::Rectangle.new(center: @center, width: 400, height: 800, bearing: 0)
    rect45 = Geodetic::Areas::Rectangle.new(center: @center, width: 400, height: 800, bearing: 45)

    # Rotated rectangle has different corner positions
    refute_in_delta rect0.corners[0].lat, rect45.corners[0].lat, 1e-6
  end

  def test_rectangle_to_bounding_box
    rect = Geodetic::Areas::Rectangle.new(center: @center, width: 400, height: 800, bearing: 29)
    bbox = rect.to_bounding_box

    assert_kind_of Geodetic::Areas::BoundingBox, bbox
    # BoundingBox should enclose all corners
    rect.corners.each do |corner|
      assert bbox.includes?(corner), "BoundingBox should contain corner #{corner}"
    end
  end

  def test_rectangle_raises_on_zero_width
    assert_raises(ArgumentError) do
      Geodetic::Areas::Rectangle.new(center: @center, width: 0, height: 100)
    end
  end

  def test_rectangle_raises_on_negative_height
    assert_raises(ArgumentError) do
      Geodetic::Areas::Rectangle.new(center: @center, width: 100, height: -50)
    end
  end

  # ── Pentagon ─────────────────────────────────────────────────

  def test_pentagon_is_polygon
    pent = Geodetic::Areas::Pentagon.new(center: @center, radius: 500)
    assert_kind_of Geodetic::Areas::Polygon, pent
  end

  def test_pentagon_has_5_sides
    pent = Geodetic::Areas::Pentagon.new(center: @center, radius: 500)
    assert_equal 5, pent.sides
  end

  def test_pentagon_boundary_closed
    pent = Geodetic::Areas::Pentagon.new(center: @center, radius: 500)
    assert_equal pent.boundary.first, pent.boundary.last
    assert_equal 6, pent.boundary.size
  end

  def test_pentagon_center_inside
    pent = Geodetic::Areas::Pentagon.new(center: @center, radius: 500)
    assert pent.includes?(@center)
  end

  # ── Hexagon ──────────────────────────────────────────────────

  def test_hexagon_is_polygon
    hex = Geodetic::Areas::Hexagon.new(center: @center, radius: 500)
    assert_kind_of Geodetic::Areas::Polygon, hex
  end

  def test_hexagon_has_6_sides
    hex = Geodetic::Areas::Hexagon.new(center: @center, radius: 500)
    assert_equal 6, hex.sides
  end

  def test_hexagon_boundary_closed
    hex = Geodetic::Areas::Hexagon.new(center: @center, radius: 500)
    assert_equal hex.boundary.first, hex.boundary.last
    assert_equal 7, hex.boundary.size
  end

  def test_hexagon_center_inside
    hex = Geodetic::Areas::Hexagon.new(center: @center, radius: 500)
    assert hex.includes?(@center)
  end

  # ── Octagon ──────────────────────────────────────────────────

  def test_octagon_is_polygon
    oct = Geodetic::Areas::Octagon.new(center: @center, radius: 500)
    assert_kind_of Geodetic::Areas::Polygon, oct
  end

  def test_octagon_has_8_sides
    oct = Geodetic::Areas::Octagon.new(center: @center, radius: 500)
    assert_equal 8, oct.sides
  end

  def test_octagon_boundary_closed
    oct = Geodetic::Areas::Octagon.new(center: @center, radius: 500)
    assert_equal oct.boundary.first, oct.boundary.last
    assert_equal 9, oct.boundary.size
  end

  def test_octagon_center_inside
    oct = Geodetic::Areas::Octagon.new(center: @center, radius: 500)
    assert oct.includes?(@center)
  end

  # ── Shared behavior ─────────────────────────────────────────

  def test_regular_polygon_raises_on_zero_radius
    assert_raises(ArgumentError) do
      Geodetic::Areas::Pentagon.new(center: @center, radius: 0)
    end
  end

  def test_regular_polygon_raises_on_negative_radius
    assert_raises(ArgumentError) do
      Geodetic::Areas::Hexagon.new(center: @center, radius: -100)
    end
  end

  def test_all_subclasses_have_centroid
    shapes = [
      Geodetic::Areas::Triangle.new(center: @center, width: 400, height: 600),
      Geodetic::Areas::Rectangle.new(center: @center, width: 400, height: 800),
      Geodetic::Areas::Pentagon.new(center: @center, radius: 500),
      Geodetic::Areas::Hexagon.new(center: @center, radius: 500),
      Geodetic::Areas::Octagon.new(center: @center, radius: 500)
    ]

    shapes.each do |shape|
      assert_kind_of Geodetic::Coordinate::LLA, shape.centroid
      # Centroid should be near the center
      assert_in_delta @center.lat, shape.centroid.lat, 0.01
      assert_in_delta @center.lng, shape.centroid.lng, 0.01
    end
  end

  def test_vertices_are_equidistant_from_center_for_regular_polygons
    hex = Geodetic::Areas::Hexagon.new(center: @center, radius: 500)
    vertices = hex.boundary[0...-1]  # exclude closing point

    distances = vertices.map { |v| @center.distance_to(v).meters }
    distances.each do |d|
      assert_in_delta 500.0, d, 2.0  # within 2m of specified radius
    end
  end

  def test_path_closest_points_to_rectangle
    route = Geodetic::Path.new(coordinates: [
      LLA.new(lat: 40.70, lng: -74.01, alt: 0),
      LLA.new(lat: 40.76, lng: -73.98, alt: 0)
    ])

    rect = Geodetic::Areas::Rectangle.new(center: @center, width: 400, height: 800, bearing: 29)
    result = route.closest_points_to(rect)

    assert result[:path_point]
    assert result[:area_point]
    assert_kind_of Geodetic::Distance, result[:distance]
  end

  def test_feature_with_rectangle_geometry
    rect = Geodetic::Areas::Rectangle.new(center: @center, width: 400, height: 800, bearing: 29)
    feature = Geodetic::Feature.new(label: "Building", geometry: rect)

    target = LLA.new(lat: 40.75, lng: -73.99, alt: 0)
    dist = feature.distance_to(target)
    assert_kind_of Geodetic::Distance, dist
  end
end
