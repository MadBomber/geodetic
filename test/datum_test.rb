# frozen_string_literal: true

require "test_helper"

class DatumTest < Minitest::Test
  Datum = Geodetic::Datum

  # -- Constructor ----------------------------------------------------------

  def test_constructor_valid_name
    datum = Datum.new(name: "WGS84")
    assert_equal "WGS84", datum.name
  end

  def test_constructor_case_insensitive
    datum = Datum.new(name: "wgs84")
    assert_equal "WGS84", datum.name
  end

  # -- Invalid name raises --------------------------------------------------

  def test_invalid_name_raises
    assert_raises(NameError) { Datum.new(name: "BOGUS_DATUM") }
  end

  # -- Attributes -----------------------------------------------------------

  def test_attribute_name
    datum = Datum.new(name: "WGS84")
    assert_equal "WGS84", datum.name
  end

  def test_attribute_desc
    datum = Datum.new(name: "WGS84")
    assert_equal "World Geodetic System 1984", datum.desc
  end

  def test_attribute_a
    datum = Datum.new(name: "WGS84")
    assert_in_delta 6378137.0, datum.a, 1e-6
  end

  def test_attribute_f_inv
    datum = Datum.new(name: "WGS84")
    assert_in_delta 298.257223563, datum.f_inv, 1e-9
  end

  def test_attribute_f
    datum = Datum.new(name: "WGS84")
    assert_in_delta(1.0 / 298.257223563, datum.f, 1e-15)
  end

  def test_attribute_b
    datum = Datum.new(name: "WGS84")
    assert_in_delta 6356752.3142451793, datum.b, 1e-4
  end

  def test_attribute_e
    datum = Datum.new(name: "WGS84")
    expected_e = Math.sqrt(0.00669437999014132)
    assert_in_delta expected_e, datum.e, 1e-10
  end

  def test_attribute_e2
    datum = Datum.new(name: "WGS84")
    assert_in_delta 0.00669437999014132, datum.e2, 1e-15
  end

  # -- WGS84 constant ------------------------------------------------------

  def test_wgs84_constant_exists
    assert_instance_of Datum, Geodetic::WGS84
  end

  def test_wgs84_constant_a
    assert_in_delta 6378137.0, Geodetic::WGS84.a, 1e-6
  end

  def test_wgs84_constant_f_inv
    assert_in_delta 298.257223563, Geodetic::WGS84.f_inv, 1e-9
  end

  # -- Datum.list -----------------------------------------------------------

  def test_list_returns_nil
    assert_nil Datum.list
  end

  # -- Datum.get ------------------------------------------------------------

  def test_get_returns_hash
    result = Datum.get("WGS84")
    assert_instance_of Hash, result
  end

  def test_get_has_correct_keys
    result = Datum.get("WGS84")
    %w[name desc a f_inv f b e2 e].each do |key|
      assert result.key?(key), "Expected key '#{key}' in Datum.get result"
    end
  end

  def test_get_correct_a_value
    result = Datum.get("WGS84")
    assert_in_delta 6378137.0, result["a"], 1e-6
  end

  def test_get_invalid_name_raises
    assert_raises(NameError) { Datum.get("BOGUS_DATUM") }
  end

  # -- Module functions: deg2rad / rad2deg ----------------------------------

  def test_deg2rad_180_to_pi
    assert_in_delta Math::PI, Geodetic.deg2rad(180), 1e-10
  end

  def test_rad2deg_pi_to_180
    assert_in_delta 180.0, Geodetic.rad2deg(Math::PI), 1e-10
  end

  # -- Constants ------------------------------------------------------------

  def test_rad_per_deg_exists
    assert_in_delta 0.0174532925199433, Geodetic::RAD_PER_DEG, 1e-13
  end

  def test_deg_per_rad_exists
    assert_in_delta 57.2957795130823, Geodetic::DEG_PER_RAD, 1e-10
  end

  def test_quarter_pi_exists
    assert_in_delta 0.785398163397448, Geodetic::QUARTER_PI, 1e-12
  end

  def test_half_pi_exists
    assert_in_delta 1.5707963267949, Geodetic::HALF_PI, 1e-10
  end

  def test_feet_per_meter_exists
    assert_in_delta 3.2808399, Geodetic::FEET_PER_METER, 1e-7
  end

  def test_gravity_constant_exists
    assert_in_delta 9.80665, Geodetic::GRAVITY, 1e-5
  end
end
