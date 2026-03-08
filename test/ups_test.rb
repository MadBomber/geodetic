# frozen_string_literal: true

require "test_helper"
require_relative "../lib/geodetic/coordinates/ups"
require_relative "../lib/geodetic/coordinates/lla"

class UpsTest < Minitest::Test
  UPS = Geodetic::Coordinates::UPS
  LLA = Geodetic::Coordinates::LLA

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
end
