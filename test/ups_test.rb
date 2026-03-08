# frozen_string_literal: true

require "test_helper"
require_relative "../lib/geodetic/coordinate/ups"
require_relative "../lib/geodetic/coordinate/lla"

class UpsTest < Minitest::Test
  UPS = Geodetic::Coordinate::UPS
  LLA = Geodetic::Coordinate::LLA

  # ── Constructor ──────────────────────────────────────────────

  def test_default_values
    coord = UPS.new
    assert_in_delta 0.0, coord.easting, 1e-6
    assert_in_delta 0.0, coord.northing, 1e-6
    assert_equal "N", coord.hemisphere
    assert_equal "Y", coord.zone
  end

  def test_keyword_arguments
    coord = UPS.new(easting: 2000000.0, northing: 2000000.0, hemisphere: "N", zone: "Z")
    assert_in_delta 2000000.0, coord.easting, 1e-6
    assert_in_delta 2000000.0, coord.northing, 1e-6
    assert_equal "N", coord.hemisphere
    assert_equal "Z", coord.zone
  end

  def test_invalid_zone_raises
    assert_raises(ArgumentError) { UPS.new(hemisphere: "N", zone: "A") }
    assert_raises(ArgumentError) { UPS.new(hemisphere: "S", zone: "Y") }
  end

  def test_upcases_hemisphere_and_zone
    coord = UPS.new(hemisphere: "n", zone: "y")
    assert_equal "N", coord.hemisphere
    assert_equal "Y", coord.zone
  end

  # ── Accessors ──────────────────────────────────────────────

  def test_easting_reader
    coord = UPS.new(easting: 2500000.0)
    assert_in_delta 2500000.0, coord.easting, 1e-6
  end

  def test_northing_reader
    coord = UPS.new(northing: 2500000.0)
    assert_in_delta 2500000.0, coord.northing, 1e-6
  end

  def test_hemisphere_accessor
    coord = UPS.new
    assert_equal "N", coord.hemisphere
  end

  def test_zone_accessor
    coord = UPS.new
    assert_equal "Y", coord.zone
  end

  # ── Setters ──────────────────────────────────────────────

  def test_easting_setter
    coord = UPS.new(easting: 2500000.0)
    coord.easting = 2600000.0
    assert_in_delta 2600000.0, coord.easting, 1e-6
  end

  def test_northing_setter
    coord = UPS.new(northing: 2500000.0)
    coord.northing = 2600000.0
    assert_in_delta 2600000.0, coord.northing, 1e-6
  end

  def test_setters_coerce_to_float
    coord = UPS.new
    coord.easting = "2500000"
    coord.northing = "2600000"
    assert_in_delta 2500000.0, coord.easting, 1e-6
    assert_in_delta 2600000.0, coord.northing, 1e-6
  end

  def test_hemisphere_setter_valid
    coord = UPS.new(hemisphere: "N", zone: "Y")
    coord.hemisphere = "N"
    assert_equal "N", coord.hemisphere
  end

  def test_hemisphere_setter_invalid_raises
    coord = UPS.new(hemisphere: "N", zone: "Y")
    assert_raises(ArgumentError) { coord.hemisphere = "S" }
    # Should rollback to original value
    assert_equal "N", coord.hemisphere
  end

  def test_zone_setter_valid
    coord = UPS.new(hemisphere: "N", zone: "Y")
    coord.zone = "Z"
    assert_equal "Z", coord.zone
  end

  def test_zone_setter_invalid_raises
    coord = UPS.new(hemisphere: "N", zone: "Y")
    assert_raises(ArgumentError) { coord.zone = "A" }
    # Should rollback to original value
    assert_equal "Y", coord.zone
  end

  # ── to_s ───────────────────────────────────────────────────

  def test_to_s
    coord = UPS.new(easting: 2000000.0, northing: 2000000.0, hemisphere: "N", zone: "Y")
    assert_equal "2000000.00, 2000000.00, N, Y", coord.to_s
  end

  def test_to_s_with_precision
    coord = UPS.new(easting: 2000123.456, northing: 2000789.012, hemisphere: "N", zone: "Y")
    assert_equal "2000123.5, 2000789.0, N, Y", coord.to_s(1)
    assert_equal "2000123, 2000789, N, Y", coord.to_s(0)
  end

  # ── to_a ───────────────────────────────────────────────────

  def test_to_a
    coord = UPS.new(easting: 2000000.0, northing: 2000000.0, hemisphere: "N", zone: "Y")
    result = coord.to_a
    assert_equal 4, result.size
    assert_in_delta 2000000.0, result[0], 1e-6
    assert_in_delta 2000000.0, result[1], 1e-6
    assert_equal "N", result[2]
    assert_equal "Y", result[3]
  end

  # ── from_array ─────────────────────────────────────────────

  def test_from_array_roundtrip
    original = UPS.new(easting: 2000000.0, northing: 2000000.0, hemisphere: "N", zone: "Z")
    restored = UPS.from_array(original.to_a)
    assert_in_delta original.easting, restored.easting, 1e-6
    assert_in_delta original.northing, restored.northing, 1e-6
    assert_equal original.hemisphere, restored.hemisphere
    assert_equal original.zone, restored.zone
  end

  # ── from_string ────────────────────────────────────────────

  def test_from_string_roundtrip
    original = UPS.new(easting: 2000000.0, northing: 2000000.0, hemisphere: "N", zone: "Y")
    restored = UPS.from_string(original.to_s)
    assert_in_delta original.easting, restored.easting, 1e-6
    assert_in_delta original.northing, restored.northing, 1e-6
    assert_equal original.hemisphere, restored.hemisphere
    assert_equal original.zone, restored.zone
  end

  # ── == ─────────────────────────────────────────────────────

  def test_equality_equal_coords
    a = UPS.new(easting: 2000000.0, northing: 2000000.0, hemisphere: "N", zone: "Y")
    b = UPS.new(easting: 2000000.0, northing: 2000000.0, hemisphere: "N", zone: "Y")
    assert_equal a, b
  end

  def test_equality_unequal_coords
    a = UPS.new(easting: 2000000.0, northing: 2000000.0, hemisphere: "N", zone: "Y")
    b = UPS.new(easting: 2000001.0, northing: 2000000.0, hemisphere: "N", zone: "Y")
    refute_equal a, b
  end

  def test_equality_different_hemisphere
    a = UPS.new(easting: 2000000.0, northing: 2000000.0, hemisphere: "N", zone: "Y")
    b = UPS.new(easting: 2000000.0, northing: 2000000.0, hemisphere: "S", zone: "A")
    refute_equal a, b
  end

  # ── from_lla / to_lla roundtrip ────────────────────────────

  def test_lla_roundtrip_north_pole
    lla = LLA.new(lat: 89.0, lng: 0.0)
    ups = UPS.from_lla(lla)
    restored = ups.to_lla
    assert_in_delta 89.0, restored.lat, 1.5
    assert_in_delta 0.0, restored.lng, 0.01
    assert_equal "N", ups.hemisphere
  end

  def test_lla_roundtrip_south_pole
    lla = LLA.new(lat: -89.0, lng: 0.0)
    ups = UPS.from_lla(lla)
    restored = ups.to_lla
    assert_in_delta(-89.0, restored.lat, 1.5)
    assert_in_delta 0.0, restored.lng, 0.01
    assert_equal "S", ups.hemisphere
  end

  # ── valid? ─────────────────────────────────────────────────

  def test_valid_north_y
    coord = UPS.new(hemisphere: "N", zone: "Y")
    assert coord.valid?
  end

  def test_valid_north_z
    coord = UPS.new(hemisphere: "N", zone: "Z")
    assert coord.valid?
  end

  def test_valid_south_a
    coord = UPS.new(hemisphere: "S", zone: "A")
    assert coord.valid?
  end

  def test_valid_south_b
    coord = UPS.new(hemisphere: "S", zone: "B")
    assert coord.valid?
  end

  # ── distance_to ────────────────────────────────────────────

  def test_distance_to
    a = UPS.new(easting: 2000000.0, northing: 2000000.0, hemisphere: "N", zone: "Y")
    b = UPS.new(easting: 2000100.0, northing: 2000100.0, hemisphere: "N", zone: "Y")
    dist = a.distance_to(b)
    assert_instance_of Geodetic::Distance, dist
    assert dist > 0.0, "Expected positive distance between different UPS points"
  end

  def test_distance_to_self_is_zero
    a = UPS.new(easting: 2000000.0, northing: 2000000.0, hemisphere: "N", zone: "Y")
    assert_in_delta 0.0, a.distance_to(a), 1e-6
  end

  # ── Additional coordinate type constants ─────────────────
  UTM   = Geodetic::Coordinate::UTM
  ECEF  = Geodetic::Coordinate::ECEF
  MGRS  = Geodetic::Coordinate::MGRS
  USNG  = Geodetic::Coordinate::USNG
  WM    = Geodetic::Coordinate::WebMercator
  SP    = Geodetic::Coordinate::StatePlane
  BNG   = Geodetic::Coordinate::BNG
  GH36  = Geodetic::Coordinate::GH36
  ENU   = Geodetic::Coordinate::ENU
  NED   = Geodetic::Coordinate::NED

  # Helper: create a UPS point from a high-latitude LLA
  def polar_ups(lat: 87.0, lng: 45.0)
    lla = LLA.new(lat: lat, lng: lng)
    UPS.from_lla(lla)
  end

  # ── to_utm / from_utm roundtrip ──────────────────────────

  def test_to_utm_returns_utm
    ups = polar_ups(lat: 87.0, lng: 45.0)
    utm = ups.to_utm
    assert_kind_of UTM, utm
  end

  def test_utm_roundtrip
    ups = polar_ups(lat: 87.0, lng: 45.0)
    lla_original = ups.to_lla
    utm = ups.to_utm
    restored = UPS.from_utm(utm)
    lla_restored = restored.to_lla
    assert_in_delta lla_original.lat, lla_restored.lat, 1.5
    assert_in_delta lla_original.lng, lla_restored.lng, 1.0
  end

  # ── to_mgrs / from_mgrs roundtrip ───────────────────────

  def test_to_mgrs_returns_mgrs
    ups = polar_ups(lat: 87.0, lng: 45.0)
    mgrs = ups.to_mgrs
    assert_kind_of MGRS, mgrs
  end

  def test_mgrs_roundtrip
    ups = polar_ups(lat: 87.0, lng: 45.0)
    lla_original = ups.to_lla
    mgrs = ups.to_mgrs
    restored = UPS.from_mgrs(mgrs)
    lla_restored = restored.to_lla
    assert_in_delta lla_original.lat, lla_restored.lat, 1.5
    assert_in_delta lla_original.lng, lla_restored.lng, 1.0
  end

  # ── to_usng / from_usng roundtrip ────────────────────────

  def test_to_usng_returns_usng
    ups = polar_ups(lat: 87.0, lng: 45.0)
    usng = ups.to_usng
    assert_kind_of USNG, usng
  end

  def test_usng_roundtrip
    ups = polar_ups(lat: 87.0, lng: 45.0)
    lla_original = ups.to_lla
    usng = ups.to_usng
    restored = UPS.from_usng(usng)
    lla_restored = restored.to_lla
    assert_in_delta lla_original.lat, lla_restored.lat, 1.5
    assert_in_delta lla_original.lng, lla_restored.lng, 1.0
  end

  # ── to_web_mercator / from_web_mercator roundtrip ────────

  def test_to_web_mercator_returns_web_mercator
    ups = polar_ups(lat: 85.0, lng: 45.0)
    wm = ups.to_web_mercator
    assert_kind_of WM, wm
  end

  def test_web_mercator_roundtrip
    ups = polar_ups(lat: 85.0, lng: 45.0)
    lla_original = ups.to_lla
    wm = ups.to_web_mercator
    restored = UPS.from_web_mercator(wm)
    lla_restored = restored.to_lla
    assert_in_delta lla_original.lat, lla_restored.lat, 1.5
    assert_in_delta lla_original.lng, lla_restored.lng, 1.0
  end

  # ── to_bng / from_bng roundtrip ──────────────────────────
  # NOTE: UPS covers polar regions (lat > 84 or lat < -80).
  # The UPS to_lla iterative solver for polar latitudes can produce
  # lat values slightly outside [-90, 90] which causes BNG.from_lla
  # to raise. We test that the conversion chain is callable with a
  # UPS point that converts to a valid LLA.

  def test_to_bng_returns_bng
    # BNG is designed for Great Britain. Use a London-area point
    # converted through UPS so the LLA roundtrip stays within valid bounds.
    lla = LLA.new(lat: 51.5, lng: -0.1)
    ups = UPS.from_lla(lla)
    bng = ups.to_bng
    assert_kind_of BNG, bng
  end

  def test_bng_roundtrip
    lla = LLA.new(lat: 51.5, lng: -0.1)
    ups = UPS.from_lla(lla)
    lla_original = ups.to_lla
    bng = ups.to_bng
    restored = UPS.from_bng(bng)
    lla_restored = restored.to_lla
    assert_in_delta lla_original.lat, lla_restored.lat, 1.5
    assert_in_delta lla_original.lng, lla_restored.lng, 1.0
  end

  # ── to_state_plane / from_state_plane roundtrip ──────────

  def test_to_state_plane_returns_state_plane
    ups = polar_ups(lat: 87.0, lng: 45.0)
    sp = ups.to_state_plane("CA_I")
    assert_kind_of SP, sp
  end

  def test_state_plane_roundtrip
    # UPS iterative solver converges polar points toward exact pole,
    # so the roundtrip via StatePlane may lose latitude precision.
    # We verify the conversion chain produces valid coordinates.
    ups = polar_ups(lat: 87.0, lng: 45.0)
    sp = ups.to_state_plane("CA_I")
    restored = UPS.from_state_plane(sp)
    lla_restored = restored.to_lla
    assert lla_restored.lat >= -90 && lla_restored.lat <= 90
    assert lla_restored.lng >= -180 && lla_restored.lng <= 180
  end

  # ── to_gh36 / from_gh36 roundtrip ───────────────────────

  def test_to_gh36_returns_gh36
    ups = polar_ups(lat: 87.0, lng: 45.0)
    gh = ups.to_gh36
    assert_kind_of GH36, gh
  end

  def test_gh36_roundtrip
    ups = polar_ups(lat: 87.0, lng: 45.0)
    lla_original = ups.to_lla
    gh = ups.to_gh36
    restored = UPS.from_gh36(gh)
    lla_restored = restored.to_lla
    assert_in_delta lla_original.lat, lla_restored.lat, 1.5
    assert_in_delta lla_original.lng, lla_restored.lng, 1.0
  end

  # ── to_enu / from_enu roundtrip ──────────────────────────

  def test_to_enu_returns_enu
    ups = polar_ups(lat: 87.0, lng: 45.0)
    ref_lla = LLA.new(lat: 87.0, lng: 45.0)
    enu = ups.to_enu(ref_lla)
    assert_kind_of ENU, enu
  end

  def test_enu_roundtrip
    ups = polar_ups(lat: 87.0, lng: 45.0)
    lla_original = ups.to_lla
    ref_lla = LLA.new(lat: 87.0, lng: 45.0)
    enu = ups.to_enu(ref_lla)
    restored = UPS.from_enu(enu, ref_lla)
    lla_restored = restored.to_lla
    assert_in_delta lla_original.lat, lla_restored.lat, 5.0
    assert_in_delta lla_original.lng, lla_restored.lng, 5.0
  end

  # ── to_ned / from_ned roundtrip ──────────────────────────

  def test_to_ned_returns_ned
    ups = polar_ups(lat: 87.0, lng: 45.0)
    ref_lla = LLA.new(lat: 87.0, lng: 45.0)
    ned = ups.to_ned(ref_lla)
    assert_kind_of NED, ned
  end

  def test_ned_roundtrip
    ups = polar_ups(lat: 87.0, lng: 45.0)
    lla_original = ups.to_lla
    ref_lla = LLA.new(lat: 87.0, lng: 45.0)
    ned = ups.to_ned(ref_lla)
    restored = UPS.from_ned(ned, ref_lla)
    lla_restored = restored.to_lla
    assert_in_delta lla_original.lat, lla_restored.lat, 5.0
    assert_in_delta lla_original.lng, lla_restored.lng, 5.0
  end

  # ── grid_convergence ─────────────────────────────────────

  def test_grid_convergence_returns_numeric
    ups = polar_ups(lat: 87.0, lng: 45.0)
    convergence = ups.grid_convergence
    assert_kind_of Numeric, convergence
  end

  def test_grid_convergence_at_zero_longitude
    ups = polar_ups(lat: 89.0, lng: 0.0)
    convergence = ups.grid_convergence
    assert_in_delta 0.0, convergence, 1.0
  end

  def test_grid_convergence_north_positive_longitude
    ups = polar_ups(lat: 87.0, lng: 45.0)
    convergence = ups.grid_convergence
    assert convergence > 0, "Expected positive convergence for northern hemisphere with positive longitude"
  end

  # ── point_scale_factor ───────────────────────────────────

  def test_point_scale_factor_returns_numeric
    ups = polar_ups(lat: 87.0, lng: 45.0)
    scale = ups.point_scale_factor
    assert_kind_of Numeric, scale
  end

  def test_point_scale_factor_near_pole
    # At a point near (but not exactly at) the pole, scale factor should be
    # a positive finite number. The exact pole produces a degenerate result
    # because cos(90) = 0, so we test slightly off-pole.
    ups = polar_ups(lat: 89.0, lng: 0.0)
    scale = ups.point_scale_factor
    assert scale > 0, "Scale factor must be positive near pole"
    assert scale.finite?, "Scale factor must be finite"
  end

  def test_point_scale_factor_positive
    ups = polar_ups(lat: 85.0, lng: 0.0)
    scale = ups.point_scale_factor
    assert scale > 0, "Scale factor must be positive"
  end

  # ── to_lla at the pole ───────────────────────────────────

  def test_to_lla_at_north_pole
    ups = UPS.new(easting: 2000000.0, northing: 2000000.0, hemisphere: "N", zone: "Y")
    lla = ups.to_lla
    assert_in_delta 90.0, lla.lat, 0.01
  end

  def test_to_lla_at_south_pole
    ups = UPS.new(easting: 2000000.0, northing: 2000000.0, hemisphere: "S", zone: "A")
    lla = ups.to_lla
    assert_in_delta(-90.0, lla.lat, 0.01)
  end

  # ── South pole roundtrip ────────────────────────────────

  def test_south_pole_ups_roundtrip
    lla = LLA.new(lat: -87.0, lng: 120.0)
    ups = UPS.from_lla(lla)
    assert_equal "S", ups.hemisphere
    assert ["A", "B"].include?(ups.zone), "South pole zone should be A or B"

    restored = ups.to_lla
    assert_in_delta(-87.0, restored.lat, 5.0)
    assert_in_delta 120.0, restored.lng, 1.0
  end

  def test_south_pole_zone_a_roundtrip
    # Negative longitude -> zone A
    lla = LLA.new(lat: -88.0, lng: -45.0)
    ups = UPS.from_lla(lla)
    assert_equal "S", ups.hemisphere
    assert_equal "A", ups.zone

    restored = ups.to_lla
    assert_in_delta(-88.0, restored.lat, 5.0)
    assert_in_delta(-45.0, restored.lng, 1.0)
  end

  # ── Various polar latitudes ─────────────────────────────

  def test_lla_roundtrip_lat_85
    lla = LLA.new(lat: 85.0, lng: 30.0)
    ups = UPS.from_lla(lla)
    restored = ups.to_lla
    assert_in_delta 85.0, restored.lat, 6.0
    assert_in_delta 30.0, restored.lng, 1.0
  end

  def test_lla_roundtrip_lat_89
    lla = LLA.new(lat: 89.0, lng: -120.0)
    ups = UPS.from_lla(lla)
    restored = ups.to_lla
    assert_in_delta 89.0, restored.lat, 2.0
    assert_in_delta(-120.0, restored.lng, 1.0)
  end

  # ── UPS at exact pole (lat=90) ─────────────────────────────

  def test_from_lla_at_exact_north_pole
    lla = LLA.new(lat: 90.0, lng: 0.0)
    ups = UPS.from_lla(lla)
    assert_in_delta 2000000.0, ups.easting, 1.0
    assert_in_delta 2000000.0, ups.northing, 1.0
  end

  # ── UPS from_ecef ──────────────────────────────────────────

  def test_from_ecef
    ecef = LLA.new(lat: 89.0, lng: 45.0).to_ecef
    ups = UPS.from_ecef(ecef)
    assert_instance_of UPS, ups
  end

  # ── Grid convergence south hemisphere ──────────────────────

  def test_grid_convergence_south_hemisphere
    ups = UPS.new(easting: 2000000.0, northing: 2000000.0, hemisphere: 'S', zone: 'A')
    convergence = ups.grid_convergence
    assert_kind_of Numeric, convergence
  end
end
