# frozen_string_literal: true

require_relative "test_helper"

class S2Test < Minitest::Test
  include Geodetic

  def setup
    skip "libs2 not available" unless Coordinate::S2.available?
  end

  # --- Construction from token string ---

  def test_from_token_string
    s = Coordinate::S2.new("54906ab12f10f899")
    assert_equal "54906ab12f10f899", s.to_s
  end

  def test_from_token_case_insensitive
    s = Coordinate::S2.new("54906AB12F10F899")
    assert_equal "54906ab12f10f899", s.to_s
  end

  def test_from_token_strips_0x_prefix
    s = Coordinate::S2.new("0x54906ab12f10f899")
    assert_equal "54906ab12f10f899", s.to_s
  end

  def test_from_short_token
    s = Coordinate::S2.new("5494")
    assert_equal "5494", s.to_s
    assert_equal 5, s.level
  end

  # --- Construction from integer ---

  def test_from_integer
    id = 0x54906ab12f10f899
    s = Coordinate::S2.new(id)
    assert_equal "54906ab12f10f899", s.to_s
    assert_equal id, s.cell_id
  end

  def test_to_s_integer_format
    s = Coordinate::S2.new("54906ab12f10f899")
    assert_equal s.cell_id, s.to_s(:integer)
  end

  def test_invalid_integer_raises
    assert_raises(ArgumentError) { Coordinate::S2.new(0) }
    assert_raises(ArgumentError) { Coordinate::S2.new(42) }
  end

  # --- Construction from LLA ---

  def test_from_lla
    lla = Coordinate::LLA.new(lat: 47.6062, lng: -122.3321)
    s = Coordinate::S2.new(lla)
    assert_equal 15, s.level
    assert s.valid?
  end

  def test_from_lla_custom_level
    lla = Coordinate::LLA.new(lat: 47.6062, lng: -122.3321)
    s = Coordinate::S2.new(lla, precision: 20)
    assert_equal 20, s.level
  end

  def test_from_lla_level_30
    lla = Coordinate::LLA.new(lat: 47.6062, lng: -122.3321)
    s = Coordinate::S2.new(lla, precision: 30)
    assert_equal 30, s.level
    assert s.leaf?
    assert_equal "54906ab12f10f899", s.to_s
  end

  # --- Round-trip LLA conversion ---

  def test_round_trip_seattle
    lat, lng = 47.6062, -122.3321
    s = Coordinate::S2.new(Coordinate::LLA.new(lat: lat, lng: lng), precision: 30)
    lla = s.to_lla
    assert_in_delta lat, lla.lat, 1e-6
    assert_in_delta lng, lla.lng, 1e-6
  end

  def test_round_trip_tokyo
    lat, lng = 35.6762, 139.6503
    s = Coordinate::S2.new(Coordinate::LLA.new(lat: lat, lng: lng), precision: 30)
    lla = s.to_lla
    assert_in_delta lat, lla.lat, 1e-6
    assert_in_delta lng, lla.lng, 1e-6
  end

  def test_round_trip_sydney
    lat, lng = -33.8688, 151.2093
    s = Coordinate::S2.new(Coordinate::LLA.new(lat: lat, lng: lng), precision: 30)
    lla = s.to_lla
    assert_in_delta lat, lla.lat, 1e-6
    assert_in_delta lng, lla.lng, 1e-6
  end

  def test_round_trip_null_island
    s = Coordinate::S2.new(Coordinate::LLA.new(lat: 0.0, lng: 0.0), precision: 30)
    lla = s.to_lla
    assert_in_delta 0.0, lla.lat, 1e-6
    assert_in_delta 0.0, lla.lng, 1e-6
  end

  # --- Properties ---

  def test_level
    s = Coordinate::S2.new("54906ab14")
    assert_equal 15, s.level
  end

  def test_face
    s = Coordinate::S2.new("54906ab12f10f899")
    assert_equal 2, s.face
  end

  def test_face_cells
    # Face 0-5 tokens at level 0
    faces = { "1" => 0, "3" => 1, "5" => 2, "7" => 3, "9" => 4, "b" => 5 }
    faces.each do |token, expected_face|
      s = Coordinate::S2.new(token)
      assert_equal expected_face, s.face, "Token #{token} should be face #{expected_face}"
      assert_equal 0, s.level
    end
  end

  def test_leaf_and_face_cell
    leaf = Coordinate::S2.new(Coordinate::LLA.new(lat: 0.0, lng: 0.0), precision: 30)
    assert leaf.leaf?
    refute leaf.face_cell?

    face = Coordinate::S2.new("1")
    assert face.face_cell?
    refute face.leaf?
  end

  def test_valid
    s = Coordinate::S2.new("54906ab12f10f899")
    assert s.valid?
  end

  def test_invalid_token_raises
    assert_raises(ArgumentError) { Coordinate::S2.new("") }
    assert_raises(ArgumentError) { Coordinate::S2.new("xyz") }
    assert_raises(ArgumentError) { Coordinate::S2.new("0000000000000000") }
  end

  # --- Hierarchy ---

  def test_parent
    s = Coordinate::S2.new("54906ab12f10f899")
    p = s.parent
    assert_equal 29, p.level
    assert p.contains?(s)
  end

  def test_parent_at_level
    s = Coordinate::S2.new("54906ab12f10f899")
    p10 = s.parent(10)
    assert_equal 10, p10.level
    assert p10.contains?(s)
  end

  def test_parent_at_level_0
    s = Coordinate::S2.new("54906ab12f10f899")
    p0 = s.parent(0)
    assert_equal 0, p0.level
    assert_equal 2, p0.face
  end

  def test_parent_invalid_level_raises
    s = Coordinate::S2.new("54906ab14")
    assert_raises(ArgumentError) { s.parent(15) }
    assert_raises(ArgumentError) { s.parent(16) }
    assert_raises(ArgumentError) { s.parent(-1) }
  end

  def test_children
    s = Coordinate::S2.new("54906ab14")
    kids = s.children
    assert_equal 4, kids.length
    kids.each do |child|
      assert_equal 16, child.level
      assert s.contains?(child)
    end
  end

  def test_children_leaf_raises
    s = Coordinate::S2.new(Coordinate::LLA.new(lat: 0.0, lng: 0.0), precision: 30)
    assert_raises(ArgumentError) { s.children }
  end

  # --- Containment ---

  def test_contains_child
    s = Coordinate::S2.new(Coordinate::LLA.new(lat: 47.6062, lng: -122.3321), precision: 10)
    child = Coordinate::S2.new(Coordinate::LLA.new(lat: 47.6062, lng: -122.3321), precision: 20)
    assert s.contains?(child)
    refute child.contains?(s)
  end

  def test_contains_self
    s = Coordinate::S2.new("54906ab14")
    assert s.contains?(s)
  end

  def test_does_not_contain_different_cell
    seattle = Coordinate::S2.new(Coordinate::LLA.new(lat: 47.6062, lng: -122.3321), precision: 15)
    tokyo = Coordinate::S2.new(Coordinate::LLA.new(lat: 35.6762, lng: 139.6503), precision: 15)
    refute seattle.contains?(tokyo)
  end

  # --- Intersects ---

  def test_intersects_parent_child
    s = Coordinate::S2.new(Coordinate::LLA.new(lat: 47.6062, lng: -122.3321), precision: 10)
    child = Coordinate::S2.new(Coordinate::LLA.new(lat: 47.6062, lng: -122.3321), precision: 20)
    assert s.intersects?(child)
    assert child.intersects?(s)
  end

  def test_does_not_intersect_distant
    seattle = Coordinate::S2.new(Coordinate::LLA.new(lat: 47.6062, lng: -122.3321), precision: 20)
    tokyo = Coordinate::S2.new(Coordinate::LLA.new(lat: 35.6762, lng: 139.6503), precision: 20)
    refute seattle.intersects?(tokyo)
  end

  # --- Neighbors ---

  def test_edge_neighbors
    s = Coordinate::S2.new(Coordinate::LLA.new(lat: 47.6062, lng: -122.3321), precision: 15)
    nbrs = s.neighbors
    assert_equal 4, nbrs.length
    nbrs.each do |n|
      assert_instance_of Coordinate::S2, n
      assert_equal s.level, n.level
      refute_equal s.cell_id, n.cell_id
    end
  end

  def test_edge_neighbors_level_30
    s = Coordinate::S2.new(Coordinate::LLA.new(lat: 47.6062, lng: -122.3321), precision: 30)
    nbrs = s.neighbors
    assert_equal 4, nbrs.length
    nbrs.each { |n| assert_equal 30, n.level }
  end

  # --- Range (database scans) ---

  def test_range_min_max
    s = Coordinate::S2.new(Coordinate::LLA.new(lat: 47.6062, lng: -122.3321), precision: 12)
    assert s.range_min < s.cell_id
    assert s.range_max > s.cell_id
    assert s.range_min < s.range_max
  end

  def test_child_in_parent_range
    parent = Coordinate::S2.new(Coordinate::LLA.new(lat: 47.6062, lng: -122.3321), precision: 10)
    child = Coordinate::S2.new(Coordinate::LLA.new(lat: 47.6062, lng: -122.3321), precision: 20)
    assert child.cell_id >= parent.range_min
    assert child.cell_id <= parent.range_max
  end

  # --- Cell area ---

  def test_cell_area_level_30
    s = Coordinate::S2.new(Coordinate::LLA.new(lat: 47.6062, lng: -122.3321), precision: 30)
    area = s.cell_area
    assert_in_delta 0.0, area, 0.01  # ~0.7 cm² = ~0.0000007 m²
    assert area > 0
  end

  def test_cell_area_level_10
    s = Coordinate::S2.new(Coordinate::LLA.new(lat: 47.6062, lng: -122.3321), precision: 10)
    area = s.cell_area
    # Level 10 ≈ 79 km² = ~79,000,000 m²
    assert area > 50_000_000
    assert area < 150_000_000
  end

  def test_average_cell_area
    area = Coordinate::S2.average_cell_area(15)
    # Level 15 ≈ 79,000 m²
    assert area > 50_000
    assert area < 150_000
  end

  # --- to_area (polygon) ---

  def test_to_area_returns_polygon
    s = Coordinate::S2.new(Coordinate::LLA.new(lat: 47.6062, lng: -122.3321), precision: 15)
    polygon = s.to_area
    assert_instance_of Areas::Polygon, polygon
    # S2 cells are quadrilaterals: 4 vertices + closing vertex = 5 boundary points
    assert_equal 5, polygon.boundary.length
  end

  def test_to_area_contains_center
    s = Coordinate::S2.new(Coordinate::LLA.new(lat: 47.6062, lng: -122.3321), precision: 10)
    polygon = s.to_area
    center = s.to_lla
    assert polygon.includes?(center), "Polygon should contain the cell center"
  end

  # --- Equality ---

  def test_equality
    a = Coordinate::S2.new("54906ab12f10f899")
    b = Coordinate::S2.new("54906ab12f10f899")
    assert_equal a, b
  end

  def test_inequality
    a = Coordinate::S2.new("54906ab12f10f899")
    b = Coordinate::S2.new("54906ab12f10f89f")
    refute_equal a, b
  end

  # --- Conversion to/from other systems ---

  def test_to_ecef
    s = Coordinate::S2.new(Coordinate::LLA.new(lat: 47.6062, lng: -122.3321), precision: 15)
    ecef = s.to_ecef
    assert_instance_of Coordinate::ECEF, ecef
    lla = ecef.to_lla
    assert_in_delta 47.6062, lla.lat, 0.01
    assert_in_delta(-122.3321, lla.lng, 0.01)
  end

  def test_to_utm
    s = Coordinate::S2.new(Coordinate::LLA.new(lat: 47.6062, lng: -122.3321), precision: 15)
    utm = s.to_utm
    assert_instance_of Coordinate::UTM, utm
  end

  def test_from_ecef
    ecef = Coordinate::LLA.new(lat: 47.6062, lng: -122.3321).to_ecef
    s = Coordinate::S2.from_ecef(ecef)
    assert_instance_of Coordinate::S2, s
  end

  # --- Cross-hash conversions ---

  def test_to_gh
    s = Coordinate::S2.new(Coordinate::LLA.new(lat: 47.6062, lng: -122.3321), precision: 15)
    gh = s.to_gh
    assert_instance_of Coordinate::GH, gh
  end

  def test_from_gh
    gh = Coordinate::GH.new("c23nb5")
    s = Coordinate::S2.from_gh(gh)
    assert_instance_of Coordinate::S2, s
  end

  # --- Distance and bearing mixins ---

  def test_distance_to
    seattle = Coordinate::S2.new(Coordinate::LLA.new(lat: 47.6062, lng: -122.3321), precision: 15)
    nyc = Coordinate::S2.new(Coordinate::LLA.new(lat: 40.7128, lng: -74.0060), precision: 15)
    dist = seattle.distance_to(nyc)
    assert_instance_of Distance, dist
    # Seattle to NYC ≈ 3,866 km
    assert_in_delta 3_866_000, dist.meters, 50_000
  end

  def test_bearing_to
    seattle = Coordinate::S2.new(Coordinate::LLA.new(lat: 47.6062, lng: -122.3321), precision: 15)
    nyc = Coordinate::S2.new(Coordinate::LLA.new(lat: 40.7128, lng: -74.0060), precision: 15)
    bearing = seattle.bearing_to(nyc)
    assert_instance_of Bearing, bearing
    # Seattle to NYC bearing ≈ 79° (roughly east)
    assert_in_delta 79, bearing.degrees, 10
  end

  # --- Inspect ---

  def test_inspect
    s = Coordinate::S2.new("54906ab14")
    assert_match(/S2/, s.inspect)
    assert_match(/token=54906ab14/, s.inspect)
    assert_match(/level=15/, s.inspect)
    assert_match(/face=2/, s.inspect)
  end

  # --- precision_in_meters ---

  def test_precision_in_meters
    s = Coordinate::S2.new(Coordinate::LLA.new(lat: 47.6062, lng: -122.3321), precision: 15)
    pm = s.precision_in_meters
    assert pm[:lat] > 0
    assert pm[:lng] > 0
    assert pm[:area_m2] > 0
    # Level 15 ≈ 280m edge, ≈ 79,000 m² area
    assert pm[:area_m2] > 40_000
    assert pm[:area_m2] < 200_000
  end

  # --- Token round-trip ---

  def test_token_round_trip
    original = "54906ab12f10f899"
    s = Coordinate::S2.new(original)
    assert_equal original, s.to_s
    restored = Coordinate::S2.new(s.cell_id)
    assert_equal s, restored
  end
end
