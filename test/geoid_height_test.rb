# frozen_string_literal: true

require "test_helper"
require_relative "../lib/geodetic/geoid_height"
require_relative "../lib/geodetic/coordinates/lla"

class GeoidHeightTest < Minitest::Test
  LAT = 47.6205
  LNG = -122.3493

  def setup
    @geoid = Geodetic::GeoidHeight.new(geoid_model: 'EGM2008', interpolation_method: 'bilinear')
  end

  # 1. Constructor: defaults, explicit model, invalid model raises
  def test_constructor_defaults
    geoid = Geodetic::GeoidHeight.new
    assert_equal 'EGM2008', geoid.geoid_model
    assert_equal 'bilinear', geoid.interpolation_method
  end

  def test_constructor_explicit_model
    geoid = Geodetic::GeoidHeight.new(geoid_model: 'EGM96', interpolation_method: 'bicubic')
    assert_equal 'EGM96', geoid.geoid_model
    assert_equal 'bicubic', geoid.interpolation_method
  end

  def test_constructor_invalid_model_raises
    assert_raises(RuntimeError) do
      Geodetic::GeoidHeight.new(geoid_model: 'INVALID')
    end
  end

  # 2. Accessors: geoid_model, interpolation_method
  def test_geoid_model_accessor
    assert_equal 'EGM2008', @geoid.geoid_model
    @geoid.geoid_model = 'EGM96'
    assert_equal 'EGM96', @geoid.geoid_model
  end

  def test_interpolation_method_accessor
    assert_equal 'bilinear', @geoid.interpolation_method
    @geoid.interpolation_method = 'bicubic'
    assert_equal 'bicubic', @geoid.interpolation_method
  end

  # 3. geoid_height_at: returns a Float for known lat/lng
  def test_geoid_height_at_returns_float
    result = @geoid.geoid_height_at(LAT, LNG)
    assert_instance_of Float, result
  end

  # 4. Different models return different values
  def test_different_models_return_different_values
    models = %w[EGM96 EGM2008 GEOID18 GEOID12B]
    values = models.map do |model|
      geoid = Geodetic::GeoidHeight.new(geoid_model: model)
      geoid.geoid_height_at(LAT, LNG)
    end

    assert_equal values.uniq.size, values.size, "Expected all models to return different geoid heights"
  end

  # 5. ellipsoidal_to_orthometric: result = ellipsoidal_height - geoid_height
  def test_ellipsoidal_to_orthometric
    ellipsoidal_height = 100.0
    geoid_height = @geoid.geoid_height_at(LAT, LNG)
    expected = ellipsoidal_height - geoid_height

    result = @geoid.ellipsoidal_to_orthometric(LAT, LNG, ellipsoidal_height)
    assert_in_delta expected, result, 1e-10
  end

  # 6. orthometric_to_ellipsoidal: result = orthometric_height + geoid_height
  def test_orthometric_to_ellipsoidal
    orthometric_height = 50.0
    geoid_height = @geoid.geoid_height_at(LAT, LNG)
    expected = orthometric_height + geoid_height

    result = @geoid.orthometric_to_ellipsoidal(LAT, LNG, orthometric_height)
    assert_in_delta expected, result, 1e-10
  end

  # 7. Roundtrip: ellipsoidal -> orthometric -> ellipsoidal
  def test_roundtrip_ellipsoidal_orthometric
    original_height = 123.456

    orthometric = @geoid.ellipsoidal_to_orthometric(LAT, LNG, original_height)
    recovered   = @geoid.orthometric_to_ellipsoidal(LAT, LNG, orthometric)

    assert_in_delta original_height, recovered, 1e-10
  end

  # 8. convert_vertical_datum: HAE to NAVD88 and back
  def test_convert_vertical_datum_hae_to_navd88_and_back
    original_height = 100.0

    navd88_height = @geoid.convert_vertical_datum(LAT, LNG, original_height, 'HAE', 'NAVD88')
    recovered     = @geoid.convert_vertical_datum(LAT, LNG, navd88_height, 'NAVD88', 'HAE')

    assert_in_delta original_height, recovered, 1e-6
  end

  # 9. convert_vertical_datum: invalid datum raises
  def test_convert_vertical_datum_invalid_from_raises
    assert_raises(RuntimeError) do
      @geoid.convert_vertical_datum(LAT, LNG, 100.0, 'BOGUS', 'NAVD88')
    end
  end

  def test_convert_vertical_datum_invalid_to_raises
    assert_raises(RuntimeError) do
      @geoid.convert_vertical_datum(LAT, LNG, 100.0, 'HAE', 'BOGUS')
    end
  end

  # 10. in_coverage?: CONUS point for GEOID18 true, outside false
  def test_in_coverage_conus_point_for_geoid18
    geoid = Geodetic::GeoidHeight.new(geoid_model: 'GEOID18')
    assert geoid.in_coverage?(LAT, LNG), "Seattle should be in GEOID18 CONUS coverage"
  end

  def test_in_coverage_outside_conus_for_geoid18
    geoid = Geodetic::GeoidHeight.new(geoid_model: 'GEOID18')
    refute geoid.in_coverage?(0.0, 0.0), "Equator/prime meridian should be outside GEOID18 CONUS coverage"
  end

  # 11. accuracy_estimate: returns a Float
  def test_accuracy_estimate_returns_float
    result = @geoid.accuracy_estimate(LAT, LNG)
    assert_instance_of Float, result
  end

  # 12. model_info: returns hash with expected keys
  def test_model_info_returns_hash_with_expected_keys
    info = @geoid.model_info
    assert_kind_of Hash, info
    assert info.key?(:name), "model_info should include :name"
    assert info.key?(:resolution), "model_info should include :resolution"
    assert info.key?(:accuracy), "model_info should include :accuracy"
    assert info.key?(:epoch), "model_info should include :epoch"
  end

  # 13. available_models: returns array including 'EGM96', 'EGM2008'
  def test_available_models
    models = Geodetic::GeoidHeight.available_models
    assert_kind_of Array, models
    assert_includes models, 'EGM96'
    assert_includes models, 'EGM2008'
  end

  # 14. available_vertical_datums: returns array including 'NAVD88', 'MSL'
  def test_available_vertical_datums
    datums = Geodetic::GeoidHeight.available_vertical_datums
    assert_kind_of Array, datums
    assert_includes datums, 'NAVD88'
    assert_includes datums, 'MSL'
  end
end

class GeoidHeightSupportTest < Minitest::Test
  def setup
    @lla = Geodetic::Coordinates::LLA.new(lat: 47.6205, lng: -122.3493, alt: 100.0)
  end

  # 15. geoid_height: returns Float for LLA coordinate
  def test_geoid_height_returns_float
    result = @lla.geoid_height
    assert_instance_of Float, result
  end

  # 16. orthometric_height: returns Float
  def test_orthometric_height_returns_float
    result = @lla.orthometric_height
    assert_instance_of Float, result
  end

  # 17. convert_height_datum: returns modified coordinate
  def test_convert_height_datum_returns_modified_coordinate
    result = @lla.convert_height_datum('HAE', 'NAVD88')
    assert_kind_of Geodetic::Coordinates::LLA, result
    refute_equal @lla.alt, result.alt, "Converted altitude should differ from original"
    assert_in_delta @lla.lat, result.lat, 1e-10
    assert_in_delta @lla.lng, result.lng, 1e-10
  end
end
