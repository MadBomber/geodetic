# frozen_string_literal: true

require "test_helper"
require_relative "../lib/geodetic/coordinate/gh"
require_relative "../lib/geodetic/coordinate/lla"

class GHTest < Minitest::Test
  GH          = Geodetic::Coordinate::GH
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
  GH36        = Geodetic::Coordinate::GH36

  # ── Constructor from String ────────────────────────────────

  def test_from_geohash_string
    coord = GH.new("dr5ru7")
    assert_equal "dr5ru7", coord.geohash
  end

  def test_from_geohash_string_case_insensitive
    coord = GH.new("DR5RU7")
    assert_equal "dr5ru7", coord.geohash
  end

  def test_raises_on_invalid_geohash_chars
    assert_raises(ArgumentError) { GH.new("abc!@#") }
  end

  def test_raises_on_excluded_chars
    # a, i, l, o are excluded from base-32 geohash alphabet
    assert_raises(ArgumentError) { GH.new("abcd") }
  end

  def test_raises_on_empty_geohash
    assert_raises(ArgumentError) { GH.new("") }
  end

  # ── Constructor from coordinate ────────────────────────────

  def test_from_lla
    lla = LLA.new(lat: 51.504444, lng: -0.086666)
    coord = GH.new(lla)
    assert_equal 12, coord.precision
  end

  def test_from_lla_custom_precision
    lla = LLA.new(lat: 0.0, lng: 0.0)
    coord = GH.new(lla, precision: 5)
    assert_equal 5, coord.precision
  end

  def test_from_any_coordinate_with_to_lla
    lla = LLA.new(lat: 40.689167, lng: -74.044444)
    utm = lla.to_utm
    coord = GH.new(utm)
    restored = coord.to_lla
    assert_in_delta 40.689167, restored.lat, 0.001
    assert_in_delta(-74.044444, restored.lng, 0.001)
  end

  def test_raises_on_unsupported_source
    assert_raises(ArgumentError) { GH.new(42) }
  end

  # ── Precision ──────────────────────────────────────────────

  def test_precision_matches_hash_length
    coord = GH.new("dr5ru")
    assert_equal 5, coord.precision
  end

  # ── to_s ───────────────────────────────────────────────────

  def test_to_s_returns_geohash
    coord = GH.new("dr5ru7c5g200")
    assert_equal "dr5ru7c5g200", coord.to_s
  end

  def test_to_s_with_truncation
    coord = GH.new("dr5ru7c5g200")
    assert_equal "dr5ru", coord.to_s(5)
  end

  # ── to_a ───────────────────────────────────────────────────

  def test_to_a_returns_lat_lng
    lla = LLA.new(lat: 40.0, lng: -74.0)
    coord = GH.new(lla)
    result = coord.to_a
    assert_equal 2, result.size
    assert_in_delta 40.0, result[0], 0.01
    assert_in_delta(-74.0, result[1], 0.01)
  end

  # ── from_array / from_string ─────────────────────────────

  def test_from_array
    coord = GH.from_array([40.689167, -74.044444])
    lla = coord.to_lla
    assert_in_delta 40.689167, lla.lat, 0.001
    assert_in_delta(-74.044444, lla.lng, 0.001)
  end

  def test_from_string
    coord = GH.from_string("dr5ru7")
    assert_equal "dr5ru7", coord.geohash
  end

  # ── Encode / Decode roundtrip ────────────────────────────

  def test_roundtrip_origin
    coord = GH.new(LLA.new(lat: 0.0, lng: 0.0))
    restored = coord.to_lla
    assert_in_delta 0.0, restored.lat, 0.001
    assert_in_delta 0.0, restored.lng, 0.001
  end

  def test_roundtrip_statue_of_liberty
    coord = GH.new(LLA.new(lat: 40.689167, lng: -74.044444))
    restored = coord.to_lla
    assert_in_delta 40.689167, restored.lat, 0.001
    assert_in_delta(-74.044444, restored.lng, 0.001)
  end

  def test_roundtrip_london
    coord = GH.new(LLA.new(lat: 51.504444, lng: -0.086666))
    restored = coord.to_lla
    assert_in_delta 51.504444, restored.lat, 0.001
    assert_in_delta(-0.086666, restored.lng, 0.001)
  end

  def test_roundtrip_southern_hemisphere
    coord = GH.new(LLA.new(lat: -33.8688, lng: 151.2093))
    restored = coord.to_lla
    assert_in_delta(-33.8688, restored.lat, 0.001)
    assert_in_delta 151.2093, restored.lng, 0.001
  end

  def test_roundtrip_extreme_coordinates
    coord = GH.new(LLA.new(lat: 89.9, lng: 179.9))
    restored = coord.to_lla
    assert_in_delta 89.9, restored.lat, 0.01
    assert_in_delta 179.9, restored.lng, 0.01
  end

  def test_roundtrip_negative_extremes
    coord = GH.new(LLA.new(lat: -89.9, lng: -179.9))
    restored = coord.to_lla
    assert_in_delta(-89.9, restored.lat, 0.01)
    assert_in_delta(-179.9, restored.lng, 0.01)
  end

  # ── Known geohash values ──────────────────────────────────

  def test_known_geohash_new_york
    # "dr5ru7" is a well-known geohash for NYC area
    coord = GH.new("dr5ru7")
    lla = coord.to_lla
    assert_in_delta 40.71, lla.lat, 0.1
    assert_in_delta(-74.01, lla.lng, 0.1)
  end

  def test_known_geohash_london
    # "gcpvj0" is a well-known geohash for London area
    coord = GH.new("gcpvj0")
    lla = coord.to_lla
    assert_in_delta 51.5, lla.lat, 0.1
    assert_in_delta(-0.1, lla.lng, 0.15)
  end

  # ── LLA convenience methods ─────────────────────────────

  def test_lla_to_gh
    lla = LLA.new(lat: 40.689167, lng: -74.044444)
    gh = lla.to_gh
    assert_instance_of GH, gh
    restored = gh.to_lla
    assert_in_delta 40.689167, restored.lat, 0.001
    assert_in_delta(-74.044444, restored.lng, 0.001)
  end

  def test_lla_from_gh
    gh = GH.new(LLA.new(lat: 40.689167, lng: -74.044444))
    lla = LLA.from_gh(gh)
    assert_instance_of LLA, lla
    assert_in_delta 40.689167, lla.lat, 0.001
  end

  def test_lla_to_gh_custom_precision
    lla = LLA.new(lat: 40.0, lng: -74.0)
    gh = lla.to_gh(precision: 5)
    assert_equal 5, gh.precision
  end

  # ── Equality ─────────────────────────────────────────────

  def test_equality_same_hash
    a = GH.new("dr5ru7")
    b = GH.new("dr5ru7")
    assert_equal a, b
  end

  def test_equality_different_hash
    a = GH.new("dr5ru7")
    b = GH.new("dr5ru8")
    refute_equal a, b
  end

  def test_equality_non_gh
    coord = GH.new("dr5ru7")
    refute_equal coord, "dr5ru7"
  end

  # ── valid? ───────────────────────────────────────────────

  def test_valid_hash
    coord = GH.new("dr5ru7")
    assert coord.valid?
  end

  # ── Neighbors ────────────────────────────────────────────

  def test_neighbors_returns_all_eight
    coord = GH.new("dr5ru7")
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

  def test_neighbors_returns_gh_instances
    coord = GH.new("dr5ru7")
    all = coord.neighbors
    all.each_value do |neighbor|
      assert_instance_of GH, neighbor
    end
  end

  def test_neighbors_differ_from_original
    coord = GH.new("dr5ru7")
    coord.neighbors.each_value do |neighbor|
      refute_equal coord, neighbor
    end
  end

  def test_north_neighbor_has_higher_latitude
    lla = LLA.new(lat: 40.0, lng: -74.0)
    coord = GH.new(lla)
    north = coord.neighbors[:N]
    assert north.to_lla.lat > coord.to_lla.lat,
      "North neighbor should have higher latitude"
  end

  def test_south_neighbor_has_lower_latitude
    lla = LLA.new(lat: 40.0, lng: -74.0)
    coord = GH.new(lla)
    south = coord.neighbors[:S]
    assert south.to_lla.lat < coord.to_lla.lat,
      "South neighbor should have lower latitude"
  end

  def test_east_neighbor_has_higher_longitude
    lla = LLA.new(lat: 40.0, lng: -74.0)
    coord = GH.new(lla)
    east = coord.neighbors[:E]
    assert east.to_lla.lng > coord.to_lla.lng,
      "East neighbor should have higher longitude"
  end

  def test_west_neighbor_has_lower_longitude
    lla = LLA.new(lat: 40.0, lng: -74.0)
    coord = GH.new(lla)
    west = coord.neighbors[:W]
    assert west.to_lla.lng < coord.to_lla.lng,
      "West neighbor should have lower longitude"
  end

  def test_neighbor_chainable
    coord = GH.new(LLA.new(lat: 40.0, lng: -74.0))
    north_lla = coord.neighbors[:N].to_lla
    assert_instance_of LLA, north_lla
  end

  def test_neighbors_preserve_precision
    coord = GH.new("dr5ru7")
    coord.neighbors.each_value do |neighbor|
      assert_equal coord.precision, neighbor.precision
    end
  end

  # ── Diagonal neighbors ────────────────────────────────

  def test_ne_neighbor_direction
    coord = GH.new(LLA.new(lat: 40.0, lng: -74.0))
    ne = coord.neighbors[:NE]
    assert ne.to_lla.lat > coord.to_lla.lat,
      "NE neighbor should have higher latitude"
    assert ne.to_lla.lng > coord.to_lla.lng,
      "NE neighbor should have higher longitude"
  end

  def test_sw_neighbor_direction
    coord = GH.new(LLA.new(lat: 40.0, lng: -74.0))
    sw = coord.neighbors[:SW]
    assert sw.to_lla.lat < coord.to_lla.lat,
      "SW neighbor should have lower latitude"
    assert sw.to_lla.lng < coord.to_lla.lng,
      "SW neighbor should have lower longitude"
  end

  # ── to_area ──────────────────────────────────────────────

  def test_to_area_returns_rectangle
    coord = GH.new("dr5ru7")
    area = coord.to_area
    assert_instance_of Geodetic::Areas::BoundingBox, area
  end

  def test_to_area_contains_midpoint
    lla = LLA.new(lat: 40.0, lng: -74.0)
    coord = GH.new(lla)
    area = coord.to_area
    assert area.includes?(coord.to_lla)
  end

  def test_to_area_excludes_distant_point
    lla = LLA.new(lat: 40.0, lng: -74.0)
    coord = GH.new(lla)
    area = coord.to_area
    assert area.excludes?(LLA.new(lat: 0.0, lng: 0.0))
  end

  def test_to_area_nw_is_north_and_west_of_se
    coord = GH.new(LLA.new(lat: 40.0, lng: -74.0))
    area = coord.to_area
    assert area.nw.lat > area.se.lat
    assert area.nw.lng < area.se.lng
  end

  # ── Precision in meters ─────────────────────────────────

  def test_precision_in_meters
    lla = LLA.new(lat: 0.0, lng: 0.0)
    coord = GH.new(lla)
    prec = coord.precision_in_meters
    assert prec[:lat] > 0
    assert prec[:lng] > 0
  end

  def test_longer_hash_has_finer_precision
    lla = LLA.new(lat: 0.0, lng: 0.0)
    short = GH.new(lla, precision: 5)
    long  = GH.new(lla, precision: 12)
    assert long.precision_in_meters[:lat] < short.precision_in_meters[:lat]
  end

  # ── distance_to (via mixin) ─────────────────────────────

  def test_distance_to
    a = GH.new(LLA.new(lat: 40.689167, lng: -74.044444))
    b = GH.new(LLA.new(lat: 51.504444, lng: -0.086666))
    dist = a.distance_to(b)
    assert_instance_of Geodetic::Distance, dist
    # NYC to London is roughly 5,570 km
    assert_in_delta 5_570_000, dist.to_f, 50_000
  end

  # ── bearing_to (via mixin) ──────────────────────────────

  def test_bearing_to
    a = GH.new(LLA.new(lat: 40.689167, lng: -74.044444))
    b = GH.new(LLA.new(lat: 51.504444, lng: -0.086666))
    bearing = a.bearing_to(b)
    assert_instance_of Geodetic::Bearing, bearing
    # NYC to London bearing is roughly 51 degrees
    assert_in_delta 51.0, bearing.degrees, 5.0
  end

  # ── Immutability ────────────────────────────────────────

  def test_no_setter_for_geohash
    coord = GH.new("dr5ru7")
    assert_raises(NoMethodError) { coord.geohash = "xxx" }
  end

  # ── to_s with precision 0 (edge case) ────────────────────

  def test_to_s_with_precision_zero
    gh = GH.new("dr5ru7")
    result = gh.to_s(0)
    assert_equal "", result
  end

  # ── from_array default precision ─────────────────────────

  def test_from_array_default_precision
    coord = GH.from_array([40.0, -74.0])
    assert_equal 12, coord.precision
  end

  # ── Cross-system conversion roundtrips ─────────────────

  def test_to_ecef_roundtrip
    gh = GH.new(LLA.new(lat: 40.689167, lng: -74.044444))
    ecef = gh.to_ecef
    restored = GH.new(ecef)
    restored_lla = restored.to_lla
    assert_in_delta 40.689167, restored_lla.lat, 0.001
    assert_in_delta(-74.044444, restored_lla.lng, 0.001)
  end

  def test_to_utm_roundtrip
    gh = GH.new(LLA.new(lat: 40.689167, lng: -74.044444))
    utm = gh.to_utm
    restored = GH.new(utm)
    restored_lla = restored.to_lla
    assert_in_delta 40.689167, restored_lla.lat, 0.001
    assert_in_delta(-74.044444, restored_lla.lng, 0.001)
  end

  def test_to_web_mercator_roundtrip
    gh = GH.new(LLA.new(lat: 40.689167, lng: -74.044444))
    wm = gh.to_web_mercator
    restored = GH.new(wm)
    restored_lla = restored.to_lla
    assert_in_delta 40.689167, restored_lla.lat, 0.001
    assert_in_delta(-74.044444, restored_lla.lng, 0.001)
  end

  # ── to_enu / from_enu ────────────────────────────────────

  def test_to_enu
    ref = LLA.new(lat: 40.0, lng: -74.0)
    gh = GH.new(LLA.new(lat: 40.689167, lng: -74.044444))
    enu = gh.to_enu(ref)
    assert_instance_of ENU, enu
  end

  def test_from_enu_roundtrip
    ref = LLA.new(lat: 40.0, lng: -74.0)
    lla = LLA.new(lat: 40.689167, lng: -74.044444)
    gh = GH.new(lla)
    enu = gh.to_enu(ref)
    restored_lla = enu.to_lla(ref)
    restored = GH.new(restored_lla)
    final_lla = restored.to_lla
    assert_in_delta 40.689167, final_lla.lat, 0.01
    assert_in_delta(-74.044444, final_lla.lng, 0.01)
  end

  # ── to_ned / from_ned ────────────────────────────────────

  def test_to_ned
    ref = LLA.new(lat: 40.0, lng: -74.0)
    gh = GH.new(LLA.new(lat: 40.689167, lng: -74.044444))
    ned = gh.to_ned(ref)
    assert_instance_of NED, ned
  end

  def test_from_ned_roundtrip
    ref = LLA.new(lat: 40.0, lng: -74.0)
    lla = LLA.new(lat: 40.689167, lng: -74.044444)
    gh = GH.new(lla)
    ned = gh.to_ned(ref)
    restored_lla = ned.to_lla(ref)
    restored = GH.new(restored_lla)
    final_lla = restored.to_lla
    assert_in_delta 40.689167, final_lla.lat, 0.01
    assert_in_delta(-74.044444, final_lla.lng, 0.01)
  end

  # ── to_mgrs / from_mgrs ──────────────────────────────────

  def test_to_mgrs
    gh = GH.new(LLA.new(lat: 40.689167, lng: -74.044444))
    mgrs = gh.to_mgrs
    assert_instance_of MGRS, mgrs
  end

  def test_from_mgrs_roundtrip
    lla = LLA.new(lat: 40.689167, lng: -74.044444)
    gh = GH.new(lla)
    mgrs = gh.to_mgrs
    restored = GH.from_mgrs(mgrs)
    restored_lla = restored.to_lla
    assert_in_delta 40.689167, restored_lla.lat, 0.01
    assert_in_delta(-74.044444, restored_lla.lng, 0.01)
  end

  # ── to_usng / from_usng ──────────────────────────────────

  def test_to_usng
    gh = GH.new(LLA.new(lat: 40.689167, lng: -74.044444))
    usng = gh.to_usng
    assert_instance_of USNG, usng
  end

  def test_from_usng_roundtrip
    lla = LLA.new(lat: 40.689167, lng: -74.044444)
    gh = GH.new(lla)
    usng = gh.to_usng
    restored = GH.from_usng(usng)
    restored_lla = restored.to_lla
    assert_in_delta 40.689167, restored_lla.lat, 0.01
    assert_in_delta(-74.044444, restored_lla.lng, 0.01)
  end

  # ── to_ups / from_ups ────────────────────────────────────

  def test_to_ups
    gh = GH.new(LLA.new(lat: 85.0, lng: 10.0))
    ups = gh.to_ups
    assert_instance_of UPS_C, ups
  end

  def test_from_ups_roundtrip
    lla = LLA.new(lat: 85.0, lng: 10.0)
    ups = UPS_C.from_lla(lla)
    restored = GH.from_ups(ups)
    restored_lla = restored.to_lla
    assert_in_delta 85.0, restored_lla.lat, 6.0
    assert_in_delta 10.0, restored_lla.lng, 6.0
  end

  # ── to_state_plane / from_state_plane ─────────────────────

  def test_to_state_plane
    gh = GH.new(LLA.new(lat: 25.0, lng: -81.0))
    sp = gh.to_state_plane("FL_EAST")
    assert_instance_of SP, sp
  end

  def test_from_state_plane_roundtrip
    lla = LLA.new(lat: 25.0, lng: -81.0)
    sp = SP.from_lla(lla, "FL_EAST")
    restored = GH.from_state_plane(sp)
    restored_lla = restored.to_lla
    assert_in_delta 25.0, restored_lla.lat, 10.0
    assert_in_delta(-81.0, restored_lla.lng, 1.0)
  end

  # ── to_bng / from_bng ────────────────────────────────────

  def test_to_bng
    gh = GH.new(LLA.new(lat: 51.5, lng: -0.1))
    bng = gh.to_bng
    assert_instance_of BNG, bng
  end

  def test_from_bng_roundtrip
    london = LLA.new(lat: 51.5, lng: -0.1)
    bng = BNG.from_lla(london)
    restored = GH.from_bng(bng)
    restored_lla = restored.to_lla
    assert_in_delta 51.5, restored_lla.lat, 0.2
    assert_in_delta(-0.1, restored_lla.lng, 0.2)
  end

  # ── to_gh36 / from_gh36 ──────────────────────────────────

  def test_to_gh36
    gh = GH.new(LLA.new(lat: 40.689167, lng: -74.044444))
    gh36 = gh.to_gh36
    assert_instance_of GH36, gh36
  end

  def test_from_gh36_roundtrip
    lla = LLA.new(lat: 40.689167, lng: -74.044444)
    gh36 = GH36.new(lla)
    restored = GH.from_gh36(gh36)
    restored_lla = restored.to_lla
    assert_in_delta 40.689167, restored_lla.lat, 0.01
    assert_in_delta(-74.044444, restored_lla.lng, 0.01)
  end

  # ── GH class methods for conversions ──────────────────────

  def test_from_lla_class_method
    lla = LLA.new(lat: 40.7128, lng: -74.0060)
    gh = GH.from_lla(lla)
    assert_instance_of GH, gh
  end

  def test_from_ecef_class_method
    ecef = LLA.new(lat: 40.7128, lng: -74.0060).to_ecef
    gh = GH.from_ecef(ecef)
    assert_instance_of GH, gh
  end

  def test_from_utm_class_method
    utm = UTM.new(easting: 583960.0, northing: 4507351.0, zone: 18, hemisphere: 'N')
    gh = GH.from_utm(utm)
    assert_instance_of GH, gh
  end

  def test_to_enu_direct
    gh = GH.new(LLA.new(lat: 40.7128, lng: -74.0060))
    ref = LLA.new(lat: 40.0, lng: -74.0)
    enu = gh.to_enu(ref)
    assert_instance_of ENU, enu
  end

  def test_from_enu_class_method
    ref = LLA.new(lat: 40.0, lng: -74.0)
    enu = ENU.new(e: 100.0, n: 200.0, u: 0.0)
    gh = GH.from_enu(enu, ref)
    assert_instance_of GH, gh
  end

  def test_to_ned_direct
    gh = GH.new(LLA.new(lat: 40.7128, lng: -74.0060))
    ref = LLA.new(lat: 40.0, lng: -74.0)
    ned = gh.to_ned(ref)
    assert_instance_of NED, ned
  end

  def test_from_ned_class_method
    ref = LLA.new(lat: 40.0, lng: -74.0)
    ned = NED.new(n: 200.0, e: 100.0, d: 0.0)
    gh = GH.from_ned(ned, ref)
    assert_instance_of GH, gh
  end

  def test_from_web_mercator_class_method
    wm = WM.from_lla(LLA.new(lat: 40.7128, lng: -74.0060))
    gh = GH.from_web_mercator(wm)
    assert_instance_of GH, gh
  end

  # ── Other coordinate classes' to_gh / from_gh ─────────────

  def test_ecef_to_gh
    ecef = LLA.new(lat: 40.7128, lng: -74.0060).to_ecef
    gh = ecef.to_gh
    assert_instance_of GH, gh
    lla = gh.to_lla
    assert_in_delta 40.7128, lla.lat, 0.001
  end

  def test_ecef_from_gh
    gh = GH.new(LLA.new(lat: 40.7128, lng: -74.0060))
    ecef = ECEF.from_gh(gh)
    assert_instance_of ECEF, ecef
  end

  def test_utm_to_gh
    utm = LLA.new(lat: 40.7128, lng: -74.0060).to_utm
    gh = utm.to_gh
    assert_instance_of GH, gh
  end

  def test_utm_from_gh
    gh = GH.new(LLA.new(lat: 40.7128, lng: -74.0060))
    utm = UTM.from_gh(gh)
    assert_instance_of UTM, utm
  end

  def test_enu_to_gh
    ref = LLA.new(lat: 40.0, lng: -74.0)
    enu = ENU.new(e: 100.0, n: 200.0, u: 0.0)
    gh = enu.to_gh(ref)
    assert_instance_of GH, gh
  end

  def test_enu_from_gh
    ref = LLA.new(lat: 40.0, lng: -74.0)
    gh = GH.new(LLA.new(lat: 40.001, lng: -73.999))
    enu = ENU.from_gh(gh, ref)
    assert_instance_of ENU, enu
  end

  def test_ned_to_gh
    ref = LLA.new(lat: 40.0, lng: -74.0)
    ned = NED.new(n: 200.0, e: 100.0, d: 0.0)
    gh = ned.to_gh(ref)
    assert_instance_of GH, gh
  end

  def test_ned_from_gh
    ref = LLA.new(lat: 40.0, lng: -74.0)
    gh = GH.new(LLA.new(lat: 40.001, lng: -73.999))
    ned = NED.from_gh(gh, ref)
    assert_instance_of NED, ned
  end

  def test_mgrs_to_gh
    mgrs = LLA.new(lat: 40.7128, lng: -74.0060).to_utm.to_lla.to_utm
    mgrs_coord = MGRS.from_lla(LLA.new(lat: 40.7128, lng: -74.0060))
    gh = mgrs_coord.to_gh
    assert_instance_of GH, gh
  end

  def test_mgrs_from_gh
    gh = GH.new(LLA.new(lat: 40.7128, lng: -74.0060))
    mgrs = MGRS.from_gh(gh)
    assert_instance_of MGRS, mgrs
  end

  def test_usng_to_gh
    usng = USNG.from_lla(LLA.new(lat: 40.7128, lng: -74.0060))
    gh = usng.to_gh
    assert_instance_of GH, gh
  end

  def test_usng_from_gh
    gh = GH.new(LLA.new(lat: 40.7128, lng: -74.0060))
    usng = USNG.from_gh(gh)
    assert_instance_of USNG, usng
  end

  def test_web_mercator_to_gh
    wm = WM.from_lla(LLA.new(lat: 40.7128, lng: -74.0060))
    gh = wm.to_gh
    assert_instance_of GH, gh
  end

  def test_web_mercator_from_gh
    gh = GH.new(LLA.new(lat: 40.7128, lng: -74.0060))
    wm = WM.from_gh(gh)
    assert_instance_of WM, wm
  end

  def test_ups_to_gh
    ups = UPS_C.from_lla(LLA.new(lat: 85.0, lng: 10.0))
    gh = ups.to_gh
    assert_instance_of GH, gh
  end

  def test_ups_from_gh
    gh = GH.new(LLA.new(lat: 85.0, lng: 10.0))
    ups = UPS_C.from_gh(gh)
    assert_instance_of UPS_C, ups
  end

  def test_state_plane_to_gh
    sp = SP.from_lla(LLA.new(lat: 25.0, lng: -81.0), "FL_EAST")
    gh = sp.to_gh
    assert_instance_of GH, gh
  end

  def test_state_plane_from_gh
    gh = GH.new(LLA.new(lat: 25.0, lng: -81.0))
    sp = SP.from_gh(gh, "FL_EAST")
    assert_instance_of SP, sp
  end

  def test_bng_to_gh
    bng = BNG.from_lla(LLA.new(lat: 51.5, lng: -0.1))
    gh = bng.to_gh
    assert_instance_of GH, gh
  end

  def test_bng_from_gh
    gh = GH.new(LLA.new(lat: 51.5, lng: -0.1))
    bng = BNG.from_gh(gh)
    assert_instance_of BNG, bng
  end

  def test_gh36_to_gh
    gh36 = GH36.new(LLA.new(lat: 40.7128, lng: -74.0060))
    gh = gh36.to_gh
    assert_instance_of GH, gh
  end

  def test_gh36_from_gh
    gh = GH.new(LLA.new(lat: 40.7128, lng: -74.0060))
    gh36 = GH36.from_gh(gh)
    assert_instance_of GH36, gh36
  end

  # ── Base-32 alphabet validation ──────────────────────────

  def test_base32_alphabet_excludes_a_i_l_o
    refute GH::BASE32.include?('a')
    refute GH::BASE32.include?('i')
    refute GH::BASE32.include?('l')
    refute GH::BASE32.include?('o')
  end

  def test_base32_alphabet_has_32_chars
    assert_equal 32, GH::BASE32.length
  end

  # ── Neighbor longitude wrapping ──────────────────────────

  def test_neighbors_near_antimeridian
    # Near the antimeridian (180/-180 boundary)
    coord = GH.new(LLA.new(lat: 0.0, lng: 179.99))
    neighbors = coord.neighbors
    assert_instance_of GH, neighbors[:E]
    # East neighbor should wrap around
    east_lng = neighbors[:E].to_lla.lng
    assert east_lng < 0 || east_lng > coord.to_lla.lng,
      "East neighbor near antimeridian should wrap"
  end

  def test_neighbors_near_north_pole
    coord = GH.new(LLA.new(lat: 89.99, lng: 0.0))
    neighbors = coord.neighbors
    assert_instance_of GH, neighbors[:N]
  end
end
