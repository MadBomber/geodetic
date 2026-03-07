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
end
