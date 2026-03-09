# frozen_string_literal: true

require_relative "test_helper"

class H3Test < Minitest::Test
  include Geodetic

  def setup
    skip "libh3 not available" unless Coordinate::H3.available?
  end

  # --- Construction from hex string ---

  def test_from_hex_string
    h = Coordinate::H3.new("872a1072bffffff")
    assert_equal "872a1072bffffff", h.to_s
  end

  def test_from_hex_string_case_insensitive
    h = Coordinate::H3.new("872A1072BFFFFFF")
    assert_equal "872a1072bffffff", h.to_s
  end

  def test_from_hex_string_strips_0x_prefix
    h = Coordinate::H3.new("0x872a1072bffffff")
    assert_equal "872a1072bffffff", h.to_s
  end

  # --- Construction from integer ---

  def test_from_integer
    h = Coordinate::H3.new(0x872a1072bffffff)
    assert_equal "872a1072bffffff", h.to_s
  end

  def test_h3_index_returns_integer
    h = Coordinate::H3.new("872a1072bffffff")
    assert_equal 0x872a1072bffffff, h.h3_index
  end

  # --- Construction from LLA ---

  def test_from_lla
    lla = Coordinate::LLA.new(lat: 40.689167, lng: -74.044444)
    h = Coordinate::H3.new(lla)
    assert_equal 7, h.resolution
    assert h.valid?
  end

  def test_from_lla_custom_resolution
    lla = Coordinate::LLA.new(lat: 40.689167, lng: -74.044444)
    h = Coordinate::H3.new(lla, precision: 9)
    assert_equal 9, h.resolution
  end

  def test_from_lla_known_value
    # Statue of Liberty at res 7 — verified via H3 CLI
    lla = Coordinate::LLA.new(lat: 40.689167, lng: -74.044444)
    h = Coordinate::H3.new(lla, precision: 7)
    assert_equal "872a1072bffffff", h.to_s
  end

  def test_from_lla_resolution_9_known_value
    lla = Coordinate::LLA.new(lat: 40.689167, lng: -74.044444)
    h = Coordinate::H3.new(lla, precision: 9)
    assert_equal "892a1072b5bffff", h.to_s
  end

  def test_from_lla_london
    lla = Coordinate::LLA.new(lat: 51.5074, lng: -0.1278)
    h = Coordinate::H3.new(lla, precision: 7)
    assert_equal "87195da49ffffff", h.to_s
  end

  def test_from_lla_null_island
    lla = Coordinate::LLA.new(lat: 0.0, lng: 0.0)
    h = Coordinate::H3.new(lla, precision: 7)
    assert_equal "87754e64dffffff", h.to_s
  end

  # --- Resolution / precision ---

  def test_resolution
    h = Coordinate::H3.new("872a1072bffffff")
    assert_equal 7, h.resolution
  end

  def test_precision_alias
    h = Coordinate::H3.new("872a1072bffffff")
    assert_equal h.resolution, h.precision
  end

  def test_default_precision_is_7
    assert_equal 7, Coordinate::H3.default_precision
  end

  def test_resolution_range
    lla = Coordinate::LLA.new(lat: 40.0, lng: -74.0)
    (0..15).each do |res|
      h = Coordinate::H3.new(lla, precision: res)
      assert_equal res, h.resolution
    end
  end

  # --- Roundtrip encoding/decoding ---

  def test_roundtrip_statue_of_liberty
    lla = Coordinate::LLA.new(lat: 40.689167, lng: -74.044444)
    h = Coordinate::H3.new(lla, precision: 9)
    result = h.to_lla
    # Res 9 cells are ~175m, so center offset can be ~0.002°
    assert_in_delta 40.689167, result.lat, 0.005
    assert_in_delta(-74.044444, result.lng, 0.005)
  end

  def test_roundtrip_london
    lla = Coordinate::LLA.new(lat: 51.5074, lng: -0.1278)
    h = Coordinate::H3.new(lla, precision: 9)
    result = h.to_lla
    assert_in_delta 51.5074, result.lat, 0.005
    assert_in_delta(-0.1278, result.lng, 0.005)
  end

  def test_roundtrip_equator
    lla = Coordinate::LLA.new(lat: 0.0, lng: 0.0)
    h = Coordinate::H3.new(lla, precision: 9)
    result = h.to_lla
    assert_in_delta 0.0, result.lat, 0.005
    assert_in_delta 0.0, result.lng, 0.005
  end

  def test_roundtrip_south_hemisphere
    lla = Coordinate::LLA.new(lat: -33.8688, lng: 151.2093)
    h = Coordinate::H3.new(lla, precision: 9)
    result = h.to_lla
    assert_in_delta(-33.8688, result.lat, 0.005)
    assert_in_delta 151.2093, result.lng, 0.005
  end

  def test_decode_known_center
    # H3 CLI: 872a1072bffffff -> 40.6852839752 -74.0302183235
    h = Coordinate::H3.new("872a1072bffffff")
    center = h.to_lla
    assert_in_delta 40.685284, center.lat, 0.001
    assert_in_delta(-74.030218, center.lng, 0.001)
  end

  # --- Validation ---

  def test_valid
    assert Coordinate::H3.new("872a1072bffffff").valid?
  end

  def test_raises_on_empty
    assert_raises(ArgumentError) { Coordinate::H3.new("") }
  end

  def test_raises_on_invalid_hex
    assert_raises(ArgumentError) { Coordinate::H3.new("not_hex_at_all!") }
  end

  def test_raises_on_invalid_cell
    assert_raises(ArgumentError) { Coordinate::H3.new("0000000000000000") }
  end

  # --- Pentagon ---

  def test_non_pentagon
    h = Coordinate::H3.new("872a1072bffffff")
    refute h.pentagon?
  end

  # --- Equality ---

  def test_equality
    a = Coordinate::H3.new("872a1072bffffff")
    b = Coordinate::H3.new("872a1072bffffff")
    assert_equal a, b
  end

  def test_equality_string_and_integer
    a = Coordinate::H3.new("872a1072bffffff")
    b = Coordinate::H3.new(0x872a1072bffffff)
    assert_equal a, b
  end

  def test_inequality
    a = Coordinate::H3.new("872a1072bffffff")
    b = Coordinate::H3.new("87195da49ffffff")
    refute_equal a, b
  end

  # --- to_area (Polygon) ---

  def test_to_area_returns_polygon
    h = Coordinate::H3.new("872a1072bffffff")
    area = h.to_area
    assert_instance_of Geodetic::Areas::Polygon, area
  end

  def test_to_area_has_6_vertices
    h = Coordinate::H3.new("872a1072bffffff")
    area = h.to_area
    # Polygon closes the boundary, so boundary.length = vertices + 1
    assert_equal 7, area.boundary.length
  end

  def test_to_area_contains_center
    h = Coordinate::H3.new("872a1072bffffff")
    area = h.to_area
    center = h.to_lla
    assert area.includes?(center)
  end

  # --- Neighbors ---

  def test_neighbors_returns_array
    h = Coordinate::H3.new("872a1072bffffff")
    n = h.neighbors
    assert_instance_of Array, n
  end

  def test_neighbors_count_hexagon
    h = Coordinate::H3.new("872a1072bffffff")
    n = h.neighbors
    assert_equal 6, n.length
  end

  def test_neighbors_are_h3
    h = Coordinate::H3.new("872a1072bffffff")
    n = h.neighbors
    n.each { |cell| assert_instance_of Coordinate::H3, cell }
  end

  def test_neighbors_do_not_include_self
    h = Coordinate::H3.new("872a1072bffffff")
    n = h.neighbors
    n.each { |cell| refute_equal h, cell }
  end

  def test_neighbors_known_values
    # gridDisk k=1 for 872a1072bffffff (from H3 CLI):
    # 872a1072affffff, 872a1070cffffff, 872a1070dffffff,
    # 872a10776ffffff, 872a10729ffffff, 872a10728ffffff
    h = Coordinate::H3.new("872a1072bffffff")
    expected = %w[872a1072affffff 872a1070cffffff 872a1070dffffff
                  872a10776ffffff 872a10729ffffff 872a10728ffffff].sort
    actual = h.neighbors.map(&:to_s).sort
    assert_equal expected, actual
  end

  # --- grid_disk ---

  def test_grid_disk_k0
    h = Coordinate::H3.new("872a1072bffffff")
    cells = h.grid_disk(0)
    assert_equal 1, cells.length
    assert_equal h, cells.first
  end

  def test_grid_disk_k1
    h = Coordinate::H3.new("872a1072bffffff")
    cells = h.grid_disk(1)
    assert_equal 7, cells.length
  end

  def test_grid_disk_k2
    h = Coordinate::H3.new("872a1072bffffff")
    cells = h.grid_disk(2)
    assert_equal 19, cells.length
  end

  # --- Parent / Children ---

  def test_parent
    h = Coordinate::H3.new("872a1072bffffff")
    parent = h.parent(5)
    assert_instance_of Coordinate::H3, parent
    assert_equal 5, parent.resolution
  end

  def test_parent_raises_if_not_coarser
    h = Coordinate::H3.new("872a1072bffffff")
    assert_raises(ArgumentError) { h.parent(7) }
    assert_raises(ArgumentError) { h.parent(9) }
  end

  def test_children
    h = Coordinate::H3.new("872a1072bffffff")
    kids = h.children(8)
    assert_equal 7, kids.length
    kids.each do |kid|
      assert_instance_of Coordinate::H3, kid
      assert_equal 8, kid.resolution
    end
  end

  def test_children_raises_if_not_finer
    h = Coordinate::H3.new("872a1072bffffff")
    assert_raises(ArgumentError) { h.children(7) }
    assert_raises(ArgumentError) { h.children(5) }
  end

  # --- Cell area ---

  def test_cell_area
    h = Coordinate::H3.new("872a1072bffffff")
    area = h.cell_area
    assert_instance_of Float, area
    assert area > 0
    # Res 7 cells are roughly 5 km² = 5_000_000 m²
    assert_in_delta 5_000_000, area, 1_000_000
  end

  # --- precision_in_meters ---

  def test_precision_in_meters
    h = Coordinate::H3.new("872a1072bffffff")
    meters = h.precision_in_meters
    assert_instance_of Hash, meters
    assert meters[:lat] > 0
    assert meters[:lng] > 0
    assert meters[:area_m2] > 0
  end

  # --- to_s ---

  def test_to_s
    h = Coordinate::H3.new("872a1072bffffff")
    assert_equal "872a1072bffffff", h.to_s
  end

  def test_to_s_integer_format
    h = Coordinate::H3.new("872a1072bffffff")
    assert_equal 0x872a1072bffffff, h.to_s(:integer)
  end

  # --- to_a ---

  def test_to_a
    h = Coordinate::H3.new("872a1072bffffff")
    lat, lng = h.to_a
    assert_instance_of Float, lat
    assert_instance_of Float, lng
  end

  # --- Conversion to/from LLA ---

  def test_to_lla
    h = Coordinate::H3.new("872a1072bffffff")
    lla = h.to_lla
    assert_instance_of Coordinate::LLA, lla
    assert_equal 0.0, lla.alt
  end

  def test_from_lla_class_method
    lla = Coordinate::LLA.new(lat: 40.0, lng: -74.0)
    h = Coordinate::H3.from_lla(lla)
    assert_instance_of Coordinate::H3, h
  end

  def test_lla_to_h3
    lla = Coordinate::LLA.new(lat: 40.0, lng: -74.0)
    h = lla.to_h3
    assert_instance_of Coordinate::H3, h
  end

  def test_lla_to_h3_custom_precision
    lla = Coordinate::LLA.new(lat: 40.0, lng: -74.0)
    h = lla.to_h3(precision: 10)
    assert_equal 10, h.resolution
  end

  # --- Conversion to/from other coordinate systems ---

  def test_to_ecef
    h = Coordinate::H3.new("872a1072bffffff")
    ecef = h.to_ecef
    assert_instance_of Coordinate::ECEF, ecef
  end

  def test_to_utm
    h = Coordinate::H3.new("872a1072bffffff")
    utm = h.to_utm
    assert_instance_of Coordinate::UTM, utm
  end

  def test_from_utm
    utm = Coordinate::UTM.new(easting: 583960.0, northing: 4507523.0, zone: 18, hemisphere: 'N')
    h = Coordinate::H3.from_utm(utm)
    assert_instance_of Coordinate::H3, h
  end

  # --- Cross-hash conversions ---

  def test_to_gh
    h = Coordinate::H3.new("872a1072bffffff")
    gh = h.to_gh
    assert_instance_of Coordinate::GH, gh
  end

  def test_to_ham
    h = Coordinate::H3.new("872a1072bffffff")
    ham = h.to_ham
    assert_instance_of Coordinate::HAM, ham
  end

  def test_to_olc
    h = Coordinate::H3.new("872a1072bffffff")
    olc = h.to_olc
    assert_instance_of Coordinate::OLC, olc
  end

  def test_to_georef
    h = Coordinate::H3.new("872a1072bffffff")
    georef = h.to_georef
    assert_instance_of Coordinate::GEOREF, georef
  end

  def test_to_gars
    h = Coordinate::H3.new("872a1072bffffff")
    gars = h.to_gars
    assert_instance_of Coordinate::GARS, gars
  end

  # --- Conversions from other systems to H3 ---

  def test_ecef_to_h3
    ecef = Coordinate::ECEF.new(x: 1334075.0, y: -4653937.0, z: 4138729.0)
    h = ecef.to_h3
    assert_instance_of Coordinate::H3, h
  end

  def test_utm_to_h3
    utm = Coordinate::UTM.new(easting: 583960.0, northing: 4507523.0, zone: 18, hemisphere: 'N')
    h = utm.to_h3
    assert_instance_of Coordinate::H3, h
  end

  def test_gh_to_h3
    gh = Coordinate::GH.new("dr5ru7")
    h = gh.to_h3
    assert_instance_of Coordinate::H3, h
  end

  # --- from_string / from_array ---

  def test_from_string
    h = Coordinate::H3.from_string("872a1072bffffff")
    assert_equal "872a1072bffffff", h.to_s
  end

  def test_from_array
    h = Coordinate::H3.from_array([40.689167, -74.044444])
    assert_instance_of Coordinate::H3, h
  end

  # --- Distance and bearing ---

  def test_distance_to
    a = Coordinate::H3.new("872a1072bffffff")
    b = Coordinate::H3.new("87195da49ffffff")
    d = a.distance_to(b)
    assert_instance_of Geodetic::Distance, d
    assert d.to_f > 0
  end

  def test_bearing_to
    a = Coordinate::H3.new("872a1072bffffff")
    b = Coordinate::H3.new("87195da49ffffff")
    bearing = a.bearing_to(b)
    assert_instance_of Geodetic::Bearing, bearing
  end
end
