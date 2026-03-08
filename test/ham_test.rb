# frozen_string_literal: true

require "test_helper"
require_relative "../lib/geodetic/coordinates/ham"
require_relative "../lib/geodetic/coordinates/lla"

class HAMTest < Minitest::Test
  HAM         = Geodetic::Coordinates::HAM
  LLA         = Geodetic::Coordinates::LLA
  ECEF        = Geodetic::Coordinates::ECEF
  UTM         = Geodetic::Coordinates::UTM
  ENU         = Geodetic::Coordinates::ENU
  NED         = Geodetic::Coordinates::NED
  MGRS        = Geodetic::Coordinates::MGRS
  USNG        = Geodetic::Coordinates::USNG
  WM          = Geodetic::Coordinates::WebMercator
  UPS_C       = Geodetic::Coordinates::UPS
  SP          = Geodetic::Coordinates::StatePlane
  BNG         = Geodetic::Coordinates::BNG
  GH36        = Geodetic::Coordinates::GH36
  GH          = Geodetic::Coordinates::GH

  # ── Constructor from String ────────────────────────────────

  def test_from_locator_string
    coord = HAM.new("FN31pr")
    assert_equal "FN31pr", coord.locator
  end

  def test_from_locator_string_normalizes_case
    coord = HAM.new("fn31PR")
    assert_equal "FN31pr", coord.locator
  end

  def test_from_field_only
    coord = HAM.new("FN")
    assert_equal "FN", coord.locator
    assert_equal 2, coord.precision
  end

  def test_from_square_level
    coord = HAM.new("FN31")
    assert_equal "FN31", coord.locator
    assert_equal 4, coord.precision
  end

  def test_from_extended_level
    coord = HAM.new("FN31pr58")
    assert_equal "FN31pr58", coord.locator
    assert_equal 8, coord.precision
  end

  def test_raises_on_empty_string
    assert_raises(ArgumentError) { HAM.new("") }
  end

  def test_raises_on_odd_length
    assert_raises(ArgumentError) { HAM.new("FN3") }
  end

  def test_raises_on_too_long
    assert_raises(ArgumentError) { HAM.new("FN31pr5678") }
  end

  def test_raises_on_invalid_field_chars
    # S is out of range for field (A-R only)
    assert_raises(ArgumentError) { HAM.new("SN31pr") }
  end

  def test_raises_on_invalid_subsquare_chars
    # y is out of range for subsquare (a-x only)
    assert_raises(ArgumentError) { HAM.new("FN31yy") }
  end

  # ── Constructor from coordinate ────────────────────────────

  def test_from_lla
    lla = LLA.new(lat: 40.7128, lng: -74.0060)
    coord = HAM.new(lla)
    assert_equal 6, coord.precision
  end

  def test_from_lla_custom_precision
    lla = LLA.new(lat: 0.0, lng: 0.0)
    coord = HAM.new(lla, precision: 4)
    assert_equal 4, coord.precision
  end

  def test_from_lla_extended_precision
    lla = LLA.new(lat: 40.7128, lng: -74.0060)
    coord = HAM.new(lla, precision: 8)
    assert_equal 8, coord.precision
  end

  def test_from_any_coordinate_with_to_lla
    lla = LLA.new(lat: 40.689167, lng: -74.044444)
    utm = lla.to_utm
    coord = HAM.new(utm)
    restored = coord.to_lla
    assert_in_delta 40.689167, restored.lat, 0.05
    assert_in_delta(-74.044444, restored.lng, 0.1)
  end

  def test_raises_on_unsupported_source
    assert_raises(ArgumentError) { HAM.new(42) }
  end

  # ── Precision ──────────────────────────────────────────────

  def test_precision_matches_locator_length
    assert_equal 2, HAM.new("FN").precision
    assert_equal 4, HAM.new("FN31").precision
    assert_equal 6, HAM.new("FN31pr").precision
    assert_equal 8, HAM.new("FN31pr58").precision
  end

  # ── to_s ───────────────────────────────────────────────────

  def test_to_s_returns_locator
    coord = HAM.new("FN31pr")
    assert_equal "FN31pr", coord.to_s
  end

  def test_to_s_with_truncation
    coord = HAM.new("FN31pr58")
    assert_equal "FN31pr", coord.to_s(6)
    assert_equal "FN31", coord.to_s(4)
    assert_equal "FN", coord.to_s(2)
  end

  def test_to_s_truncation_rounds_to_even
    coord = HAM.new("FN31pr")
    # Odd truncation should round down to even
    assert_equal "FN31", coord.to_s(5)
    assert_equal "FN", coord.to_s(3)
  end

  def test_to_s_truncation_minimum_is_2
    coord = HAM.new("FN31pr")
    assert_equal "FN", coord.to_s(1)
    assert_equal "FN", coord.to_s(0)
  end

  # ── to_a ───────────────────────────────────────────────────

  def test_to_a_returns_lat_lng
    lla = LLA.new(lat: 40.0, lng: -74.0)
    coord = HAM.new(lla)
    result = coord.to_a
    assert_equal 2, result.size
    assert_in_delta 40.0, result[0], 0.05
    assert_in_delta(-74.0, result[1], 0.1)
  end

  # ── from_array / from_string ─────────────────────────────

  def test_from_array
    coord = HAM.from_array([40.689167, -74.044444])
    lla = coord.to_lla
    assert_in_delta 40.689167, lla.lat, 0.05
    assert_in_delta(-74.044444, lla.lng, 0.1)
  end

  def test_from_string
    coord = HAM.from_string("FN31pr")
    assert_equal "FN31pr", coord.locator
  end

  # ── Known Maidenhead values ────────────────────────────────

  def test_known_locator_new_york
    # New York City is in grid square FN30
    lla = LLA.new(lat: 40.7128, lng: -74.0060)
    coord = HAM.new(lla, precision: 4)
    assert_equal "FN", coord.locator[0, 2]
  end

  def test_known_locator_london
    # London is roughly in IO91
    lla = LLA.new(lat: 51.5074, lng: -0.1278)
    coord = HAM.new(lla, precision: 4)
    assert_equal "IO91", coord.locator
  end

  def test_known_locator_origin
    # (0,0) should be in JJ00
    lla = LLA.new(lat: 0.0, lng: 0.0)
    coord = HAM.new(lla, precision: 4)
    assert_equal "JJ00", coord.locator
  end

  def test_known_locator_south_pole_area
    lla = LLA.new(lat: -89.0, lng: 0.0)
    coord = HAM.new(lla, precision: 4)
    # Lat -89 + 90 = 1, so field_lat = floor(1/10) = 0 = 'A'
    assert_equal 'A', coord.locator[1]
  end

  # ── Encode / Decode roundtrip ────────────────────────────

  def test_roundtrip_origin
    coord = HAM.new(LLA.new(lat: 0.0, lng: 0.0))
    restored = coord.to_lla
    assert_in_delta 0.0, restored.lat, 0.05
    assert_in_delta 0.0, restored.lng, 0.1
  end

  def test_roundtrip_new_york
    coord = HAM.new(LLA.new(lat: 40.7128, lng: -74.0060))
    restored = coord.to_lla
    assert_in_delta 40.7128, restored.lat, 0.05
    assert_in_delta(-74.0060, restored.lng, 0.1)
  end

  def test_roundtrip_london
    coord = HAM.new(LLA.new(lat: 51.504444, lng: -0.086666))
    restored = coord.to_lla
    assert_in_delta 51.504444, restored.lat, 0.05
    assert_in_delta(-0.086666, restored.lng, 0.1)
  end

  def test_roundtrip_southern_hemisphere
    coord = HAM.new(LLA.new(lat: -33.8688, lng: 151.2093))
    restored = coord.to_lla
    assert_in_delta(-33.8688, restored.lat, 0.05)
    assert_in_delta 151.2093, restored.lng, 0.1
  end

  def test_roundtrip_extreme_coordinates
    coord = HAM.new(LLA.new(lat: 89.9, lng: 179.9))
    restored = coord.to_lla
    assert_in_delta 89.9, restored.lat, 0.05
    assert_in_delta 179.9, restored.lng, 0.1
  end

  def test_roundtrip_negative_extremes
    coord = HAM.new(LLA.new(lat: -89.9, lng: -179.9))
    restored = coord.to_lla
    assert_in_delta(-89.9, restored.lat, 0.05)
    assert_in_delta(-179.9, restored.lng, 0.1)
  end

  def test_roundtrip_extended_precision
    coord = HAM.new(LLA.new(lat: 40.7128, lng: -74.0060), precision: 8)
    restored = coord.to_lla
    assert_in_delta 40.7128, restored.lat, 0.005
    assert_in_delta(-74.0060, restored.lng, 0.01)
  end

  # ── LLA convenience methods ─────────────────────────────

  def test_lla_to_ham
    lla = LLA.new(lat: 40.689167, lng: -74.044444)
    ham = lla.to_ham
    assert_instance_of HAM, ham
    restored = ham.to_lla
    assert_in_delta 40.689167, restored.lat, 0.05
  end

  def test_lla_from_ham
    ham = HAM.new(LLA.new(lat: 40.689167, lng: -74.044444))
    lla = LLA.from_ham(ham)
    assert_instance_of LLA, lla
    assert_in_delta 40.689167, lla.lat, 0.05
  end

  def test_lla_to_ham_custom_precision
    lla = LLA.new(lat: 40.0, lng: -74.0)
    ham = lla.to_ham(precision: 4)
    assert_equal 4, ham.precision
  end

  # ── Equality ─────────────────────────────────────────────

  def test_equality_same_locator
    a = HAM.new("FN31pr")
    b = HAM.new("FN31pr")
    assert_equal a, b
  end

  def test_equality_different_locator
    a = HAM.new("FN31pr")
    b = HAM.new("FN31ps")
    refute_equal a, b
  end

  def test_equality_non_ham
    coord = HAM.new("FN31pr")
    refute_equal coord, "FN31pr"
  end

  # ── valid? ───────────────────────────────────────────────

  def test_valid_locator
    assert HAM.new("FN31pr").valid?
    assert HAM.new("FN").valid?
    assert HAM.new("FN31").valid?
    assert HAM.new("FN31pr58").valid?
  end

  # ── Neighbors ────────────────────────────────────────────

  def test_neighbors_returns_all_eight
    coord = HAM.new("FN31pr")
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

  def test_neighbors_returns_ham_instances
    coord = HAM.new("FN31pr")
    all = coord.neighbors
    all.each_value do |neighbor|
      assert_instance_of HAM, neighbor
    end
  end

  def test_neighbors_differ_from_original
    coord = HAM.new("FN31pr")
    coord.neighbors.each_value do |neighbor|
      refute_equal coord, neighbor
    end
  end

  def test_north_neighbor_has_higher_latitude
    lla = LLA.new(lat: 40.0, lng: -74.0)
    coord = HAM.new(lla)
    north = coord.neighbors[:N]
    assert north.to_lla.lat > coord.to_lla.lat,
      "North neighbor should have higher latitude"
  end

  def test_south_neighbor_has_lower_latitude
    lla = LLA.new(lat: 40.0, lng: -74.0)
    coord = HAM.new(lla)
    south = coord.neighbors[:S]
    assert south.to_lla.lat < coord.to_lla.lat,
      "South neighbor should have lower latitude"
  end

  def test_east_neighbor_has_higher_longitude
    lla = LLA.new(lat: 40.0, lng: -74.0)
    coord = HAM.new(lla)
    east = coord.neighbors[:E]
    assert east.to_lla.lng > coord.to_lla.lng,
      "East neighbor should have higher longitude"
  end

  def test_west_neighbor_has_lower_longitude
    lla = LLA.new(lat: 40.0, lng: -74.0)
    coord = HAM.new(lla)
    west = coord.neighbors[:W]
    assert west.to_lla.lng < coord.to_lla.lng,
      "West neighbor should have lower longitude"
  end

  def test_neighbors_preserve_precision
    coord = HAM.new("FN31pr")
    coord.neighbors.each_value do |neighbor|
      assert_equal coord.precision, neighbor.precision
    end
  end

  # ── Diagonal neighbors ────────────────────────────────

  def test_ne_neighbor_direction
    coord = HAM.new(LLA.new(lat: 40.0, lng: -74.0))
    ne = coord.neighbors[:NE]
    assert ne.to_lla.lat > coord.to_lla.lat,
      "NE neighbor should have higher latitude"
    assert ne.to_lla.lng > coord.to_lla.lng,
      "NE neighbor should have higher longitude"
  end

  def test_sw_neighbor_direction
    coord = HAM.new(LLA.new(lat: 40.0, lng: -74.0))
    sw = coord.neighbors[:SW]
    assert sw.to_lla.lat < coord.to_lla.lat,
      "SW neighbor should have lower latitude"
    assert sw.to_lla.lng < coord.to_lla.lng,
      "SW neighbor should have lower longitude"
  end

  # ── to_area ──────────────────────────────────────────────

  def test_to_area_returns_rectangle
    coord = HAM.new("FN31pr")
    area = coord.to_area
    assert_instance_of Geodetic::Areas::Rectangle, area
  end

  def test_to_area_contains_midpoint
    lla = LLA.new(lat: 40.0, lng: -74.0)
    coord = HAM.new(lla)
    area = coord.to_area
    assert area.includes?(coord.to_lla)
  end

  def test_to_area_excludes_distant_point
    lla = LLA.new(lat: 40.0, lng: -74.0)
    coord = HAM.new(lla)
    area = coord.to_area
    assert area.excludes?(LLA.new(lat: 0.0, lng: 0.0))
  end

  def test_to_area_nw_is_north_and_west_of_se
    coord = HAM.new(LLA.new(lat: 40.0, lng: -74.0))
    area = coord.to_area
    assert area.nw.lat > area.se.lat
    assert area.nw.lng < area.se.lng
  end

  # ── Precision in meters ─────────────────────────────────

  def test_precision_in_meters
    lla = LLA.new(lat: 0.0, lng: 0.0)
    coord = HAM.new(lla)
    prec = coord.precision_in_meters
    assert prec[:lat] > 0
    assert prec[:lng] > 0
  end

  def test_higher_precision_has_finer_resolution
    lla = LLA.new(lat: 0.0, lng: 0.0)
    short = HAM.new(lla, precision: 4)
    long  = HAM.new(lla, precision: 8)
    assert long.precision_in_meters[:lat] < short.precision_in_meters[:lat]
  end

  def test_field_level_is_very_coarse
    lla = LLA.new(lat: 0.0, lng: 0.0)
    coord = HAM.new(lla, precision: 2)
    prec = coord.precision_in_meters
    # 10 degrees of latitude ~ 1,113 km
    assert prec[:lat] > 1_000_000
  end

  def test_subsquare_level_precision
    lla = LLA.new(lat: 0.0, lng: 0.0)
    coord = HAM.new(lla, precision: 6)
    prec = coord.precision_in_meters
    # 2.5 minutes of latitude ~ 4.6 km
    assert prec[:lat] > 4_000
    assert prec[:lat] < 5_000
  end

  # ── to_slug ──────────────────────────────────────────────

  def test_to_slug_alias
    coord = HAM.new("FN31pr")
    assert_equal coord.to_s, coord.to_slug
  end

  # ── distance_to (via mixin) ─────────────────────────────

  def test_distance_to
    a = HAM.new(LLA.new(lat: 40.689167, lng: -74.044444))
    b = HAM.new(LLA.new(lat: 51.504444, lng: -0.086666))
    dist = a.distance_to(b)
    assert_instance_of Geodetic::Distance, dist
    # NYC to London is roughly 5,570 km
    assert_in_delta 5_570_000, dist.to_f, 60_000
  end

  # ── bearing_to (via mixin) ──────────────────────────────

  def test_bearing_to
    a = HAM.new(LLA.new(lat: 40.689167, lng: -74.044444))
    b = HAM.new(LLA.new(lat: 51.504444, lng: -0.086666))
    bearing = a.bearing_to(b)
    assert_instance_of Geodetic::Bearing, bearing
    assert_in_delta 51.0, bearing.degrees, 5.0
  end

  # ── Immutability ────────────────────────────────────────

  def test_no_setter_for_locator
    coord = HAM.new("FN31pr")
    assert_raises(NoMethodError) { coord.locator = "xxx" }
  end

  # ── from_array default precision ─────────────────────────

  def test_from_array_default_precision
    coord = HAM.from_array([40.0, -74.0])
    assert_equal 6, coord.precision
  end

  # ── Cross-system conversion roundtrips ─────────────────

  def test_to_ecef_roundtrip
    ham = HAM.new(LLA.new(lat: 40.689167, lng: -74.044444))
    ecef = ham.to_ecef
    restored = HAM.new(ecef)
    restored_lla = restored.to_lla
    assert_in_delta 40.689167, restored_lla.lat, 0.05
    assert_in_delta(-74.044444, restored_lla.lng, 0.1)
  end

  def test_to_utm_roundtrip
    ham = HAM.new(LLA.new(lat: 40.689167, lng: -74.044444))
    utm = ham.to_utm
    restored = HAM.new(utm)
    restored_lla = restored.to_lla
    assert_in_delta 40.689167, restored_lla.lat, 0.05
    assert_in_delta(-74.044444, restored_lla.lng, 0.1)
  end

  def test_to_web_mercator_roundtrip
    ham = HAM.new(LLA.new(lat: 40.689167, lng: -74.044444))
    wm = ham.to_web_mercator
    restored = HAM.new(wm)
    restored_lla = restored.to_lla
    assert_in_delta 40.689167, restored_lla.lat, 0.05
    assert_in_delta(-74.044444, restored_lla.lng, 0.1)
  end

  # ── to_enu / from_enu ────────────────────────────────────

  def test_to_enu
    ref = LLA.new(lat: 40.0, lng: -74.0)
    ham = HAM.new(LLA.new(lat: 40.689167, lng: -74.044444))
    enu = ham.to_enu(ref)
    assert_instance_of ENU, enu
  end

  def test_from_enu_roundtrip
    ref = LLA.new(lat: 40.0, lng: -74.0)
    lla = LLA.new(lat: 40.689167, lng: -74.044444)
    ham = HAM.new(lla)
    enu = ham.to_enu(ref)
    restored_lla = enu.to_lla(ref)
    restored = HAM.new(restored_lla)
    final_lla = restored.to_lla
    assert_in_delta 40.689167, final_lla.lat, 0.1
    assert_in_delta(-74.044444, final_lla.lng, 0.2)
  end

  # ── to_ned / from_ned ────────────────────────────────────

  def test_to_ned
    ref = LLA.new(lat: 40.0, lng: -74.0)
    ham = HAM.new(LLA.new(lat: 40.689167, lng: -74.044444))
    ned = ham.to_ned(ref)
    assert_instance_of NED, ned
  end

  # ── to_mgrs / from_mgrs ──────────────────────────────────

  def test_to_mgrs
    ham = HAM.new(LLA.new(lat: 40.689167, lng: -74.044444))
    mgrs = ham.to_mgrs
    assert_instance_of MGRS, mgrs
  end

  def test_from_mgrs_roundtrip
    lla = LLA.new(lat: 40.689167, lng: -74.044444)
    ham = HAM.new(lla)
    mgrs = ham.to_mgrs
    restored = HAM.from_mgrs(mgrs)
    restored_lla = restored.to_lla
    assert_in_delta 40.689167, restored_lla.lat, 0.1
    assert_in_delta(-74.044444, restored_lla.lng, 0.2)
  end

  # ── to_usng / from_usng ──────────────────────────────────

  def test_to_usng
    ham = HAM.new(LLA.new(lat: 40.689167, lng: -74.044444))
    usng = ham.to_usng
    assert_instance_of USNG, usng
  end

  # ── to_ups / from_ups ────────────────────────────────────

  def test_to_ups
    ham = HAM.new(LLA.new(lat: 85.0, lng: 10.0))
    ups = ham.to_ups
    assert_instance_of UPS_C, ups
  end

  # ── to_state_plane / from_state_plane ─────────────────────

  def test_to_state_plane
    ham = HAM.new(LLA.new(lat: 25.0, lng: -81.0))
    sp = ham.to_state_plane("FL_EAST")
    assert_instance_of SP, sp
  end

  # ── to_bng / from_bng ────────────────────────────────────

  def test_to_bng
    ham = HAM.new(LLA.new(lat: 51.5, lng: -0.1))
    bng = ham.to_bng
    assert_instance_of BNG, bng
  end

  # ── to_gh36 / from_gh36 ──────────────────────────────────

  def test_to_gh36
    ham = HAM.new(LLA.new(lat: 40.689167, lng: -74.044444))
    gh36 = ham.to_gh36
    assert_instance_of GH36, gh36
  end

  def test_from_gh36_roundtrip
    lla = LLA.new(lat: 40.689167, lng: -74.044444)
    gh36 = GH36.new(lla)
    restored = HAM.from_gh36(gh36)
    restored_lla = restored.to_lla
    assert_in_delta 40.689167, restored_lla.lat, 0.05
    assert_in_delta(-74.044444, restored_lla.lng, 0.1)
  end

  # ── to_gh / from_gh ──────────────────────────────────────

  def test_to_gh
    ham = HAM.new(LLA.new(lat: 40.689167, lng: -74.044444))
    gh = ham.to_gh
    assert_instance_of GH, gh
  end

  def test_from_gh_roundtrip
    lla = LLA.new(lat: 40.689167, lng: -74.044444)
    gh = GH.new(lla)
    restored = HAM.from_gh(gh)
    restored_lla = restored.to_lla
    assert_in_delta 40.689167, restored_lla.lat, 0.05
    assert_in_delta(-74.044444, restored_lla.lng, 0.1)
  end

  # ── Other coordinate classes' to_ham / from_ham ─────────────

  def test_ecef_to_ham
    ecef = LLA.new(lat: 40.7128, lng: -74.0060).to_ecef
    ham = ecef.to_ham
    assert_instance_of HAM, ham
  end

  def test_ecef_from_ham
    ham = HAM.new(LLA.new(lat: 40.7128, lng: -74.0060))
    ecef = ECEF.from_ham(ham)
    assert_instance_of ECEF, ecef
  end

  def test_utm_to_ham
    utm = LLA.new(lat: 40.7128, lng: -74.0060).to_utm
    ham = utm.to_ham
    assert_instance_of HAM, ham
  end

  def test_utm_from_ham
    ham = HAM.new(LLA.new(lat: 40.7128, lng: -74.0060))
    utm = UTM.from_ham(ham)
    assert_instance_of UTM, utm
  end

  def test_enu_to_ham
    ref = LLA.new(lat: 40.0, lng: -74.0)
    enu = ENU.new(e: 100.0, n: 200.0, u: 0.0)
    ham = enu.to_ham(ref)
    assert_instance_of HAM, ham
  end

  def test_enu_from_ham
    ref = LLA.new(lat: 40.0, lng: -74.0)
    ham = HAM.new(LLA.new(lat: 40.001, lng: -73.999))
    enu = ENU.from_ham(ham, ref)
    assert_instance_of ENU, enu
  end

  def test_ned_to_ham
    ref = LLA.new(lat: 40.0, lng: -74.0)
    ned = NED.new(n: 200.0, e: 100.0, d: 0.0)
    ham = ned.to_ham(ref)
    assert_instance_of HAM, ham
  end

  def test_ned_from_ham
    ref = LLA.new(lat: 40.0, lng: -74.0)
    ham = HAM.new(LLA.new(lat: 40.001, lng: -73.999))
    ned = NED.from_ham(ham, ref)
    assert_instance_of NED, ned
  end

  def test_mgrs_to_ham
    mgrs_coord = MGRS.from_lla(LLA.new(lat: 40.7128, lng: -74.0060))
    ham = mgrs_coord.to_ham
    assert_instance_of HAM, ham
  end

  def test_mgrs_from_ham
    ham = HAM.new(LLA.new(lat: 40.7128, lng: -74.0060))
    mgrs = MGRS.from_ham(ham)
    assert_instance_of MGRS, mgrs
  end

  def test_usng_to_ham
    usng = USNG.from_lla(LLA.new(lat: 40.7128, lng: -74.0060))
    ham = usng.to_ham
    assert_instance_of HAM, ham
  end

  def test_usng_from_ham
    ham = HAM.new(LLA.new(lat: 40.7128, lng: -74.0060))
    usng = USNG.from_ham(ham)
    assert_instance_of USNG, usng
  end

  def test_web_mercator_to_ham
    wm = WM.from_lla(LLA.new(lat: 40.7128, lng: -74.0060))
    ham = wm.to_ham
    assert_instance_of HAM, ham
  end

  def test_web_mercator_from_ham
    ham = HAM.new(LLA.new(lat: 40.7128, lng: -74.0060))
    wm = WM.from_ham(ham)
    assert_instance_of WM, wm
  end

  def test_ups_to_ham
    ups = UPS_C.from_lla(LLA.new(lat: 85.0, lng: 10.0))
    ham = ups.to_ham
    assert_instance_of HAM, ham
  end

  def test_ups_from_ham
    ham = HAM.new(LLA.new(lat: 85.0, lng: 10.0))
    ups = UPS_C.from_ham(ham)
    assert_instance_of UPS_C, ups
  end

  def test_state_plane_to_ham
    sp = SP.from_lla(LLA.new(lat: 25.0, lng: -81.0), "FL_EAST")
    ham = sp.to_ham
    assert_instance_of HAM, ham
  end

  def test_state_plane_from_ham
    ham = HAM.new(LLA.new(lat: 25.0, lng: -81.0))
    sp = SP.from_ham(ham, "FL_EAST")
    assert_instance_of SP, sp
  end

  def test_bng_to_ham
    bng = BNG.from_lla(LLA.new(lat: 51.5, lng: -0.1))
    ham = bng.to_ham
    assert_instance_of HAM, ham
  end

  def test_bng_from_ham
    ham = HAM.new(LLA.new(lat: 51.5, lng: -0.1))
    bng = BNG.from_ham(ham)
    assert_instance_of BNG, bng
  end

  def test_gh36_to_ham
    gh36 = GH36.new(LLA.new(lat: 40.7128, lng: -74.0060))
    ham = gh36.to_ham
    assert_instance_of HAM, ham
  end

  def test_gh36_from_ham
    ham = HAM.new(LLA.new(lat: 40.7128, lng: -74.0060))
    gh36 = GH36.from_ham(ham)
    assert_instance_of GH36, gh36
  end

  def test_gh_to_ham
    gh = GH.new(LLA.new(lat: 40.7128, lng: -74.0060))
    ham = gh.to_ham
    assert_instance_of HAM, ham
  end

  def test_gh_from_ham
    ham = HAM.new(LLA.new(lat: 40.7128, lng: -74.0060))
    gh = GH.from_ham(ham)
    assert_instance_of GH, gh
  end

  # ── HAM class methods for conversions ──────────────────────

  def test_from_lla_class_method
    lla = LLA.new(lat: 40.7128, lng: -74.0060)
    ham = HAM.from_lla(lla)
    assert_instance_of HAM, ham
  end

  def test_from_ecef_class_method
    ecef = LLA.new(lat: 40.7128, lng: -74.0060).to_ecef
    ham = HAM.from_ecef(ecef)
    assert_instance_of HAM, ham
  end

  def test_from_utm_class_method
    utm = UTM.new(easting: 583960.0, northing: 4507351.0, zone: 18, hemisphere: 'N')
    ham = HAM.from_utm(utm)
    assert_instance_of HAM, ham
  end

  def test_to_enu_direct
    ham = HAM.new(LLA.new(lat: 40.7128, lng: -74.0060))
    ref = LLA.new(lat: 40.0, lng: -74.0)
    enu = ham.to_enu(ref)
    assert_instance_of ENU, enu
  end

  def test_from_enu_class_method
    ref = LLA.new(lat: 40.0, lng: -74.0)
    enu = ENU.new(e: 100.0, n: 200.0, u: 0.0)
    ham = HAM.from_enu(enu, ref)
    assert_instance_of HAM, ham
  end

  def test_to_ned_direct
    ham = HAM.new(LLA.new(lat: 40.7128, lng: -74.0060))
    ref = LLA.new(lat: 40.0, lng: -74.0)
    ned = ham.to_ned(ref)
    assert_instance_of NED, ned
  end

  def test_from_ned_class_method
    ref = LLA.new(lat: 40.0, lng: -74.0)
    ned = NED.new(n: 200.0, e: 100.0, d: 0.0)
    ham = HAM.from_ned(ned, ref)
    assert_instance_of HAM, ham
  end

  def test_from_web_mercator_class_method
    wm = WM.from_lla(LLA.new(lat: 40.7128, lng: -74.0060))
    ham = HAM.from_web_mercator(wm)
    assert_instance_of HAM, ham
  end

  # ── Neighbor longitude wrapping ──────────────────────────

  def test_neighbors_near_antimeridian
    coord = HAM.new(LLA.new(lat: 0.0, lng: 179.99))
    neighbors = coord.neighbors
    assert_instance_of HAM, neighbors[:E]
  end

  def test_neighbors_near_north_pole
    coord = HAM.new(LLA.new(lat: 89.99, lng: 0.0))
    neighbors = coord.neighbors
    assert_instance_of HAM, neighbors[:N]
  end
end
