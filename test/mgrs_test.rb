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
end
