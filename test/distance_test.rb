# frozen_string_literal: true

require "test_helper"

class DistanceTest < Minitest::Test
  Distance = Geodetic::Distance

  # ── Construction ──────────────────────────────────────────────

  def test_new_defaults_to_meters
    d = Distance.new(1000)
    assert_equal :meters, d.unit
    assert_in_delta 1000.0, d.meters, 1e-10
  end

  def test_new_with_unit
    d = Distance.new(1609.344, unit: :miles)
    assert_equal :miles, d.unit
    assert_in_delta 1609.344, d.meters, 1e-10
  end

  def test_factory_meters
    d = Distance.meters(500)
    assert_in_delta 500.0, d.meters, 1e-10
    assert_equal :meters, d.unit
  end

  def test_factory_km
    d = Distance.km(5)
    assert_in_delta 5000.0, d.meters, 1e-10
    assert_equal :kilometers, d.unit
  end

  def test_factory_miles
    d = Distance.mi(1)
    assert_in_delta 1609.344, d.meters, 1e-6
    assert_equal :miles, d.unit
  end

  def test_factory_feet
    d = Distance.ft(5280)
    assert_in_delta 1609.344, d.meters, 1e-3
    assert_equal :feet, d.unit
  end

  def test_factory_nautical_miles
    d = Distance.nmi(1)
    assert_in_delta 1852.0, d.meters, 1e-10
    assert_equal :nautical_miles, d.unit
  end

  # ── to_f / to_i / to_s ─────────────────────────────────────

  def test_to_f_returns_display_unit_value
    d = Distance.new(1609.344).to_miles
    assert_in_delta 1.0, d.to_f, 1e-6
  end

  def test_to_i_returns_display_unit_integer
    d = Distance.new(2500).to_km
    assert_equal 2, d.to_i
  end

  def test_to_s_includes_unit_abbreviation
    d = Distance.new(1000)
    assert_match(/m$/, d.to_s)

    d_km = d.to_km
    assert_match(/km$/, d_km.to_s)

    d_mi = d.to_mi
    assert_match(/mi$/, d_mi.to_s)
  end

  def test_to_s_with_precision
    d = Distance.km(42.195)
    assert_equal "42.20 km", d.to_s          # default 2
    assert_equal "42.195 km", d.to_s(3)
    assert_equal "42.2 km", d.to_s(1)
    assert_equal "42 km", d.to_s(0)
  end

  def test_inspect
    d = Distance.new(1000)
    assert_match(/Geodetic::Distance/, d.inspect)
    assert_match(/1000/, d.inspect)
  end

  # ── Unit conversions ──────────────────────────────────────────

  def test_to_km
    d = Distance.new(5000).to_km
    assert_in_delta 5.0, d.to_f, 1e-10
    assert_equal :kilometers, d.unit
    assert_in_delta 5000.0, d.meters, 1e-10
  end

  def test_to_miles
    d = Distance.new(1609.344).to_miles
    assert_in_delta 1.0, d.to_f, 1e-6
  end

  def test_to_feet
    d = Distance.new(1.0).to_ft
    assert_in_delta 3.2808399, d.to_f, 1e-6
  end

  def test_to_yards
    d = Distance.new(0.9144).to_yd
    assert_in_delta 1.0, d.to_f, 1e-6
  end

  def test_to_cm
    d = Distance.new(1.0).to_cm
    assert_in_delta 100.0, d.to_f, 1e-10
  end

  def test_to_mm
    d = Distance.new(1.0).to_mm
    assert_in_delta 1000.0, d.to_f, 1e-10
  end

  def test_to_nautical_miles
    d = Distance.new(1852.0).to_nmi
    assert_in_delta 1.0, d.to_f, 1e-6
  end

  def test_conversion_preserves_meters
    d = Distance.new(12345.0)
    assert_in_delta 12345.0, d.to_km.meters, 1e-10
    assert_in_delta 12345.0, d.to_mi.meters, 1e-10
    assert_in_delta 12345.0, d.to_ft.meters, 1e-10
  end

  def test_miles_to_km_roundtrip
    d = Distance.mi(1)
    assert_in_delta 1.609344, d.to_km.to_f, 1e-6
  end

  def test_feet_to_miles
    d = Distance.ft(5280)
    assert_in_delta 1.0, d.to_mi.to_f, 1e-4
  end

  # ── Comparison ─────────────────────────────────────────────

  def test_equal_same_meters_different_units
    d_m = Distance.new(1000)
    d_km = Distance.new(1000).to_km
    assert_equal d_m, d_km
  end

  def test_less_than
    d1 = Distance.new(100)
    d2 = Distance.new(200)
    assert d1 < d2
  end

  def test_greater_than
    d1 = Distance.new(200)
    d2 = Distance.new(100)
    assert d1 > d2
  end

  def test_compare_with_numeric_uses_display_unit
    d = Distance.new(5000).to_km  # 5 km
    assert d > 3    # 3 km = 3000m
    assert d < 10   # 10 km = 10000m
  end

  # ── Arithmetic ──────────────────────────────────────────────

  def test_add_two_distances_preserves_receiver_unit
    d1 = Distance.new(1000).to_miles
    d2 = Distance.new(2000).to_km
    result = d1 + d2
    assert_instance_of Distance, result
    assert_equal :miles, result.unit
    assert_in_delta 3000.0, result.meters, 1e-10
  end

  def test_add_numeric_uses_display_unit
    d = Distance.new(1609.344).to_miles  # 1 mile
    result = d + 10  # add 10 miles
    assert_instance_of Distance, result
    assert_equal :miles, result.unit
    assert_in_delta 1609.344 + 10 * 1609.344, result.meters, 1e-3
  end

  def test_subtract_distances
    d1 = Distance.new(5000)
    d2 = Distance.new(3000)
    result = d1 - d2
    assert_in_delta 2000.0, result.meters, 1e-10
  end

  def test_subtract_numeric_uses_display_unit
    d = Distance.new(10000).to_km  # 10 km
    result = d - 3  # subtract 3 km
    assert_in_delta 7000.0, result.meters, 1e-10
    assert_equal :kilometers, result.unit
  end

  def test_multiply_by_scalar
    d = Distance.new(1000)
    result = d * 3
    assert_instance_of Distance, result
    assert_in_delta 3000.0, result.meters, 1e-10
  end

  def test_divide_by_scalar
    d = Distance.new(1000)
    result = d / 4
    assert_instance_of Distance, result
    assert_in_delta 250.0, result.meters, 1e-10
  end

  def test_divide_by_distance_returns_ratio
    d1 = Distance.new(1000)
    d2 = Distance.new(500)
    ratio = d1 / d2
    assert_instance_of Float, ratio
    assert_in_delta 2.0, ratio, 1e-10
  end

  def test_arithmetic_preserves_receiver_display_unit
    d = Distance.km(5)

    sum = d + Distance.mi(1)
    assert_equal :kilometers, sum.unit
    assert_in_delta 5.0 + 1.609344, sum.to_f, 1e-6

    diff = d - Distance.new(1000)
    assert_equal :kilometers, diff.unit
    assert_in_delta 4.0, diff.to_f, 1e-10

    scaled = d * 3
    assert_equal :kilometers, scaled.unit
    assert_in_delta 15.0, scaled.to_f, 1e-10

    halved = d / 2
    assert_equal :kilometers, halved.unit
    assert_in_delta 2.5, halved.to_f, 1e-10
  end

  def test_negate
    d = Distance.new(1000)
    neg = -d
    assert_in_delta(-1000.0, neg.meters, 1e-10)
  end

  def test_abs
    d = Distance.new(-1000)
    assert_in_delta 1000.0, d.abs.meters, 1e-10
  end

  def test_zero
    d = Distance.new(0)
    assert d.zero?
    refute Distance.new(1).zero?
  end

  def test_coerce_numeric_times_distance
    d = Distance.new(1000)
    result = 3 * d
    assert_in_delta 3000.0, result, 1e-10
  end

  # ── Integration with coordinate distance methods ────────────

  def test_distance_to_returns_distance
    seattle  = Geodetic::Coordinate::LLA.new(lat: 47.6205, lng: -122.3493, alt: 0.0)
    portland = Geodetic::Coordinate::LLA.new(lat: 45.5152, lng: -122.6784, alt: 0.0)

    d = seattle.distance_to(portland)
    assert_instance_of Distance, d
    assert d.meters > 200_000
    assert d.meters < 300_000
  end

  def test_distance_between_returns_distance
    seattle  = Geodetic::Coordinate::LLA.new(lat: 47.6205, lng: -122.3493, alt: 0.0)
    portland = Geodetic::Coordinate::LLA.new(lat: 45.5152, lng: -122.6784, alt: 0.0)

    d = Geodetic::Coordinate.distance_between(seattle, portland)
    assert_instance_of Distance, d
  end

  def test_distance_between_chain_returns_array_of_distances
    seattle  = Geodetic::Coordinate::LLA.new(lat: 47.6205, lng: -122.3493, alt: 0.0)
    portland = Geodetic::Coordinate::LLA.new(lat: 45.5152, lng: -122.6784, alt: 0.0)
    sf       = Geodetic::Coordinate::LLA.new(lat: 37.7749, lng: -122.4194, alt: 0.0)

    ds = Geodetic::Coordinate.distance_between(seattle, portland, sf)
    assert_instance_of Array, ds
    ds.each { |d| assert_instance_of Distance, d }
  end

  def test_straight_line_distance_returns_distance
    seattle  = Geodetic::Coordinate::LLA.new(lat: 47.6205, lng: -122.3493, alt: 0.0)
    portland = Geodetic::Coordinate::LLA.new(lat: 45.5152, lng: -122.6784, alt: 0.0)

    d = seattle.straight_line_distance_to(portland)
    assert_instance_of Distance, d
  end

  # ── Additional coverage ──────────────────────────────────────

  def test_to_inches
    d = Distance.new(0.0254).to_inches
    assert_in_delta 1.0, d.to_f, 1e-6
    assert_equal :inches, d.unit
    assert_in_delta 0.0254, d.meters, 1e-10
  end

  def test_to_yards_alias_to_yd
    d = Distance.new(0.9144)
    d_yd = d.to_yd
    assert_in_delta 1.0, d_yd.to_f, 1e-6
    assert_equal :yards, d_yd.unit

    d_yards = d.to_yards
    assert_in_delta d_yd.to_f, d_yards.to_f, 1e-10
    assert_equal d_yd.unit, d_yards.unit
  end

  def test_to_meters_returns_same_meters_with_meters_unit
    d = Distance.new(1234.5).to_km
    d_m = d.to_meters
    assert_equal :meters, d_m.unit
    assert_in_delta 1234.5, d_m.meters, 1e-10
    assert_in_delta 1234.5, d_m.to_f, 1e-10
  end

  def test_factory_inches
    d = Distance.inches(12)
    assert_in_delta 12.0 * 0.0254, d.meters, 1e-10
    assert_equal :inches, d.unit
  end

  def test_factory_yards
    d = Distance.yards(100)
    assert_in_delta 100.0 * 0.9144, d.meters, 1e-10
    assert_equal :yards, d.unit

    d_yd = Distance.yd(100)
    assert_in_delta d.meters, d_yd.meters, 1e-10
  end

  def test_factory_centimeters
    d = Distance.centimeters(250)
    assert_in_delta 2.5, d.meters, 1e-10
    assert_equal :centimeters, d.unit

    d_cm = Distance.cm(250)
    assert_in_delta d.meters, d_cm.meters, 1e-10
  end

  def test_factory_millimeters
    d = Distance.millimeters(5000)
    assert_in_delta 5.0, d.meters, 1e-10
    assert_equal :millimeters, d.unit

    d_mm = Distance.mm(5000)
    assert_in_delta d.meters, d_mm.meters, 1e-10
  end

  def test_to_s_for_feet
    d = Distance.ft(100)
    assert_match(/ft$/, d.to_s)
    assert_equal "100.00 ft", d.to_s
  end

  def test_to_s_for_yards
    d = Distance.yd(50)
    assert_match(/yd$/, d.to_s)
    assert_equal "50.00 yd", d.to_s
  end

  def test_to_s_for_inches
    d = Distance.inches(24)
    assert_match(/in$/, d.to_s)
    assert_equal "24.00 in", d.to_s
  end

  def test_to_s_for_nautical_miles
    d = Distance.nmi(3)
    assert_match(/nmi$/, d.to_s)
    assert_equal "3.00 nmi", d.to_s
  end

  def test_to_s_for_centimeters
    d = Distance.cm(150)
    assert_match(/cm$/, d.to_s)
    assert_equal "150.00 cm", d.to_s
  end

  def test_to_s_for_millimeters
    d = Distance.mm(2500)
    assert_match(/mm$/, d.to_s)
    assert_equal "2500.00 mm", d.to_s
  end

  def test_multiply_by_non_numeric_raises_argument_error
    d = Distance.new(1000)
    assert_raises(ArgumentError) { d * "hello" }
    assert_raises(ArgumentError) { d * [1, 2] }
  end

  def test_divide_by_non_numeric_non_distance_raises_argument_error
    d = Distance.new(1000)
    assert_raises(ArgumentError) { d / "hello" }
    assert_raises(ArgumentError) { d / [1, 2] }
  end

  def test_add_non_numeric_non_distance_raises_argument_error
    d = Distance.new(1000)
    assert_raises(ArgumentError) { d + "hello" }
    assert_raises(ArgumentError) { d + [1, 2] }
  end

  def test_subtract_numeric_minus_distance_via_coerce
    d = Distance.new(1000)
    result = 5000 - d
    assert_in_delta 4000.0, result, 1e-10
  end

  def test_equal_different_units_same_meters
    d1 = Distance.new(1609.344).to_miles
    d2 = Distance.new(1609.344).to_km
    assert_equal d1, d2
    assert_in_delta d1.meters, d2.meters, 1e-10
  end

  def test_spaceship_returns_nil_for_non_comparable_types
    d = Distance.new(1000)
    assert_nil d <=> "hello"
    assert_nil d <=> [1, 2]
    assert_nil d <=> nil
  end

  def test_inspect_includes_unit_abbreviation
    d = Distance.new(5000).to_km
    assert_match(/km/, d.inspect)
    assert_match(/Geodetic::Distance/, d.inspect)
    assert_match(/5\.00 km/, d.inspect)
    assert_match(/5000/, d.inspect)
  end

  def test_zero_on_zero_value_distance
    d = Distance.new(0)
    assert d.zero?
    assert Distance.km(0).zero?
    assert Distance.mi(0).zero?
    assert Distance.ft(0).zero?
    refute Distance.new(0.001).zero?
  end

  def test_coerce_with_non_numeric_raises_type_error
    d = Distance.new(100)
    assert_raises(TypeError) { "hello" * d }
  end

  def test_coerce_direct_call_with_non_numeric_raises_type_error
    d = Distance.new(100)
    assert_raises(TypeError) { d.coerce("hello") }
    assert_raises(TypeError) { d.coerce([1, 2]) }
    assert_raises(TypeError) { d.coerce(nil) }
  end
end
