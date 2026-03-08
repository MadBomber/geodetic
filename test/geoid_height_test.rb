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
    assert_raises(ArgumentError) do
      Geodetic::GeoidHeight.new(geoid_model: 'INVALID')
    end
  end

  # 2. Accessors: geoid_model, interpolation_method
  def test_geoid_model_reader
    assert_equal 'EGM2008', @geoid.geoid_model
    assert_raises(NoMethodError) { @geoid.geoid_model = 'EGM96' }
  end

  def test_interpolation_method_reader
    assert_equal 'bilinear', @geoid.interpolation_method
    assert_raises(NoMethodError) { @geoid.interpolation_method = 'bicubic' }
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
    assert_raises(ArgumentError) do
      @geoid.convert_vertical_datum(LAT, LNG, 100.0, 'BOGUS', 'NAVD88')
    end
  end

  def test_convert_vertical_datum_invalid_to_raises
    assert_raises(ArgumentError) do
      @geoid.convert_vertical_datum(LAT, LNG, 100.0, 'HAE', 'BOGUS')
    end
  end

  # 10. in_coverage?: North America point for GEOID18 true, outside false
  def test_in_coverage_north_america_point_for_geoid18
    geoid = Geodetic::GeoidHeight.new(geoid_model: 'GEOID18')
    assert geoid.in_coverage?(LAT, LNG), "Seattle should be in GEOID18 North America coverage"
  end

  def test_in_coverage_outside_north_america_for_geoid18
    geoid = Geodetic::GeoidHeight.new(geoid_model: 'GEOID18')
    refute geoid.in_coverage?(0.0, 0.0), "Equator/prime meridian should be outside GEOID18 North America coverage"
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

  # ── Additional coverage ──────────────────────────────────────

  # 15. geoid_height_at with different interpolation methods
  def test_geoid_height_at_with_bilinear_interpolation
    geoid = Geodetic::GeoidHeight.new(geoid_model: 'EGM2008', interpolation_method: 'bilinear')
    result = geoid.geoid_height_at(LAT, LNG)
    assert_instance_of Float, result
  end

  def test_geoid_height_at_with_bicubic_interpolation
    geoid = Geodetic::GeoidHeight.new(geoid_model: 'EGM96', interpolation_method: 'bicubic')
    result = geoid.geoid_height_at(LAT, LNG)
    assert_instance_of Float, result
  end

  # 16. convert_vertical_datum with MSL as source
  def test_convert_vertical_datum_msl_to_hae
    height = 50.0
    result = @geoid.convert_vertical_datum(LAT, LNG, height, 'MSL', 'HAE')
    assert_instance_of Float, result
    refute_equal height, result
  end

  def test_convert_vertical_datum_hae_to_msl
    height = 100.0
    result = @geoid.convert_vertical_datum(LAT, LNG, height, 'HAE', 'MSL')
    assert_instance_of Float, result
    refute_equal height, result
  end

  def test_convert_vertical_datum_msl_roundtrip
    original = 75.0
    to_hae = @geoid.convert_vertical_datum(LAT, LNG, original, 'MSL', 'HAE')
    recovered = @geoid.convert_vertical_datum(LAT, LNG, to_hae, 'HAE', 'MSL')
    assert_in_delta original, recovered, 1e-6
  end

  # 17. convert_vertical_datum with NGVD29 as source/target
  def test_convert_vertical_datum_ngvd29_to_hae
    height = 50.0
    result = @geoid.convert_vertical_datum(LAT, LNG, height, 'NGVD29', 'HAE')
    assert_instance_of Float, result
  end

  def test_convert_vertical_datum_hae_to_ngvd29
    height = 100.0
    result = @geoid.convert_vertical_datum(LAT, LNG, height, 'HAE', 'NGVD29')
    assert_instance_of Float, result
  end

  def test_convert_vertical_datum_ngvd29_roundtrip
    original = 60.0
    to_hae = @geoid.convert_vertical_datum(LAT, LNG, original, 'NGVD29', 'HAE')
    recovered = @geoid.convert_vertical_datum(LAT, LNG, to_hae, 'HAE', 'NGVD29')
    assert_in_delta original, recovered, 1e-6
  end

  # 18. in_coverage? for EGM96 (global model, should return true everywhere)
  def test_in_coverage_egm96_global
    geoid = Geodetic::GeoidHeight.new(geoid_model: 'EGM96')
    assert geoid.in_coverage?(0.0, 0.0), "EGM96 should cover equator/prime meridian"
    assert geoid.in_coverage?(LAT, LNG), "EGM96 should cover Seattle"
    assert geoid.in_coverage?(-33.8688, 151.2093), "EGM96 should cover Sydney"
    assert geoid.in_coverage?(35.6762, 139.6503), "EGM96 should cover Tokyo"
  end

  # 19. in_coverage? for EGM2008 (global model, should return true everywhere)
  def test_in_coverage_egm2008_global
    geoid = Geodetic::GeoidHeight.new(geoid_model: 'EGM2008')
    assert geoid.in_coverage?(0.0, 0.0), "EGM2008 should cover equator/prime meridian"
    assert geoid.in_coverage?(LAT, LNG), "EGM2008 should cover Seattle"
    assert geoid.in_coverage?(-33.8688, 151.2093), "EGM2008 should cover Sydney"
    assert geoid.in_coverage?(89.0, 0.0), "EGM2008 should cover near north pole"
  end

  # 20. in_coverage? for GEOID12B (should be CONUS only)
  def test_in_coverage_geoid12b_conus_inside
    geoid = Geodetic::GeoidHeight.new(geoid_model: 'GEOID12B')
    assert geoid.in_coverage?(LAT, LNG), "GEOID12B should cover Seattle (CONUS)"
    assert geoid.in_coverage?(40.7128, -74.0060), "GEOID12B should cover New York (CONUS)"
    assert geoid.in_coverage?(34.0522, -118.2437), "GEOID12B should cover Los Angeles (CONUS)"
  end

  def test_in_coverage_geoid12b_conus_outside
    geoid = Geodetic::GeoidHeight.new(geoid_model: 'GEOID12B')
    refute geoid.in_coverage?(0.0, 0.0), "GEOID12B should not cover equator/prime meridian"
    refute geoid.in_coverage?(51.5074, -0.1278), "GEOID12B should not cover London"
    refute geoid.in_coverage?(-33.8688, 151.2093), "GEOID12B should not cover Sydney"
  end

  # 21. accuracy_estimate for different models
  def test_accuracy_estimate_egm96
    geoid = Geodetic::GeoidHeight.new(geoid_model: 'EGM96')
    accuracy = geoid.accuracy_estimate(LAT, LNG)
    assert_instance_of Float, accuracy
    assert_in_delta 1.0, accuracy, 1e-10
  end

  def test_accuracy_estimate_egm2008
    geoid = Geodetic::GeoidHeight.new(geoid_model: 'EGM2008')
    accuracy = geoid.accuracy_estimate(LAT, LNG)
    assert_instance_of Float, accuracy
    assert_in_delta 0.5, accuracy, 1e-10
  end

  def test_accuracy_estimate_geoid18
    geoid = Geodetic::GeoidHeight.new(geoid_model: 'GEOID18')
    accuracy = geoid.accuracy_estimate(LAT, LNG)
    assert_in_delta 0.1, accuracy, 1e-10
  end

  def test_accuracy_estimate_geoid12b_inside_conus
    geoid = Geodetic::GeoidHeight.new(geoid_model: 'GEOID12B')
    accuracy = geoid.accuracy_estimate(LAT, LNG)
    assert_in_delta 0.15, accuracy, 1e-10
  end

  def test_accuracy_estimate_geoid12b_outside_conus
    geoid = Geodetic::GeoidHeight.new(geoid_model: 'GEOID12B')
    accuracy = geoid.accuracy_estimate(0.0, 0.0)
    assert_in_delta 0.45, accuracy, 1e-10
  end

  # 22. model_info for different models
  def test_model_info_egm96
    geoid = Geodetic::GeoidHeight.new(geoid_model: 'EGM96')
    info = geoid.model_info
    assert_equal 'Earth Gravitational Model 1996', info[:name]
    assert_in_delta 15.0, info[:resolution], 1e-10
    assert_in_delta 1.0, info[:accuracy], 1e-10
    assert_equal 1996, info[:epoch]
  end

  def test_model_info_geoid18
    geoid = Geodetic::GeoidHeight.new(geoid_model: 'GEOID18')
    info = geoid.model_info
    assert_equal 'GEOID18 (North America)', info[:name]
    assert_in_delta 1.0, info[:resolution], 1e-10
    assert_in_delta 0.1, info[:accuracy], 1e-10
    assert_equal 2018, info[:epoch]
    assert_equal 'North America', info[:region]
  end

  def test_model_info_geoid12b
    geoid = Geodetic::GeoidHeight.new(geoid_model: 'GEOID12B')
    info = geoid.model_info
    assert_equal 'GEOID12B (CONUS)', info[:name]
    assert_in_delta 1.0, info[:resolution], 1e-10
    assert_in_delta 0.15, info[:accuracy], 1e-10
    assert_equal 2012, info[:epoch]
    assert_equal 'CONUS', info[:region]
  end

  # ── interpolated_height tests (lines 124-142) ──

  def test_interpolated_height_at_grid_corner
    height_grid = [[1.0, 2.0], [3.0, 4.0]]
    lat_grid = [0.0, 1.0]
    lng_grid = [0.0, 1.0]

    # Bottom-left corner
    result = @geoid.interpolated_height(0.0, 0.0, height_grid, lat_grid, lng_grid)
    assert_in_delta 1.0, result, 1e-10
  end

  def test_interpolated_height_at_center
    height_grid = [[1.0, 2.0], [3.0, 4.0]]
    lat_grid = [0.0, 1.0]
    lng_grid = [0.0, 1.0]

    # Center point: bilinear interpolation of (1+2+3+4)/4 = 2.5
    result = @geoid.interpolated_height(0.5, 0.5, height_grid, lat_grid, lng_grid)
    assert_in_delta 2.5, result, 1e-10
  end

  def test_interpolated_height_along_edge
    height_grid = [[1.0, 2.0], [3.0, 4.0]]
    lat_grid = [0.0, 1.0]
    lng_grid = [0.0, 1.0]

    # Midpoint along bottom edge (lat=0, lng=0.5): (1+2)/2 = 1.5
    result = @geoid.interpolated_height(0.0, 0.5, height_grid, lat_grid, lng_grid)
    assert_in_delta 1.5, result, 1e-10
  end

  def test_interpolated_height_larger_grid
    height_grid = [
      [10.0, 20.0, 30.0],
      [40.0, 50.0, 60.0],
      [70.0, 80.0, 90.0]
    ]
    lat_grid = [0.0, 1.0, 2.0]
    lng_grid = [0.0, 1.0, 2.0]

    # Point at (0.5, 0.5) should interpolate the first cell
    result = @geoid.interpolated_height(0.5, 0.5, height_grid, lat_grid, lng_grid)
    expected = 0.5 * 0.5 * 10.0 + 0.5 * 0.5 * 20.0 + 0.5 * 0.5 * 40.0 + 0.5 * 0.5 * 50.0
    assert_in_delta expected, result, 1e-10
  end

  def test_interpolated_height_at_top_right_corner
    height_grid = [[1.0, 2.0], [3.0, 4.0]]
    lat_grid = [0.0, 1.0]
    lng_grid = [0.0, 1.0]

    result = @geoid.interpolated_height(1.0, 1.0, height_grid, lat_grid, lng_grid)
    assert_in_delta 4.0, result, 1e-10
  end

  # ── undulation_correction tests (lines 145-148) ──

  def test_undulation_correction_at_equator
    result = @geoid.undulation_correction(0.0)
    assert_in_delta 0.0, result, 1e-10
  end

  def test_undulation_correction_at_45_degrees
    lat_rad = 45.0 * Math::PI / 180.0
    expected = 10.0 * Math.sin(2.0 * lat_rad) + 5.0 * Math.sin(4.0 * lat_rad)
    result = @geoid.undulation_correction(45.0)
    assert_in_delta expected, result, 1e-10
  end

  def test_undulation_correction_at_90_degrees
    result = @geoid.undulation_correction(90.0)
    assert_in_delta 0.0, result, 1e-6
  end

  def test_undulation_correction_at_negative_latitude
    result_pos = @geoid.undulation_correction(30.0)
    result_neg = @geoid.undulation_correction(-30.0)
    # sin(2*lat) is odd, sin(4*lat) is odd => correction is odd function
    assert_in_delta(-result_pos, result_neg, 1e-10)
  end

  # ── GEOID18 outside coverage fallback (line 230) ──

  def test_geoid18_outside_coverage_falls_back_to_egm2008
    geoid18 = Geodetic::GeoidHeight.new(geoid_model: 'GEOID18')
    egm2008 = Geodetic::GeoidHeight.new(geoid_model: 'EGM2008')

    # London is outside CONUS coverage
    lat, lng = 51.5074, -0.1278
    refute geoid18.in_coverage?(lat, lng)

    geoid18_height = geoid18.geoid_height_at(lat, lng)
    egm2008_height = egm2008.geoid_height_at(lat, lng)
    assert_in_delta egm2008_height, geoid18_height, 1e-10
  end

  # ── GEOID12B outside coverage fallback (line 243) ──

  def test_geoid12b_outside_coverage_falls_back_to_egm96
    geoid12b = Geodetic::GeoidHeight.new(geoid_model: 'GEOID12B')
    egm96 = Geodetic::GeoidHeight.new(geoid_model: 'EGM96')

    # Tokyo is outside CONUS coverage
    lat, lng = 35.6762, 139.6503
    refute geoid12b.in_coverage?(lat, lng)

    geoid12b_height = geoid12b.geoid_height_at(lat, lng)
    egm96_height = egm96.geoid_height_at(lat, lng)
    assert_in_delta egm96_height, geoid12b_height, 1e-10
  end

  # ── convert_vertical_datum: HAE to HAE (ellipsoidal to ellipsoidal, line 120) ──

  def test_convert_vertical_datum_hae_to_hae_returns_same_height
    height = 100.0
    result = @geoid.convert_vertical_datum(LAT, LNG, height, 'HAE', 'HAE')
    assert_in_delta height, result, 1e-10
  end

  # ── convert_vertical_datum: orthometric to orthometric (NAVD88 to NGVD29) ──

  def test_convert_vertical_datum_navd88_to_ngvd29
    height = 50.0
    result = @geoid.convert_vertical_datum(LAT, LNG, height, 'NAVD88', 'NGVD29')
    assert_instance_of Float, result
    # Roundtrip
    recovered = @geoid.convert_vertical_datum(LAT, LNG, result, 'NGVD29', 'NAVD88')
    assert_in_delta height, recovered, 1e-6
  end

  # ── convert_vertical_datum: orthometric to orthometric (NAVD88 to MSL) ──

  def test_convert_vertical_datum_navd88_to_msl
    height = 75.0
    result = @geoid.convert_vertical_datum(LAT, LNG, height, 'NAVD88', 'MSL')
    assert_instance_of Float, result
    recovered = @geoid.convert_vertical_datum(LAT, LNG, result, 'MSL', 'NAVD88')
    assert_in_delta height, recovered, 1e-6
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

  # ── with_geoid_height class method (lines 261-263) ──

  def test_with_geoid_height_class_method
    klass = Geodetic::Coordinates::LLA.with_geoid_height('EGM96')
    assert_equal 'EGM96', klass.geoid_model
  end

  def test_geoid_model_default_before_with_geoid_height
    # Create a temporary class that includes GeoidHeightSupport
    # to test the default without interfering with LLA's class state
    klass = Class.new do
      include Geodetic::GeoidHeightSupport
    end
    assert_equal 'EGM2008', klass.geoid_model
  end

  # ── geoid_height with explicit model (line 280-284) ──

  def test_geoid_height_with_explicit_model
    result_default = @lla.geoid_height
    result_egm96 = @lla.geoid_height('EGM96')
    assert_instance_of Float, result_egm96
    refute_in_delta result_default, result_egm96, 1e-6, "Different models should return different values"
  end

  # ── orthometric_height with explicit model (lines 287-292) ──

  def test_orthometric_height_with_explicit_model
    result_default = @lla.orthometric_height
    result_egm96 = @lla.orthometric_height('EGM96')
    assert_instance_of Float, result_egm96
    refute_in_delta result_default, result_egm96, 1e-6
  end

  # ── convert_height_datum with explicit geoid model ──

  def test_convert_height_datum_with_explicit_geoid_model
    result = @lla.convert_height_datum('HAE', 'NAVD88', 'EGM96')
    assert_kind_of Geodetic::Coordinates::LLA, result
    assert_in_delta @lla.lat, result.lat, 1e-10
    assert_in_delta @lla.lng, result.lng, 1e-10
  end

  # ── from_orthometric_height module method (lines 294-296) ──

  def test_from_orthometric_height
    orthometric_height = 50.0
    lat = 47.6205
    lng = -122.3493

    ellipsoidal = Geodetic::GeoidHeightSupport.from_orthometric_height(lat, lng, orthometric_height)
    assert_instance_of Float, ellipsoidal

    # Verify it matches manual calculation
    geoid = Geodetic::GeoidHeight.new(geoid_model: 'EGM2008')
    expected = geoid.orthometric_to_ellipsoidal(lat, lng, orthometric_height)
    assert_in_delta expected, ellipsoidal, 1e-10
  end

  def test_from_orthometric_height_with_explicit_model
    orthometric_height = 50.0
    lat = 47.6205
    lng = -122.3493

    ellipsoidal = Geodetic::GeoidHeightSupport.from_orthometric_height(lat, lng, orthometric_height, 'EGM96')
    assert_instance_of Float, ellipsoidal

    geoid = Geodetic::GeoidHeight.new(geoid_model: 'EGM96')
    expected = geoid.orthometric_to_ellipsoidal(lat, lng, orthometric_height)
    assert_in_delta expected, ellipsoidal, 1e-10
  end

  def test_unsupported_geoid_model_raises
    assert_raises(ArgumentError) { Geodetic::GeoidHeight.new(geoid_model: 'INVALID_MODEL') }
  end

  def test_in_coverage_north_america_region
    geoid = Geodetic::GeoidHeight.new(geoid_model: 'GEOID18')
    # GEOID18 has 'North America' region - test a North America point
    assert geoid.in_coverage?(45.0, -100.0)
    # Canada (North America but not CONUS)
    assert geoid.in_coverage?(60.0, -120.0)
    # Outside North America
    refute geoid.in_coverage?(0.0, 0.0)
  end
end
