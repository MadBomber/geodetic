# frozen_string_literal: true

require "test_helper"
require_relative "../lib/geodetic/coordinate/gh36"
require_relative "../lib/geodetic/coordinate/lla"

class GH36Test < Minitest::Test
  GH36        = Geodetic::Coordinate::GH36
  LLA         = Geodetic::Coordinate::LLA
  ECEF        = Geodetic::Coordinate::ECEF
  UTM         = Geodetic::Coordinate::UTM
  ENU         = Geodetic::Coordinate::ENU
  NED         = Geodetic::Coordinate::NED
  MGRS        = Geodetic::Coordinate::MGRS
  USNG        = Geodetic::Coordinate::USNG
  WM          = Geodetic::Coordinate::WebMercator
  UPS_C       = Geodetic::Coordinate::UPS
  SP          = Geodetic::Coordinate::StatePlane
  BNG         = Geodetic::Coordinate::BNG

  # ── Constructor from String ────────────────────────────────

  def test_from_geohash_string
    coord = GH36.new("bdrdC26BqH")
    assert_equal "bdrdC26BqH", coord.geohash
  end

  def test_raises_on_invalid_geohash_chars
    assert_raises(ArgumentError) { GH36.new("abc!@#") }
  end

  def test_raises_on_empty_geohash
    assert_raises(ArgumentError) { GH36.new("") }
  end

  # ── Constructor from coordinate ────────────────────────────

  def test_from_lla
    lla = LLA.new(lat: 51.504444, lng: -0.086666)
    coord = GH36.new(lla)
    assert_equal 10, coord.precision
  end

  def test_from_lla_custom_precision
    lla = LLA.new(lat: 0.0, lng: 0.0)
    coord = GH36.new(lla, precision: 5)
    assert_equal 5, coord.precision
  end

  def test_from_any_coordinate_with_to_lla
    lla = LLA.new(lat: 40.689167, lng: -74.044444)
    utm = lla.to_utm
    coord = GH36.new(utm)
    restored = coord.to_lla
    assert_in_delta 40.689167, restored.lat, 0.001
    assert_in_delta(-74.044444, restored.lng, 0.001)
  end

  def test_raises_on_unsupported_source
    assert_raises(ArgumentError) { GH36.new(42) }
  end

  # ── Precision ──────────────────────────────────────────────

  def test_precision_matches_hash_length
    coord = GH36.new("bdrdC")
    assert_equal 5, coord.precision
  end

  # ── to_s ───────────────────────────────────────────────────

  def test_to_s_returns_geohash
    coord = GH36.new("bdrdC26BqH")
    assert_equal "bdrdC26BqH", coord.to_s
  end

  def test_to_s_with_truncation
    coord = GH36.new("bdrdC26BqH")
    assert_equal "bdrdC", coord.to_s(5)
  end

  # ── to_a ───────────────────────────────────────────────────

  def test_to_a_returns_lat_lng
    lla = LLA.new(lat: 40.0, lng: -74.0)
    coord = GH36.new(lla)
    result = coord.to_a
    assert_equal 2, result.size
    assert_in_delta 40.0, result[0], 0.01
    assert_in_delta(-74.0, result[1], 0.01)
  end

  # ── from_array / from_string ─────────────────────────────

  def test_from_array
    coord = GH36.from_array([40.689167, -74.044444])
    lla = coord.to_lla
    assert_in_delta 40.689167, lla.lat, 0.001
    assert_in_delta(-74.044444, lla.lng, 0.001)
  end

  def test_from_string
    coord = GH36.from_string("bdrdC26BqH")
    assert_equal "bdrdC26BqH", coord.geohash
  end

  # ── Encode / Decode roundtrip ────────────────────────────

  def test_roundtrip_origin
    coord = GH36.new(LLA.new(lat: 0.0, lng: 0.0))
    restored = coord.to_lla
    assert_in_delta 0.0, restored.lat, 0.001
    assert_in_delta 0.0, restored.lng, 0.001
  end

  def test_roundtrip_statue_of_liberty
    coord = GH36.new(LLA.new(lat: 40.689167, lng: -74.044444))
    restored = coord.to_lla
    assert_in_delta 40.689167, restored.lat, 0.001
    assert_in_delta(-74.044444, restored.lng, 0.001)
  end

  def test_roundtrip_london
    coord = GH36.new(LLA.new(lat: 51.504444, lng: -0.086666))
    restored = coord.to_lla
    assert_in_delta 51.504444, restored.lat, 0.001
    assert_in_delta(-0.086666, restored.lng, 0.001)
  end

  def test_roundtrip_southern_hemisphere
    coord = GH36.new(LLA.new(lat: -33.8688, lng: 151.2093))
    restored = coord.to_lla
    assert_in_delta(-33.8688, restored.lat, 0.001)
    assert_in_delta 151.2093, restored.lng, 0.001
  end

  def test_roundtrip_extreme_coordinates
    coord = GH36.new(LLA.new(lat: 89.9, lng: 179.9))
    restored = coord.to_lla
    assert_in_delta 89.9, restored.lat, 0.01
    assert_in_delta 179.9, restored.lng, 0.01
  end

  def test_roundtrip_negative_extremes
    coord = GH36.new(LLA.new(lat: -89.9, lng: -179.9))
    restored = coord.to_lla
    assert_in_delta(-89.9, restored.lat, 0.01)
    assert_in_delta(-179.9, restored.lng, 0.01)
  end

  # ── LLA convenience methods ─────────────────────────────

  def test_lla_to_gh36
    lla = LLA.new(lat: 40.689167, lng: -74.044444)
    gh36 = lla.to_gh36
    assert_instance_of GH36, gh36
    restored = gh36.to_lla
    assert_in_delta 40.689167, restored.lat, 0.001
    assert_in_delta(-74.044444, restored.lng, 0.001)
  end

  def test_lla_from_gh36
    gh36 = GH36.new(LLA.new(lat: 40.689167, lng: -74.044444))
    lla = LLA.from_gh36(gh36)
    assert_instance_of LLA, lla
    assert_in_delta 40.689167, lla.lat, 0.001
  end

  # ── Equality ─────────────────────────────────────────────

  def test_equality_same_hash
    a = GH36.new("bdrdC26BqH")
    b = GH36.new("bdrdC26BqH")
    assert_equal a, b
  end

  def test_equality_different_hash
    a = GH36.new("bdrdC26BqH")
    b = GH36.new("bdrdC26Bq2")
    refute_equal a, b
  end

  def test_equality_non_gh36
    coord = GH36.new("bdrdC26BqH")
    refute_equal coord, "bdrdC26BqH"
  end

  # ── valid? ───────────────────────────────────────────────

  def test_valid_hash
    coord = GH36.new("bdrdC26BqH")
    assert coord.valid?
  end

  # ── Neighbors ────────────────────────────────────────────

  def test_neighbors_returns_all_eight
    coord = GH36.new("bdrdC26BqH")
    all = coord.neighbors
    assert_equal 8, all.size
    assert all.key?(:N)
    assert all.key?(:S)
    assert all.key?(:E)
    assert all.key?(:W)
    assert all.key?(:NE)
    assert all.key?(:NW)
    assert all.key?(:SE)
    assert all.key?(:SW)
  end

  def test_neighbors_returns_gh36_instances
    coord = GH36.new("bdrdC26BqH")
    all = coord.neighbors
    all.each_value do |neighbor|
      assert_instance_of GH36, neighbor
    end
  end

  def test_neighbors_differ_from_original
    coord = GH36.new("bdrdC26BqH")
    coord.neighbors.each_value do |neighbor|
      refute_equal coord, neighbor
    end
  end

  def test_north_neighbor_has_higher_latitude
    lla = LLA.new(lat: 40.0, lng: -74.0)
    coord = GH36.new(lla)
    north = coord.neighbors[:N]
    assert north.to_lla.lat > coord.to_lla.lat,
      "North neighbor should have higher latitude"
  end

  def test_south_neighbor_has_lower_latitude
    lla = LLA.new(lat: 40.0, lng: -74.0)
    coord = GH36.new(lla)
    south = coord.neighbors[:S]
    assert south.to_lla.lat < coord.to_lla.lat,
      "South neighbor should have lower latitude"
  end

  def test_east_neighbor_has_higher_longitude
    lla = LLA.new(lat: 40.0, lng: -74.0)
    coord = GH36.new(lla)
    east = coord.neighbors[:E]
    assert east.to_lla.lng > coord.to_lla.lng,
      "East neighbor should have higher longitude"
  end

  def test_west_neighbor_has_lower_longitude
    lla = LLA.new(lat: 40.0, lng: -74.0)
    coord = GH36.new(lla)
    west = coord.neighbors[:W]
    assert west.to_lla.lng < coord.to_lla.lng,
      "West neighbor should have lower longitude"
  end

  def test_neighbor_chainable
    coord = GH36.new(LLA.new(lat: 40.0, lng: -74.0))
    north_lla = coord.neighbors[:N].to_lla
    assert_instance_of LLA, north_lla
  end

  # ── to_area ──────────────────────────────────────────────

  def test_to_area_returns_rectangle
    coord = GH36.new("bdrdC26BqH")
    area = coord.to_area
    assert_instance_of Geodetic::Areas::Rectangle, area
  end

  def test_to_area_contains_midpoint
    lla = LLA.new(lat: 40.0, lng: -74.0)
    coord = GH36.new(lla)
    area = coord.to_area
    assert area.includes?(coord.to_lla)
  end

  def test_to_area_excludes_distant_point
    lla = LLA.new(lat: 40.0, lng: -74.0)
    coord = GH36.new(lla)
    area = coord.to_area
    assert area.excludes?(LLA.new(lat: 0.0, lng: 0.0))
  end

  # ── Precision in meters ─────────────────────────────────

  def test_precision_in_meters
    lla = LLA.new(lat: 0.0, lng: 0.0)
    coord = GH36.new(lla)
    prec = coord.precision_in_meters
    assert prec[:lat] > 0
    assert prec[:lng] > 0
    assert prec[:lng] > prec[:lat], "Longitude precision should be coarser than latitude"
  end

  def test_longer_hash_has_finer_precision
    lla = LLA.new(lat: 0.0, lng: 0.0)
    short = GH36.new(lla, precision: 5)
    long  = GH36.new(lla, precision: 10)
    assert long.precision_in_meters[:lat] < short.precision_in_meters[:lat]
  end

  # ── to_slug ──────────────────────────────────────────────

  def test_to_slug_alias
    coord = GH36.new("bdrdC26BqH")
    assert_equal coord.to_s, coord.to_slug
  end

  # ── distance_to (via mixin) ─────────────────────────────

  def test_distance_to
    a = GH36.new(LLA.new(lat: 40.689167, lng: -74.044444))
    b = GH36.new(LLA.new(lat: 51.504444, lng: -0.086666))
    dist = a.distance_to(b)
    assert_instance_of Geodetic::Distance, dist
    # NYC to London is roughly 5,570 km
    assert_in_delta 5_570_000, dist.to_f, 50_000
  end

  # ── bearing_to (via mixin) ──────────────────────────────

  def test_bearing_to
    a = GH36.new(LLA.new(lat: 40.689167, lng: -74.044444))
    b = GH36.new(LLA.new(lat: 51.504444, lng: -0.086666))
    bearing = a.bearing_to(b)
    assert_instance_of Geodetic::Bearing, bearing
    # NYC to London bearing is roughly 51 degrees
    assert_in_delta 51.0, bearing.degrees, 5.0
  end

  # ── Immutability ────────────────────────────────────────

  def test_no_setter_for_geohash
    coord = GH36.new("bdrdC26BqH")
    assert_raises(NoMethodError) { coord.geohash = "xxx" }
  end

  # ── to_gh36 with precision ────────────────────────────

  def test_lla_to_gh36_custom_precision
    lla = LLA.new(lat: 40.0, lng: -74.0)
    gh36 = lla.to_gh36(precision: 5)
    assert_equal 5, gh36.precision
  end

  # ── from_array with precision ─────────────────────────

  def test_from_array_default_precision
    coord = GH36.from_array([40.0, -74.0])
    assert_equal 10, coord.precision
  end

  # ── Diagonal neighbors ────────────────────────────────

  def test_ne_neighbor_direction
    coord = GH36.new(LLA.new(lat: 40.0, lng: -74.0))
    ne = coord.neighbors[:NE]
    assert ne.to_lla.lat > coord.to_lla.lat,
      "NE neighbor should have higher latitude"
    assert ne.to_lla.lng > coord.to_lla.lng,
      "NE neighbor should have higher longitude"
  end

  def test_sw_neighbor_direction
    coord = GH36.new(LLA.new(lat: 40.0, lng: -74.0))
    sw = coord.neighbors[:SW]
    assert sw.to_lla.lat < coord.to_lla.lat,
      "SW neighbor should have lower latitude"
    assert sw.to_lla.lng < coord.to_lla.lng,
      "SW neighbor should have lower longitude"
  end

  # ── to_area dimensions ────────────────────────────────

  def test_to_area_nw_is_north_and_west_of_se
    coord = GH36.new(LLA.new(lat: 40.0, lng: -74.0))
    area = coord.to_area
    assert area.nw.lat > area.se.lat
    assert area.nw.lng < area.se.lng
  end

  # ── Cross-system conversion ─────────────────────────────

  def test_to_ecef_roundtrip
    gh36 = GH36.new(LLA.new(lat: 40.689167, lng: -74.044444))
    ecef = gh36.to_ecef
    restored = GH36.new(ecef)
    restored_lla = restored.to_lla
    assert_in_delta 40.689167, restored_lla.lat, 0.001
    assert_in_delta(-74.044444, restored_lla.lng, 0.001)
  end

  def test_to_utm_roundtrip
    gh36 = GH36.new(LLA.new(lat: 40.689167, lng: -74.044444))
    utm = gh36.to_utm
    restored = GH36.new(utm)
    restored_lla = restored.to_lla
    assert_in_delta 40.689167, restored_lla.lat, 0.001
    assert_in_delta(-74.044444, restored_lla.lng, 0.001)
  end

  def test_to_web_mercator_roundtrip
    gh36 = GH36.new(LLA.new(lat: 40.689167, lng: -74.044444))
    wm = gh36.to_web_mercator
    restored = GH36.new(wm)
    restored_lla = restored.to_lla
    assert_in_delta 40.689167, restored_lla.lat, 0.001
    assert_in_delta(-74.044444, restored_lla.lng, 0.001)
  end

  # ── to_enu / from_enu ────────────────────────────────────

  def test_to_enu
    ref = LLA.new(lat: 40.0, lng: -74.0)
    gh36 = GH36.new(LLA.new(lat: 40.689167, lng: -74.044444))
    enu = gh36.to_lla.to_enu(ref)
    assert_instance_of ENU, enu
  end

  def test_from_enu_roundtrip
    ref = LLA.new(lat: 40.0, lng: -74.0)
    lla = LLA.new(lat: 40.689167, lng: -74.044444)
    gh36 = GH36.new(lla)
    enu = gh36.to_lla.to_enu(ref)
    restored_lla = enu.to_lla(ref)
    restored = GH36.new(restored_lla)
    final_lla = restored.to_lla
    assert_in_delta 40.689167, final_lla.lat, 0.01
    assert_in_delta(-74.044444, final_lla.lng, 0.01)
  end

  # ── to_ned / from_ned ────────────────────────────────────

  def test_to_ned
    ref = LLA.new(lat: 40.0, lng: -74.0)
    gh36 = GH36.new(LLA.new(lat: 40.689167, lng: -74.044444))
    ned = gh36.to_lla.to_ned(ref)
    assert_instance_of NED, ned
  end

  def test_from_ned_roundtrip
    ref = LLA.new(lat: 40.0, lng: -74.0)
    lla = LLA.new(lat: 40.689167, lng: -74.044444)
    gh36 = GH36.new(lla)
    ned = gh36.to_lla.to_ned(ref)
    restored_lla = ned.to_lla(ref)
    restored = GH36.new(restored_lla)
    final_lla = restored.to_lla
    assert_in_delta 40.689167, final_lla.lat, 0.01
    assert_in_delta(-74.044444, final_lla.lng, 0.01)
  end

  # ── to_mgrs / from_mgrs ──────────────────────────────────

  def test_to_mgrs
    gh36 = GH36.new(LLA.new(lat: 40.689167, lng: -74.044444))
    mgrs = gh36.to_mgrs
    assert_instance_of MGRS, mgrs
  end

  def test_from_mgrs_roundtrip
    lla = LLA.new(lat: 40.689167, lng: -74.044444)
    gh36 = GH36.new(lla)
    mgrs = gh36.to_mgrs
    restored = GH36.from_mgrs(mgrs)
    restored_lla = restored.to_lla
    assert_in_delta 40.689167, restored_lla.lat, 0.01
    assert_in_delta(-74.044444, restored_lla.lng, 0.01)
  end

  # ── to_usng / from_usng ──────────────────────────────────

  def test_to_usng
    gh36 = GH36.new(LLA.new(lat: 40.689167, lng: -74.044444))
    usng = gh36.to_usng
    assert_instance_of USNG, usng
  end

  def test_from_usng_roundtrip
    lla = LLA.new(lat: 40.689167, lng: -74.044444)
    gh36 = GH36.new(lla)
    usng = gh36.to_usng
    restored = GH36.from_usng(usng)
    restored_lla = restored.to_lla
    assert_in_delta 40.689167, restored_lla.lat, 0.01
    assert_in_delta(-74.044444, restored_lla.lng, 0.01)
  end

  # ── to_ups / from_ups ────────────────────────────────────

  def test_to_ups
    gh36 = GH36.new(LLA.new(lat: 85.0, lng: 10.0))
    ups = gh36.to_ups
    assert_instance_of UPS_C, ups
  end

  def test_from_ups_roundtrip
    lla = LLA.new(lat: 85.0, lng: 10.0)
    ups = UPS_C.from_lla(lla)
    restored = GH36.from_ups(ups)
    restored_lla = restored.to_lla
    assert_in_delta 85.0, restored_lla.lat, 6.0
    assert_in_delta 10.0, restored_lla.lng, 6.0
  end

  # ── to_state_plane / from_state_plane ─────────────────────

  def test_to_state_plane
    gh36 = GH36.new(LLA.new(lat: 25.0, lng: -81.0))
    sp = gh36.to_state_plane("FL_EAST")
    assert_instance_of SP, sp
  end

  def test_from_state_plane_roundtrip
    lla = LLA.new(lat: 25.0, lng: -81.0)
    sp = SP.from_lla(lla, "FL_EAST")
    restored = GH36.from_state_plane(sp)
    restored_lla = restored.to_lla
    assert_in_delta 25.0, restored_lla.lat, 10.0
    assert_in_delta(-81.0, restored_lla.lng, 1.0)
  end

  # ── to_bng / from_bng ────────────────────────────────────

  def test_to_bng
    gh36 = GH36.new(LLA.new(lat: 51.5, lng: -0.1))
    bng = gh36.to_bng
    assert_instance_of BNG, bng
  end

  def test_from_bng_roundtrip
    london = LLA.new(lat: 51.5, lng: -0.1)
    bng = BNG.from_lla(london)
    restored = GH36.from_bng(bng)
    restored_lla = restored.to_lla
    assert_in_delta 51.5, restored_lla.lat, 0.2
    assert_in_delta(-0.1, restored_lla.lng, 0.2)
  end

  # ── to_s with precision 0 (edge case) ────────────────────

  def test_to_s_with_precision_zero
    gh36 = GH36.new("bdrdC26BqH")
    result = gh36.to_s(0)
    assert_equal "", result
  end

  # ── from_array with custom precision ─────────────────────

  def test_from_array_with_custom_precision
    coord = GH36.from_array([40.0, -74.0])
    # Default precision is 10
    assert_equal 10, coord.precision
    assert_instance_of GH36, coord
    restored_lla = coord.to_lla
    assert_in_delta 40.0, restored_lla.lat, 0.01
    assert_in_delta(-74.0, restored_lla.lng, 0.01)
  end

  # ── GH36 class methods for conversions ──────────────────────

  def test_from_lla_class_method
    lla = LLA.new(lat: 40.7128, lng: -74.0060)
    gh = GH36.from_lla(lla)
    assert_instance_of GH36, gh
  end

  def test_from_ecef_class_method
    ecef = LLA.new(lat: 40.7128, lng: -74.0060).to_ecef
    gh = GH36.from_ecef(ecef)
    assert_instance_of GH36, gh
  end

  def test_from_utm_class_method
    utm = UTM.new(easting: 583960.0, northing: 4507351.0, zone: 18, hemisphere: 'N')
    gh = GH36.from_utm(utm)
    assert_instance_of GH36, gh
  end

  def test_to_enu_direct
    gh = GH36.new(LLA.new(lat: 40.7128, lng: -74.0060))
    ref = LLA.new(lat: 40.0, lng: -74.0)
    enu = gh.to_enu(ref)
    assert_instance_of ENU, enu
  end

  def test_from_enu_class_method
    ref = LLA.new(lat: 40.0, lng: -74.0)
    enu = ENU.new(e: 100.0, n: 200.0, u: 0.0)
    gh = GH36.from_enu(enu, ref)
    assert_instance_of GH36, gh
  end

  def test_to_ned_direct
    gh = GH36.new(LLA.new(lat: 40.7128, lng: -74.0060))
    ref = LLA.new(lat: 40.0, lng: -74.0)
    ned = gh.to_ned(ref)
    assert_instance_of NED, ned
  end

  def test_from_ned_class_method
    ref = LLA.new(lat: 40.0, lng: -74.0)
    ned = NED.new(n: 200.0, e: 100.0, d: 0.0)
    gh = GH36.from_ned(ned, ref)
    assert_instance_of GH36, gh
  end

  def test_from_web_mercator_class_method
    wm = WM.from_lla(LLA.new(lat: 40.7128, lng: -74.0060))
    gh = GH36.from_web_mercator(wm)
    assert_instance_of GH36, gh
  end

  # ── Neighbor overflow: row >= MATRIX_SIDE (south from row 5) ──

  def test_neighbors_row_overflow_south
    # 'X' is at row 5, col 5 in the GH36 matrix.
    # Going south (row_delta=+1) from row 5 triggers new_row >= MATRIX_SIDE.
    coord = GH36.new("bdrdC26BqX")
    neighbors = coord.neighbors
    assert_instance_of GH36, neighbors[:S]
    assert_instance_of GH36, neighbors[:SE]
  end

  # ── Neighbor overflow: col < 0 (west from col 0) ──────────

  def test_neighbors_col_underflow_west
    # '2' is at row 0, col 0 in the GH36 matrix.
    # Going west (col_delta=-1) from col 0 triggers new_col < 0.
    coord = GH36.new("bdrdC26Bq2")
    neighbors = coord.neighbors
    assert_instance_of GH36, neighbors[:W]
    assert_instance_of GH36, neighbors[:NW]
    assert_instance_of GH36, neighbors[:SW]
  end
end
