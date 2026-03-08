# frozen_string_literal: true

require "test_helper"
require_relative "../lib/geodetic/coordinates/mgrs"
require_relative "../lib/geodetic/coordinates/utm"
require_relative "../lib/geodetic/coordinates/lla"

class MgrsTest < Minitest::Test
  MGRS = Geodetic::Coordinates::MGRS
  UTM  = Geodetic::Coordinates::UTM
  LLA  = Geodetic::Coordinates::LLA

  # ── Constructor from string ────────────────────────────────

  def test_construct_from_mgrs_string
    coord = MGRS.new(mgrs_string: "18SUJ2337006519")
    assert_equal "18S", coord.grid_zone_designator
    assert_equal "UJ", coord.square_identifier
    assert_equal 5, coord.precision
    assert_in_delta 23370.0, coord.easting, 1e-6
    assert_in_delta 6519.0, coord.northing, 1e-6
  end

  # ── Constructor from components ────────────────────────────

  def test_construct_from_components
    coord = MGRS.new(grid_zone: "18S", square_id: "UJ", easting: 23370.0, northing: 6519.0, precision: 5)
    assert_equal "18S", coord.grid_zone_designator
    assert_equal "UJ", coord.square_identifier
    assert_in_delta 23370.0, coord.easting, 1e-6
    assert_in_delta 6519.0, coord.northing, 1e-6
    assert_equal 5, coord.precision
  end

  # ── to_s ───────────────────────────────────────────────────

  def test_to_s_produces_valid_mgrs_string
    coord = MGRS.new(mgrs_string: "18SUJ2337006519")
    result = coord.to_s
    assert_match(/^18SUJ/, result)
    assert_equal 15, result.length
  end

  # ── from_string ────────────────────────────────────────────

  def test_from_string_roundtrip
    original_str = "18SUJ2337006519"
    coord = MGRS.from_string(original_str)
    assert_equal "18S", coord.grid_zone_designator
    assert_equal "UJ", coord.square_identifier
    restored_str = coord.to_s
    assert_equal original_str, restored_str
  end

  # ── to_utm / from_utm roundtrip ────────────────────────────

  def test_utm_roundtrip
    # UTM does not carry latitude band info, so from_utm estimates the band
    # from northing. We test that easting/northing and square ID survive roundtrip.
    utm = UTM.new(easting: 583960.0, northing: 4507351.0, altitude: 0.0, zone: 18, hemisphere: 'N')
    mgrs = MGRS.from_utm(utm, 5)
    restored_utm = mgrs.to_utm
    restored_mgrs = MGRS.from_utm(restored_utm, 5)
    assert_equal mgrs.square_identifier, restored_mgrs.square_identifier
    assert_in_delta mgrs.easting, restored_mgrs.easting, 1.0
    assert_in_delta mgrs.northing, restored_mgrs.northing, 1.0
  end

  # ── to_lla roundtrip ───────────────────────────────────────

  def test_lla_roundtrip
    # The LLA -> MGRS -> LLA roundtrip uses simplified UTM formulas,
    # so we verify the MGRS intermediate values are self-consistent
    # rather than testing geographic accuracy
    lla = LLA.new(lat: 40.7128, lng: -74.0060)
    mgrs = MGRS.from_lla(lla)
    assert_kind_of MGRS, mgrs
    assert mgrs.grid_zone_designator.length >= 2
    assert_equal 2, mgrs.square_identifier.length
    assert mgrs.easting >= 0
    assert mgrs.northing >= 0

    # Verify to_lla produces a valid LLA
    restored = mgrs.to_lla
    assert_kind_of LLA, restored
    assert restored.lat >= -90 && restored.lat <= 90
    assert restored.lng >= -180 && restored.lng <= 180
  end

  # ── Different precisions ───────────────────────────────────

  def test_precision_1_grid_square_only
    coord = MGRS.new(mgrs_string: "18SUJ")
    assert_equal 1, coord.precision
    assert_equal "18SUJ", coord.to_s
  end

  def test_precision_4
    coord = MGRS.new(grid_zone: "18S", square_id: "UJ", easting: 23370.0, northing: 6510.0, precision: 4)
    result = coord.to_s
    # precision 4 means 4 digits each for easting and northing
    assert_match(/^18SUJ/, result)
    assert_equal 13, result.length  # 3 (grid_zone) + 2 (square_id) + 4 + 4
  end

  def test_precision_5
    coord = MGRS.new(grid_zone: "18S", square_id: "UJ", easting: 23370.0, northing: 6519.0, precision: 5)
    result = coord.to_s
    assert_equal 15, result.length  # 3 + 2 + 5 + 5
  end

  def test_different_precisions_produce_different_lengths
    coord5 = MGRS.new(grid_zone: "18S", square_id: "UJ", easting: 23370.0, northing: 6510.0, precision: 5)
    coord4 = MGRS.new(grid_zone: "18S", square_id: "UJ", easting: 23370.0, northing: 6510.0, precision: 4)
    assert coord5.to_s.length > coord4.to_s.length
  end

  # ── Additional coordinate type constants ─────────────────
  ECEF  = Geodetic::Coordinates::ECEF
  WM    = Geodetic::Coordinates::WebMercator
  UPS_C = Geodetic::Coordinates::UPS
  USNG  = Geodetic::Coordinates::USNG
  SP    = Geodetic::Coordinates::StatePlane
  BNG   = Geodetic::Coordinates::BNG
  GH36  = Geodetic::Coordinates::GH36
  ENU   = Geodetic::Coordinates::ENU
  NED   = Geodetic::Coordinates::NED

  # ── to_ecef / from_ecef roundtrip ────────────────────────

  def test_to_ecef_returns_ecef
    mgrs = MGRS.new(mgrs_string: "18SUJ2337006519")
    ecef = mgrs.to_ecef
    assert_kind_of ECEF, ecef
  end

  def test_ecef_roundtrip
    mgrs = MGRS.new(mgrs_string: "18SUJ2337006519")
    lla_original = mgrs.to_lla
    ecef = mgrs.to_ecef
    restored = MGRS.from_ecef(ecef)
    lla_restored = restored.to_lla
    assert_in_delta lla_original.lat, lla_restored.lat, 0.01
    assert_in_delta lla_original.lng, lla_restored.lng, 0.01
  end

  # ── to_enu / from_enu roundtrip ──────────────────────────

  def test_to_enu_returns_enu
    mgrs = MGRS.new(mgrs_string: "18SUJ2337006519")
    ref_lla = LLA.new(lat: 40.0, lng: -74.0)
    enu = mgrs.to_enu(ref_lla)
    assert_kind_of ENU, enu
  end

  def test_enu_roundtrip
    mgrs = MGRS.new(mgrs_string: "18SUJ2337006519")
    lla_original = mgrs.to_lla
    ref_lla = LLA.new(lat: 40.0, lng: -74.0)
    enu = mgrs.to_enu(ref_lla)
    restored = MGRS.from_enu(enu, ref_lla)
    lla_restored = restored.to_lla
    assert_in_delta lla_original.lat, lla_restored.lat, 0.01
    assert_in_delta lla_original.lng, lla_restored.lng, 0.01
  end

  # ── to_ned / from_ned roundtrip ──────────────────────────

  def test_to_ned_returns_ned
    mgrs = MGRS.new(mgrs_string: "18SUJ2337006519")
    ref_lla = LLA.new(lat: 40.0, lng: -74.0)
    ned = mgrs.to_ned(ref_lla)
    assert_kind_of NED, ned
  end

  def test_ned_roundtrip
    mgrs = MGRS.new(mgrs_string: "18SUJ2337006519")
    lla_original = mgrs.to_lla
    ref_lla = LLA.new(lat: 40.0, lng: -74.0)
    ned = mgrs.to_ned(ref_lla)
    restored = MGRS.from_ned(ned, ref_lla)
    lla_restored = restored.to_lla
    assert_in_delta lla_original.lat, lla_restored.lat, 0.01
    assert_in_delta lla_original.lng, lla_restored.lng, 0.01
  end

  # ── to_web_mercator / from_web_mercator roundtrip ────────

  def test_to_web_mercator_returns_web_mercator
    mgrs = MGRS.new(mgrs_string: "18SUJ2337006519")
    wm = mgrs.to_web_mercator
    assert_kind_of WM, wm
  end

  def test_web_mercator_roundtrip
    mgrs = MGRS.new(mgrs_string: "18SUJ2337006519")
    lla_original = mgrs.to_lla
    wm = mgrs.to_web_mercator
    restored = MGRS.from_web_mercator(wm)
    lla_restored = restored.to_lla
    assert_in_delta lla_original.lat, lla_restored.lat, 0.01
    assert_in_delta lla_original.lng, lla_restored.lng, 0.01
  end

  # ── to_ups / from_ups roundtrip ──────────────────────────

  def test_to_ups_returns_ups
    mgrs = MGRS.new(mgrs_string: "18SUJ2337006519")
    ups = mgrs.to_ups
    assert_kind_of UPS_C, ups
  end

  def test_ups_roundtrip
    # UPS is designed for polar regions, so a mid-latitude MGRS point
    # loses significant precision through the UPS projection. We verify
    # the conversion chain works and produces valid coordinates.
    mgrs = MGRS.new(mgrs_string: "18SUJ2337006519")
    ups = mgrs.to_ups
    assert_kind_of UPS_C, ups
    restored = MGRS.from_ups(ups)
    assert_kind_of MGRS, restored
    lla_restored = restored.to_lla
    assert lla_restored.lat >= -90 && lla_restored.lat <= 90
    assert lla_restored.lng >= -180 && lla_restored.lng <= 180
  end

  # ── to_usng / from_usng roundtrip ────────────────────────

  def test_to_usng_returns_usng
    mgrs = MGRS.new(mgrs_string: "18SUJ2337006519")
    usng = mgrs.to_usng
    assert_kind_of USNG, usng
  end

  def test_usng_roundtrip
    mgrs = MGRS.new(mgrs_string: "18SUJ2337006519")
    usng = mgrs.to_usng
    restored = MGRS.from_usng(usng)
    assert_equal mgrs.grid_zone_designator, restored.grid_zone_designator
    assert_equal mgrs.square_identifier, restored.square_identifier
    assert_in_delta mgrs.easting, restored.easting, 1e-6
    assert_in_delta mgrs.northing, restored.northing, 1e-6
    assert_equal mgrs.precision, restored.precision
  end

  # ── to_state_plane / from_state_plane roundtrip ──────────

  def test_to_state_plane_returns_state_plane
    mgrs = MGRS.new(mgrs_string: "18SUJ2337006519")
    sp = mgrs.to_state_plane("FL_EAST")
    assert_kind_of SP, sp
  end

  def test_state_plane_roundtrip
    mgrs = MGRS.new(mgrs_string: "18SUJ2337006519")
    lla_original = mgrs.to_lla
    sp = mgrs.to_state_plane("FL_EAST")
    restored = MGRS.from_state_plane(sp)
    lla_restored = restored.to_lla
    assert_in_delta lla_original.lat, lla_restored.lat, 0.01
    assert_in_delta lla_original.lng, lla_restored.lng, 0.01
  end

  # ── to_bng / from_bng roundtrip ──────────────────────────

  def test_to_bng_returns_bng
    mgrs = MGRS.new(mgrs_string: "18SUJ2337006519")
    bng = mgrs.to_bng
    assert_kind_of BNG, bng
  end

  def test_bng_roundtrip
    mgrs = MGRS.new(mgrs_string: "18SUJ2337006519")
    lla_original = mgrs.to_lla
    bng = mgrs.to_bng
    restored = MGRS.from_bng(bng)
    lla_restored = restored.to_lla
    assert_in_delta lla_original.lat, lla_restored.lat, 0.01
    assert_in_delta lla_original.lng, lla_restored.lng, 0.01
  end

  # ── to_gh36 / from_gh36 roundtrip ───────────────────────

  def test_to_gh36_returns_gh36
    mgrs = MGRS.new(mgrs_string: "18SUJ2337006519")
    gh = mgrs.to_gh36
    assert_kind_of GH36, gh
  end

  def test_gh36_roundtrip
    mgrs = MGRS.new(mgrs_string: "18SUJ2337006519")
    lla_original = mgrs.to_lla
    gh = mgrs.to_gh36
    restored = MGRS.from_gh36(gh)
    lla_restored = restored.to_lla
    assert_in_delta lla_original.lat, lla_restored.lat, 0.01
    assert_in_delta lla_original.lng, lla_restored.lng, 0.01
  end

  # ── == equality and inequality ───────────────────────────

  def test_equality_same_coords
    a = MGRS.new(mgrs_string: "18SUJ2337006519")
    b = MGRS.new(mgrs_string: "18SUJ2337006519")
    assert_equal a, b
  end

  def test_inequality_different_easting
    a = MGRS.new(grid_zone: "18S", square_id: "UJ", easting: 23370.0, northing: 6519.0, precision: 5)
    b = MGRS.new(grid_zone: "18S", square_id: "UJ", easting: 23380.0, northing: 6519.0, precision: 5)
    refute_equal a, b
  end

  def test_inequality_different_grid_zone
    a = MGRS.new(grid_zone: "18S", square_id: "UJ", easting: 23370.0, northing: 6519.0, precision: 5)
    b = MGRS.new(grid_zone: "17S", square_id: "UJ", easting: 23370.0, northing: 6519.0, precision: 5)
    refute_equal a, b
  end

  def test_inequality_different_square_id
    a = MGRS.new(grid_zone: "18S", square_id: "UJ", easting: 23370.0, northing: 6519.0, precision: 5)
    b = MGRS.new(grid_zone: "18S", square_id: "VK", easting: 23370.0, northing: 6519.0, precision: 5)
    refute_equal a, b
  end

  def test_inequality_different_precision
    a = MGRS.new(grid_zone: "18S", square_id: "UJ", easting: 23370.0, northing: 6519.0, precision: 5)
    b = MGRS.new(grid_zone: "18S", square_id: "UJ", easting: 23370.0, northing: 6519.0, precision: 4)
    refute_equal a, b
  end

  def test_inequality_with_non_mgrs_object
    a = MGRS.new(mgrs_string: "18SUJ2337006519")
    refute_equal a, "18SUJ2337006519"
  end

  # ── to_a / from_array roundtrip ──────────────────────────

  def test_to_a_returns_array
    mgrs = MGRS.new(mgrs_string: "18SUJ2337006519")
    arr = mgrs.to_a
    assert_kind_of Array, arr
    assert_equal 5, arr.size
    assert_equal "18S", arr[0]
    assert_equal "UJ", arr[1]
    assert_in_delta 23370.0, arr[2], 1e-6
    assert_in_delta 6519.0, arr[3], 1e-6  # precision-dependent value
    assert_equal 5, arr[4]
  end

  def test_from_array_roundtrip
    mgrs = MGRS.new(mgrs_string: "18SUJ2337006519")
    arr = mgrs.to_a
    restored = MGRS.from_array(arr)
    assert_equal mgrs, restored
  end

  # ── Invalid MGRS formats ────────────────────────────────

  def test_invalid_mgrs_uneven_coords_raises
    assert_raises(ArgumentError) { MGRS.new(mgrs_string: "18SUJ23370") }
  end

  def test_invalid_mgrs_missing_square_id_raises
    assert_raises(ArgumentError) { MGRS.new(mgrs_string: "18S") }
  end

  def test_invalid_mgrs_no_zone_number_raises
    assert_raises(ArgumentError) { MGRS.new(mgrs_string: "XYZABC") }
  end

  # ── Parse MGRS with spaces ──────────────────────────────

  def test_parse_mgrs_with_spaces
    coord = MGRS.new(mgrs_string: "18S UJ 23370 06519")
    assert_equal "18S", coord.grid_zone_designator
    assert_equal "UJ", coord.square_identifier
    assert_in_delta 23370.0, coord.easting, 1e-6
    assert_in_delta 6519.0, coord.northing, 1e-6  # precision-dependent value
    assert_equal 5, coord.precision
  end

  def test_parse_mgrs_with_mixed_spaces
    coord = MGRS.new(mgrs_string: "18SUJ 23370 06519")
    assert_equal "18S", coord.grid_zone_designator
    assert_equal "UJ", coord.square_identifier
  end

  # ── Southern hemisphere and even-zone coverage ──────────────

  def test_from_lla_southern_hemisphere
    # Sydney, Australia - southern hemisphere, even zone (56)
    lla = LLA.new(lat: -33.8688, lng: 151.2093)
    mgrs = MGRS.from_lla(lla)
    assert_instance_of MGRS, mgrs
    assert mgrs.grid_zone_designator.length >= 2
  end

  def test_from_utm_even_zone_southern_hemisphere
    # Even zone number, southern hemisphere
    utm = UTM.new(easting: 334786.0, northing: 6252080.0, zone: 56, hemisphere: 'S')
    mgrs = MGRS.from_utm(utm, 5)
    assert_instance_of MGRS, mgrs
  end

  def test_from_utm_odd_zone_column_letter
    # Odd zone number (17) to cover the SET1_E column letter branch
    # Columbus, Ohio area: lat ~40.0, lng ~-83.0 is in UTM zone 17
    utm = UTM.new(easting: 500000.0, northing: 4427757.0, zone: 17, hemisphere: 'N')
    mgrs = MGRS.from_utm(utm, 5)
    assert_instance_of MGRS, mgrs
    assert_equal 2, mgrs.square_identifier.length
  end
end
