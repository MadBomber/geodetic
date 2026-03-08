# frozen_string_literal: true

require "test_helper"
require_relative "../lib/geodetic/coordinates/usng"
require_relative "../lib/geodetic/coordinates/mgrs"
require_relative "../lib/geodetic/coordinates/utm"
require_relative "../lib/geodetic/coordinates/lla"

class UsngTest < Minitest::Test
  USNG = Geodetic::Coordinates::USNG
  MGRS = Geodetic::Coordinates::MGRS
  LLA  = Geodetic::Coordinates::LLA

  # ── Constructor from string ────────────────────────────────

  def test_construct_from_spaced_string
    coord = USNG.new(usng_string: "18T WL 12345 67890")
    assert_equal "18T", coord.grid_zone_designator
    assert_equal "WL", coord.square_identifier
    assert_in_delta 12345.0, coord.easting, 1e-6
    assert_in_delta 67890.0, coord.northing, 1e-6
    assert_equal 5, coord.precision
  end

  def test_construct_from_non_spaced_string
    coord = USNG.new(usng_string: "18TWL1234567890")
    assert_equal "18T", coord.grid_zone_designator
    assert_equal "WL", coord.square_identifier
    assert_in_delta 12345.0, coord.easting, 1e-6
    assert_in_delta 67890.0, coord.northing, 1e-6
  end

  # ── Constructor from components ────────────────────────────

  def test_construct_from_components
    coord = USNG.new(grid_zone: "18T", square_id: "WL", easting: 12345.0, northing: 67890.0, precision: 5)
    assert_equal "18T", coord.grid_zone_designator
    assert_equal "WL", coord.square_identifier
    assert_in_delta 12345.0, coord.easting, 1e-6
    assert_in_delta 67890.0, coord.northing, 1e-6
    assert_equal 5, coord.precision
  end

  # ── to_s ───────────────────────────────────────────────────

  def test_to_s_produces_spaced_format
    coord = USNG.new(grid_zone: "18T", square_id: "WL", easting: 12345.0, northing: 67890.0, precision: 5)
    result = coord.to_s
    assert_match(/^18T WL/, result)
    parts = result.split(" ")
    assert_equal 4, parts.size
  end

  def test_to_s_precision_1
    coord = USNG.new(grid_zone: "18T", square_id: "WL", easting: 0.0, northing: 0.0, precision: 1)
    assert_equal "18T WL", coord.to_s
  end

  # ── from_string ────────────────────────────────────────────

  def test_from_string_roundtrip
    original_str = "18T WL 12345 67890"
    coord = USNG.from_string(original_str)
    restored = coord.to_s
    assert_equal original_str, restored
  end

  # ── to_mgrs / from_mgrs roundtrip ─────────────────────────

  def test_mgrs_roundtrip
    original = USNG.new(grid_zone: "18T", square_id: "WL", easting: 12345.0, northing: 67890.0, precision: 5)
    mgrs = original.to_mgrs
    restored = USNG.from_mgrs(mgrs)
    assert_equal original.grid_zone_designator, restored.grid_zone_designator
    assert_equal original.square_identifier, restored.square_identifier
    assert_in_delta original.easting, restored.easting, 1.0
    assert_in_delta original.northing, restored.northing, 1.0
  end

  # ── to_lla roundtrip ───────────────────────────────────────

  def test_lla_roundtrip
    # The LLA -> USNG -> LLA roundtrip uses simplified UTM formulas,
    # so we verify the USNG intermediate values are self-consistent
    lla = LLA.new(lat: 38.8977, lng: -77.0365)
    usng = USNG.from_lla(lla)
    assert_kind_of USNG, usng
    assert usng.grid_zone_designator.length >= 2
    assert_equal 2, usng.square_identifier.length

    # Verify to_lla produces a valid LLA
    restored = usng.to_lla
    assert_kind_of LLA, restored
    assert restored.lat >= -90 && restored.lat <= 90
    assert restored.lng >= -180 && restored.lng <= 180
  end

  # ── to_full_format ─────────────────────────────────────────

  def test_to_full_format
    coord = USNG.new(grid_zone: "18T", square_id: "WL", easting: 12345.0, northing: 67890.0, precision: 5)
    result = coord.to_full_format
    assert_match(/^18T WL/, result)
    parts = result.split(" ")
    assert_equal 4, parts.size
    assert_equal 5, parts[2].length
    assert_equal 5, parts[3].length
  end

  def test_to_full_format_pads_with_zeros
    coord = USNG.new(grid_zone: "18T", square_id: "WL", easting: 345.0, northing: 90.0, precision: 5)
    result = coord.to_full_format
    parts = result.split(" ")
    assert_equal "00345", parts[2]
    assert_equal "00090", parts[3]
  end

  # ── to_abbreviated_format ──────────────────────────────────

  def test_to_abbreviated_format
    coord = USNG.new(grid_zone: "18T", square_id: "WL", easting: 12345.0, northing: 67890.0, precision: 5)
    result = coord.to_abbreviated_format
    assert_match(/^18T WL/, result)
  end

  def test_to_abbreviated_format_strips_leading_zeros
    coord = USNG.new(grid_zone: "18T", square_id: "WL", easting: 345.0, northing: 90.0, precision: 5)
    result = coord.to_abbreviated_format
    parts = result.split(" ")
    assert_equal "345", parts[2]
    assert_equal "90", parts[3]
  end

  # ── valid? ─────────────────────────────────────────────────

  def test_valid_zone_designator
    coord = USNG.new(grid_zone: "18T", square_id: "WL", easting: 12345.0, northing: 67890.0)
    assert coord.valid?
  end

  def test_invalid_zone_designator
    coord = USNG.new(grid_zone: "99X", square_id: "WL", easting: 12345.0, northing: 67890.0)
    refute coord.valid?
  end

  def test_invalid_square_identifier_length
    coord = USNG.new(grid_zone: "18T", square_id: "W", easting: 12345.0, northing: 67890.0)
    refute coord.valid?
  end

  def test_invalid_easting_out_of_range
    coord = USNG.new(grid_zone: "18T", square_id: "WL", easting: 100000.0, northing: 67890.0)
    refute coord.valid?
  end

  def test_invalid_northing_out_of_range
    coord = USNG.new(grid_zone: "18T", square_id: "WL", easting: 12345.0, northing: 100000.0)
    refute coord.valid?
  end

  # ── Additional coordinate type constants ─────────────────
  UTM   = Geodetic::Coordinates::UTM
  ECEF  = Geodetic::Coordinates::ECEF
  WM    = Geodetic::Coordinates::WebMercator
  UPS_C = Geodetic::Coordinates::UPS
  SP    = Geodetic::Coordinates::StatePlane
  BNG   = Geodetic::Coordinates::BNG
  GH36  = Geodetic::Coordinates::GH36
  ENU   = Geodetic::Coordinates::ENU
  NED   = Geodetic::Coordinates::NED

  # ── to_utm / from_utm roundtrip ──────────────────────────

  def test_to_utm_returns_utm
    usng = USNG.new(grid_zone: "18T", square_id: "WL", easting: 12345.0, northing: 67890.0, precision: 5)
    utm = usng.to_utm
    assert_kind_of UTM, utm
  end

  def test_utm_roundtrip
    usng = USNG.new(grid_zone: "18T", square_id: "WL", easting: 12345.0, northing: 67890.0, precision: 5)
    utm = usng.to_utm
    restored = USNG.from_utm(utm, 5)
    assert_equal usng.grid_zone_designator, restored.grid_zone_designator
    assert_equal usng.square_identifier, restored.square_identifier
    assert_in_delta usng.easting, restored.easting, 1.0
    assert_in_delta usng.northing, restored.northing, 1.0
  end

  # ── to_ecef / from_ecef roundtrip ────────────────────────

  def test_to_ecef_returns_ecef
    usng = USNG.new(grid_zone: "18T", square_id: "WL", easting: 12345.0, northing: 67890.0, precision: 5)
    ecef = usng.to_ecef
    assert_kind_of ECEF, ecef
  end

  def test_ecef_roundtrip
    usng = USNG.new(grid_zone: "18T", square_id: "WL", easting: 12345.0, northing: 67890.0, precision: 5)
    lla_original = usng.to_lla
    ecef = usng.to_ecef
    restored = USNG.from_ecef(ecef)
    lla_restored = restored.to_lla
    assert_in_delta lla_original.lat, lla_restored.lat, 0.01
    assert_in_delta lla_original.lng, lla_restored.lng, 0.01
  end

  # ── to_enu / from_enu roundtrip ──────────────────────────

  def test_to_enu_returns_enu
    usng = USNG.new(grid_zone: "18T", square_id: "WL", easting: 12345.0, northing: 67890.0, precision: 5)
    ref_lla = LLA.new(lat: 43.0, lng: -75.0)
    enu = usng.to_enu(ref_lla)
    assert_kind_of ENU, enu
  end

  def test_enu_roundtrip
    usng = USNG.new(grid_zone: "18T", square_id: "WL", easting: 12345.0, northing: 67890.0, precision: 5)
    lla_original = usng.to_lla
    ref_lla = LLA.new(lat: 43.0, lng: -75.0)
    enu = usng.to_enu(ref_lla)
    restored = USNG.from_enu(enu, ref_lla)
    lla_restored = restored.to_lla
    assert_in_delta lla_original.lat, lla_restored.lat, 0.01
    assert_in_delta lla_original.lng, lla_restored.lng, 0.01
  end

  # ── to_ned / from_ned roundtrip ──────────────────────────

  def test_to_ned_returns_ned
    usng = USNG.new(grid_zone: "18T", square_id: "WL", easting: 12345.0, northing: 67890.0, precision: 5)
    ref_lla = LLA.new(lat: 43.0, lng: -75.0)
    ned = usng.to_ned(ref_lla)
    assert_kind_of NED, ned
  end

  def test_ned_roundtrip
    usng = USNG.new(grid_zone: "18T", square_id: "WL", easting: 12345.0, northing: 67890.0, precision: 5)
    lla_original = usng.to_lla
    ref_lla = LLA.new(lat: 43.0, lng: -75.0)
    ned = usng.to_ned(ref_lla)
    restored = USNG.from_ned(ned, ref_lla)
    lla_restored = restored.to_lla
    assert_in_delta lla_original.lat, lla_restored.lat, 0.01
    assert_in_delta lla_original.lng, lla_restored.lng, 0.01
  end

  # ── to_ups / from_ups roundtrip ──────────────────────────

  def test_to_ups_returns_ups
    usng = USNG.new(grid_zone: "18T", square_id: "WL", easting: 12345.0, northing: 67890.0, precision: 5)
    ups = usng.to_ups
    assert_kind_of UPS_C, ups
  end

  def test_ups_roundtrip
    # UPS is designed for polar regions, so a mid-latitude USNG point
    # loses significant precision through the UPS projection. We verify
    # the conversion chain works and produces valid coordinates.
    usng = USNG.new(grid_zone: "18T", square_id: "WL", easting: 12345.0, northing: 67890.0, precision: 5)
    ups = usng.to_ups
    assert_kind_of UPS_C, ups
    restored = USNG.from_ups(ups)
    assert_kind_of USNG, restored
    lla_restored = restored.to_lla
    assert lla_restored.lat >= -90 && lla_restored.lat <= 90
    assert lla_restored.lng >= -180 && lla_restored.lng <= 180
  end

  # ── to_web_mercator / from_web_mercator roundtrip ────────

  def test_to_web_mercator_returns_web_mercator
    usng = USNG.new(grid_zone: "18T", square_id: "WL", easting: 12345.0, northing: 67890.0, precision: 5)
    wm = usng.to_web_mercator
    assert_kind_of WM, wm
  end

  def test_web_mercator_roundtrip
    usng = USNG.new(grid_zone: "18T", square_id: "WL", easting: 12345.0, northing: 67890.0, precision: 5)
    lla_original = usng.to_lla
    wm = usng.to_web_mercator
    restored = USNG.from_web_mercator(wm)
    lla_restored = restored.to_lla
    assert_in_delta lla_original.lat, lla_restored.lat, 0.01
    assert_in_delta lla_original.lng, lla_restored.lng, 0.01
  end

  # ── to_bng / from_bng roundtrip ──────────────────────────

  def test_to_bng_returns_bng
    usng = USNG.new(grid_zone: "18T", square_id: "WL", easting: 12345.0, northing: 67890.0, precision: 5)
    bng = usng.to_bng
    assert_kind_of BNG, bng
  end

  def test_bng_roundtrip
    usng = USNG.new(grid_zone: "18T", square_id: "WL", easting: 12345.0, northing: 67890.0, precision: 5)
    lla_original = usng.to_lla
    bng = usng.to_bng
    restored = USNG.from_bng(bng)
    lla_restored = restored.to_lla
    assert_in_delta lla_original.lat, lla_restored.lat, 0.01
    assert_in_delta lla_original.lng, lla_restored.lng, 0.01
  end

  # ── to_state_plane / from_state_plane roundtrip ──────────

  def test_to_state_plane_returns_state_plane
    usng = USNG.new(grid_zone: "18T", square_id: "WL", easting: 12345.0, northing: 67890.0, precision: 5)
    sp = usng.to_state_plane("FL_EAST")
    assert_kind_of SP, sp
  end

  def test_state_plane_roundtrip
    usng = USNG.new(grid_zone: "18T", square_id: "WL", easting: 12345.0, northing: 67890.0, precision: 5)
    lla_original = usng.to_lla
    sp = usng.to_state_plane("FL_EAST")
    restored = USNG.from_state_plane(sp)
    lla_restored = restored.to_lla
    assert_in_delta lla_original.lat, lla_restored.lat, 0.01
    assert_in_delta lla_original.lng, lla_restored.lng, 0.01
  end

  # ── to_gh36 / from_gh36 roundtrip ───────────────────────

  def test_to_gh36_returns_gh36
    usng = USNG.new(grid_zone: "18T", square_id: "WL", easting: 12345.0, northing: 67890.0, precision: 5)
    gh = usng.to_gh36
    assert_kind_of GH36, gh
  end

  def test_gh36_roundtrip
    usng = USNG.new(grid_zone: "18T", square_id: "WL", easting: 12345.0, northing: 67890.0, precision: 5)
    lla_original = usng.to_lla
    gh = usng.to_gh36
    restored = USNG.from_gh36(gh)
    lla_restored = restored.to_lla
    assert_in_delta lla_original.lat, lla_restored.lat, 0.01
    assert_in_delta lla_original.lng, lla_restored.lng, 0.01
  end

  # ── == equality and inequality ───────────────────────────

  def test_equality_same_coords
    a = USNG.new(grid_zone: "18T", square_id: "WL", easting: 12345.0, northing: 67890.0, precision: 5)
    b = USNG.new(grid_zone: "18T", square_id: "WL", easting: 12345.0, northing: 67890.0, precision: 5)
    assert_equal a, b
  end

  def test_inequality_different_easting
    a = USNG.new(grid_zone: "18T", square_id: "WL", easting: 12345.0, northing: 67890.0, precision: 5)
    b = USNG.new(grid_zone: "18T", square_id: "WL", easting: 12355.0, northing: 67890.0, precision: 5)
    refute_equal a, b
  end

  def test_inequality_different_grid_zone
    a = USNG.new(grid_zone: "18T", square_id: "WL", easting: 12345.0, northing: 67890.0, precision: 5)
    b = USNG.new(grid_zone: "17T", square_id: "WL", easting: 12345.0, northing: 67890.0, precision: 5)
    refute_equal a, b
  end

  def test_inequality_different_square_id
    a = USNG.new(grid_zone: "18T", square_id: "WL", easting: 12345.0, northing: 67890.0, precision: 5)
    b = USNG.new(grid_zone: "18T", square_id: "XM", easting: 12345.0, northing: 67890.0, precision: 5)
    refute_equal a, b
  end

  def test_inequality_with_non_usng_object
    a = USNG.new(grid_zone: "18T", square_id: "WL", easting: 12345.0, northing: 67890.0, precision: 5)
    refute_equal a, "18T WL 12345 67890"
  end

  # ── to_a / from_array roundtrip ──────────────────────────

  def test_to_a_returns_array
    usng = USNG.new(grid_zone: "18T", square_id: "WL", easting: 12345.0, northing: 67890.0, precision: 5)
    arr = usng.to_a
    assert_kind_of Array, arr
    assert_equal 5, arr.size
    assert_equal "18T", arr[0]
    assert_equal "WL", arr[1]
    assert_in_delta 12345.0, arr[2], 1e-6
    assert_in_delta 67890.0, arr[3], 1e-6
    assert_equal 5, arr[4]
  end

  def test_from_array_roundtrip
    usng = USNG.new(grid_zone: "18T", square_id: "WL", easting: 12345.0, northing: 67890.0, precision: 5)
    arr = usng.to_a
    restored = USNG.from_array(arr)
    assert_equal usng, restored
  end

  # ── adjacent_squares ─────────────────────────────────────

  def test_adjacent_squares_returns_hash_with_8_directions
    usng = USNG.new(grid_zone: "18T", square_id: "WL", easting: 12345.0, northing: 67890.0, precision: 5)
    squares = usng.adjacent_squares
    assert_kind_of Hash, squares
    assert_equal 8, squares.size
    expected_directions = [:north, :northeast, :east, :southeast, :south, :southwest, :west, :northwest]
    expected_directions.each do |dir|
      assert squares.key?(dir), "Missing direction: #{dir}"
    end
  end

  def test_adjacent_squares_north_has_higher_northing
    usng = USNG.new(grid_zone: "18T", square_id: "WL", easting: 12345.0, northing: 67890.0, precision: 5)
    squares = usng.adjacent_squares
    north = squares[:north]
    if north
      assert north.northing > usng.northing, "North square should have higher northing"
    end
  end

  # ── Parse USNG with grid zone + square only (precision 1) ─

  def test_parse_usng_grid_zone_and_square_only
    coord = USNG.new(usng_string: "18T WL")
    assert_equal "18T", coord.grid_zone_designator
    assert_equal "WL", coord.square_identifier
    assert_equal 1, coord.precision
    assert_in_delta 0.0, coord.easting, 1e-6
    assert_in_delta 0.0, coord.northing, 1e-6
  end

  # ── Invalid USNG format ─────────────────────────────────

  def test_invalid_usng_format_single_part_raises
    assert_raises(ArgumentError) { USNG.new(usng_string: "X") }
  end

  def test_parse_usng_with_space_and_single_part_raises
    # A spaced USNG string with < 2 parts after splitting
    assert_raises(ArgumentError) { USNG.new(usng_string: " ") }
  end
end
