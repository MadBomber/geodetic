# frozen_string_literal: true

require "test_helper"
require_relative "../lib/geodetic/coordinate/web_mercator"
require_relative "../lib/geodetic/coordinate/lla"

class WebMercatorTest < Minitest::Test
  WebMercator = Geodetic::Coordinate::WebMercator
  LLA         = Geodetic::Coordinate::LLA
  ECEF        = Geodetic::Coordinate::ECEF
  UTM         = Geodetic::Coordinate::UTM
  ENU         = Geodetic::Coordinate::ENU
  NED         = Geodetic::Coordinate::NED
  MGRS        = Geodetic::Coordinate::MGRS
  USNG        = Geodetic::Coordinate::USNG
  UPS_C       = Geodetic::Coordinate::UPS
  SP          = Geodetic::Coordinate::StatePlane
  BNG         = Geodetic::Coordinate::BNG
  GH36        = Geodetic::Coordinate::GH36

  # ── Constructor ──────────────────────────────────────────────

  def test_default_values
    coord = WebMercator.new
    assert_in_delta 0.0, coord.x, 1e-6
    assert_in_delta 0.0, coord.y, 1e-6
  end

  def test_keyword_arguments
    coord = WebMercator.new(x: 1000.0, y: 2000.0)
    assert_in_delta 1000.0, coord.x, 1e-6
    assert_in_delta 2000.0, coord.y, 1e-6
  end

  # ── Accessors ──────────────────────────────────────────────

  def test_x_reader
    coord = WebMercator.new(x: 123.456)
    assert_in_delta 123.456, coord.x, 1e-6
  end

  def test_y_reader
    coord = WebMercator.new(y: 654.321)
    assert_in_delta 654.321, coord.y, 1e-6
  end

  # ── Setters ──────────────────────────────────────────────

  def test_x_setter
    coord = WebMercator.new(x: 123.456)
    coord.x = 789.0
    assert_in_delta 789.0, coord.x, 1e-6
  end

  def test_y_setter
    coord = WebMercator.new(y: 654.321)
    coord.y = 111.0
    assert_in_delta 111.0, coord.y, 1e-6
  end

  def test_setters_coerce_to_float
    coord = WebMercator.new
    coord.x = "1234.5"
    coord.y = "6789.0"
    assert_in_delta 1234.5, coord.x, 1e-6
    assert_in_delta 6789.0, coord.y, 1e-6
  end

  # ── to_s ───────────────────────────────────────────────────

  def test_to_s
    coord = WebMercator.new(x: 1000.5, y: 2000.5)
    assert_equal "1000.50, 2000.50", coord.to_s
  end

  def test_to_s_with_precision
    coord = WebMercator.new(x: 1234.5678, y: 5678.1234)
    assert_equal "1234.568, 5678.123", coord.to_s(3)
    assert_equal "1235, 5678", coord.to_s(0)
  end

  # ── to_a ───────────────────────────────────────────────────

  def test_to_a
    coord = WebMercator.new(x: 1000.0, y: 2000.0)
    result = coord.to_a
    assert_equal 2, result.size
    assert_in_delta 1000.0, result[0], 1e-6
    assert_in_delta 2000.0, result[1], 1e-6
  end

  # ── from_array ─────────────────────────────────────────────

  def test_from_array_roundtrip
    original = WebMercator.new(x: 1234.5, y: 6789.0)
    restored = WebMercator.from_array(original.to_a)
    assert_in_delta original.x, restored.x, 1e-6
    assert_in_delta original.y, restored.y, 1e-6
  end

  # ── from_string ────────────────────────────────────────────

  def test_from_string_roundtrip
    original = WebMercator.new(x: 1234.5, y: 6789.0)
    restored = WebMercator.from_string(original.to_s)
    assert_in_delta original.x, restored.x, 1e-6
    assert_in_delta original.y, restored.y, 1e-6
  end

  # ── == ─────────────────────────────────────────────────────

  def test_equality_equal_coords
    a = WebMercator.new(x: 1000.0, y: 2000.0)
    b = WebMercator.new(x: 1000.0, y: 2000.0)
    assert_equal a, b
  end

  def test_equality_unequal_coords
    a = WebMercator.new(x: 1000.0, y: 2000.0)
    b = WebMercator.new(x: 1001.0, y: 2000.0)
    refute_equal a, b
  end

  def test_equality_non_web_mercator
    coord = WebMercator.new(x: 1000.0, y: 2000.0)
    refute_equal coord, "not a WebMercator"
  end

  # ── from_lla / to_lla roundtrip ────────────────────────────

  def test_lla_roundtrip
    lla = LLA.new(lat: 47.6205, lng: -122.3493)
    wm = WebMercator.from_lla(lla)
    restored = wm.to_lla
    assert_in_delta 47.6205, restored.lat, 1e-4
    assert_in_delta(-122.3493, restored.lng, 1e-4)
  end

  # ── valid? ─────────────────────────────────────────────────

  def test_valid_within_bounds
    coord = WebMercator.new(x: 0.0, y: 0.0)
    assert coord.valid?
  end

  def test_valid_at_origin_shift_boundary
    coord = WebMercator.new(x: WebMercator::ORIGIN_SHIFT, y: WebMercator::ORIGIN_SHIFT)
    assert coord.valid?
  end

  def test_invalid_outside_bounds
    coord = WebMercator.new(x: WebMercator::ORIGIN_SHIFT + 1.0, y: 0.0)
    refute coord.valid?
  end

  # ── clamp! ─────────────────────────────────────────────────

  def test_clamp_within_bounds_unchanged
    coord = WebMercator.new(x: 1000.0, y: 2000.0)
    coord.clamp!
    assert_in_delta 1000.0, coord.x, 1e-6
    assert_in_delta 2000.0, coord.y, 1e-6
  end

  def test_clamp_exceeding_bounds
    over = WebMercator::ORIGIN_SHIFT + 5000.0
    coord = WebMercator.new(x: over, y: -over)
    coord.clamp!
    assert_in_delta WebMercator::ORIGIN_SHIFT, coord.x, 1e-6
    assert_in_delta(-WebMercator::ORIGIN_SHIFT, coord.y, 1e-6)
  end

  def test_clamp_returns_self
    coord = WebMercator.new(x: 0.0, y: 0.0)
    assert_same coord, coord.clamp!
  end

  # ── distance_to ────────────────────────────────────────────

  def test_distance_to
    a = WebMercator.new(x: 0.0, y: 0.0)
    b = WebMercator.new(x: 100000.0, y: 100000.0)
    dist = a.distance_to(b)
    assert_instance_of Geodetic::Distance, dist
    assert dist > 0.0, "Expected positive distance between different WebMercator points"
  end

  # ── to_tile_coordinates / from_tile_coordinates ────────────

  def test_tile_coordinates_roundtrip_zoom_10
    lla = LLA.new(lat: 47.6205, lng: -122.3493)
    wm = WebMercator.from_lla(lla)
    tile = wm.to_tile_coordinates(10)

    assert_equal 3, tile.size
    assert_equal 10, tile[2]
    assert_kind_of Integer, tile[0]
    assert_kind_of Integer, tile[1]

    restored = WebMercator.from_tile_coordinates(tile[0], tile[1], tile[2])
    restored_lla = restored.to_lla
    # Tile coordinates represent the NW corner of a tile, so tolerance is large
    assert_in_delta 47.6205, restored_lla.lat, 1.0
    assert_in_delta(-122.3493, restored_lla.lng, 1.0)
  end

  # ── to_pixel_coordinates / from_pixel_coordinates ──────────

  def test_pixel_coordinates_roundtrip
    lla = LLA.new(lat: 47.6205, lng: -122.3493)
    wm = WebMercator.from_lla(lla)
    pixel = wm.to_pixel_coordinates(10)

    assert_equal 3, pixel.size
    assert_equal 10, pixel[2]
    assert_kind_of Integer, pixel[0]
    assert_kind_of Integer, pixel[1]

    restored = WebMercator.from_pixel_coordinates(pixel[0], pixel[1], pixel[2])
    restored_lla = restored.to_lla
    assert_in_delta 47.6205, restored_lla.lat, 0.01
    assert_in_delta(-122.3493, restored_lla.lng, 0.01)
  end

  # ── to_ecef / from_ecef ──────────────────────────────────

  def test_to_ecef
    wm = WebMercator.from_lla(LLA.new(lat: 47.6205, lng: -122.3493))
    ecef = wm.to_ecef
    assert_instance_of ECEF, ecef
  end

  def test_from_ecef_roundtrip
    lla = LLA.new(lat: 47.6205, lng: -122.3493)
    wm = WebMercator.from_lla(lla)
    ecef = wm.to_ecef
    restored = WebMercator.from_ecef(ecef)
    restored_lla = restored.to_lla
    assert_in_delta 47.6205, restored_lla.lat, 1e-4
    assert_in_delta(-122.3493, restored_lla.lng, 1e-4)
  end

  # ── to_utm / from_utm ────────────────────────────────────

  def test_to_utm
    wm = WebMercator.from_lla(LLA.new(lat: 47.6205, lng: -122.3493))
    utm = wm.to_utm
    assert_instance_of UTM, utm
  end

  def test_from_utm_roundtrip
    lla = LLA.new(lat: 47.6205, lng: -122.3493)
    wm = WebMercator.from_lla(lla)
    utm = wm.to_utm
    restored = WebMercator.from_utm(utm)
    restored_lla = restored.to_lla
    assert_in_delta 47.6205, restored_lla.lat, 1e-4
    assert_in_delta(-122.3493, restored_lla.lng, 1e-4)
  end

  # ── to_enu / from_enu ────────────────────────────────────

  def test_to_enu
    ref = LLA.new(lat: 47.0, lng: -122.0)
    wm = WebMercator.from_lla(LLA.new(lat: 47.6205, lng: -122.3493))
    enu = wm.to_lla.to_enu(ref)
    assert_instance_of ENU, enu
  end

  def test_from_enu_roundtrip
    ref = LLA.new(lat: 47.0, lng: -122.0)
    lla = LLA.new(lat: 47.6205, lng: -122.3493)
    wm = WebMercator.from_lla(lla)
    enu = wm.to_lla.to_enu(ref)
    restored_lla = enu.to_lla(ref)
    restored = WebMercator.from_lla(restored_lla)
    final_lla = restored.to_lla
    assert_in_delta 47.6205, final_lla.lat, 1e-4
    assert_in_delta(-122.3493, final_lla.lng, 1e-4)
  end

  # ── to_ned / from_ned ────────────────────────────────────

  def test_to_ned
    ref = LLA.new(lat: 47.0, lng: -122.0)
    wm = WebMercator.from_lla(LLA.new(lat: 47.6205, lng: -122.3493))
    ned = wm.to_lla.to_ned(ref)
    assert_instance_of NED, ned
  end

  def test_from_ned_roundtrip
    ref = LLA.new(lat: 47.0, lng: -122.0)
    lla = LLA.new(lat: 47.6205, lng: -122.3493)
    wm = WebMercator.from_lla(lla)
    ned = wm.to_lla.to_ned(ref)
    restored_lla = ned.to_lla(ref)
    restored = WebMercator.from_lla(restored_lla)
    final_lla = restored.to_lla
    assert_in_delta 47.6205, final_lla.lat, 1e-4
    assert_in_delta(-122.3493, final_lla.lng, 1e-4)
  end

  # ── to_mgrs / from_mgrs ──────────────────────────────────

  def test_to_mgrs
    wm = WebMercator.from_lla(LLA.new(lat: 47.6205, lng: -122.3493))
    mgrs = wm.to_mgrs
    assert_instance_of MGRS, mgrs
  end

  def test_from_mgrs_roundtrip
    lla = LLA.new(lat: 47.6205, lng: -122.3493)
    wm = WebMercator.from_lla(lla)
    mgrs = wm.to_mgrs
    restored = WebMercator.from_mgrs(mgrs)
    restored_lla = restored.to_lla
    assert_in_delta 47.6205, restored_lla.lat, 0.01
    assert_in_delta(-122.3493, restored_lla.lng, 0.01)
  end

  # ── to_usng / from_usng ──────────────────────────────────

  def test_to_usng
    wm = WebMercator.from_lla(LLA.new(lat: 47.6205, lng: -122.3493))
    usng = wm.to_usng
    assert_instance_of USNG, usng
  end

  def test_from_usng_roundtrip
    lla = LLA.new(lat: 47.6205, lng: -122.3493)
    wm = WebMercator.from_lla(lla)
    usng = wm.to_usng
    restored = WebMercator.from_usng(usng)
    restored_lla = restored.to_lla
    assert_in_delta 47.6205, restored_lla.lat, 0.01
    assert_in_delta(-122.3493, restored_lla.lng, 0.01)
  end

  # ── to_ups / from_ups ────────────────────────────────────

  def test_to_ups
    # Use a high-latitude point suitable for UPS
    wm = WebMercator.from_lla(LLA.new(lat: 85.0, lng: 10.0))
    ups = wm.to_ups
    assert_instance_of UPS_C, ups
  end

  def test_from_ups_roundtrip
    lla = LLA.new(lat: 85.0, lng: 10.0)
    wm = WebMercator.from_lla(lla)
    ups = wm.to_ups
    restored = WebMercator.from_ups(ups)
    restored_lla = restored.to_lla
    assert_in_delta 85.0, restored_lla.lat, 0.1
    assert_in_delta 10.0, restored_lla.lng, 0.1
  end

  # ── to_state_plane / from_state_plane ─────────────────────

  def test_to_state_plane
    wm = WebMercator.from_lla(LLA.new(lat: 40.0, lng: -122.0))
    sp = wm.to_state_plane("CA_I")
    assert_instance_of SP, sp
  end

  def test_from_state_plane_roundtrip
    lla = LLA.new(lat: 40.0, lng: -122.0)
    wm = WebMercator.from_lla(lla)
    sp = wm.to_state_plane("CA_I")
    restored = WebMercator.from_state_plane(sp)
    assert_instance_of WebMercator, restored
  end

  # ── to_bng / from_bng ────────────────────────────────────

  def test_to_bng
    wm = WebMercator.from_lla(LLA.new(lat: 51.5, lng: -0.1))
    bng = wm.to_bng
    assert_instance_of BNG, bng
  end

  def test_from_bng_roundtrip
    lla = LLA.new(lat: 51.5, lng: -0.1)
    wm = WebMercator.from_lla(lla)
    bng = wm.to_bng
    restored = WebMercator.from_bng(bng)
    restored_lla = restored.to_lla
    assert_in_delta 51.5, restored_lla.lat, 0.2
    assert_in_delta(-0.1, restored_lla.lng, 0.2)
  end

  # ── to_gh36 / from_gh36 ──────────────────────────────────

  def test_to_gh36
    wm = WebMercator.from_lla(LLA.new(lat: 47.6205, lng: -122.3493))
    gh36 = wm.to_gh36
    assert_instance_of GH36, gh36
  end

  def test_from_gh36_roundtrip
    lla = LLA.new(lat: 47.6205, lng: -122.3493)
    wm = WebMercator.from_lla(lla)
    gh36 = wm.to_gh36
    restored = WebMercator.from_gh36(gh36)
    restored_lla = restored.to_lla
    assert_in_delta 47.6205, restored_lla.lat, 0.001
    assert_in_delta(-122.3493, restored_lla.lng, 0.001)
  end

  # ── tile_bounds class method ──────────────────────────────

  def test_tile_bounds_returns_expected_keys
    bounds = WebMercator.tile_bounds(0, 0, 1)
    assert_instance_of Hash, bounds
    assert bounds.key?(:north_west)
    assert bounds.key?(:south_east)
    assert bounds.key?(:north)
    assert bounds.key?(:south)
    assert bounds.key?(:west)
    assert bounds.key?(:east)
    assert_instance_of WebMercator, bounds[:north_west]
    assert_instance_of WebMercator, bounds[:south_east]
  end

  # ── to_lla at origin ──────────────────────────────────────

  def test_to_lla_at_origin
    wm = WebMercator.new(x: 0.0, y: 0.0)
    lla = wm.to_lla
    assert_in_delta 0.0, lla.lat, 1e-6
    assert_in_delta 0.0, lla.lng, 1e-6
  end

  # ── equality with non-WebMercator ─────────────────────────

  def test_equality_with_lla_returns_false
    wm = WebMercator.new(x: 1000.0, y: 2000.0)
    lla = LLA.new(lat: 0.0, lng: 0.0)
    refute_equal wm, lla
  end

  # ── Direct to_enu/from_enu and to_ned/from_ned ──────────────

  def test_to_enu_direct
    wm = WebMercator.from_lla(LLA.new(lat: 47.6205, lng: -122.3493))
    ref = LLA.new(lat: 47.0, lng: -122.0)
    enu = wm.to_enu(ref)
    assert_instance_of ENU, enu
  end

  def test_from_enu_direct
    ref = LLA.new(lat: 47.0, lng: -122.0)
    enu = ENU.new(e: 100.0, n: 200.0, u: 0.0)
    wm = WebMercator.from_enu(enu, ref)
    assert_instance_of WebMercator, wm
  end

  def test_to_ned_direct
    wm = WebMercator.from_lla(LLA.new(lat: 47.6205, lng: -122.3493))
    ref = LLA.new(lat: 47.0, lng: -122.0)
    ned = wm.to_ned(ref)
    assert_instance_of NED, ned
  end

  def test_from_ned_direct
    ref = LLA.new(lat: 47.0, lng: -122.0)
    ned = NED.new(n: 200.0, e: 100.0, d: 0.0)
    wm = WebMercator.from_ned(ned, ref)
    assert_instance_of WebMercator, wm
  end
end
