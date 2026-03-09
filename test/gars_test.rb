# frozen_string_literal: true

require_relative "test_helper"

class GARSTest < Minitest::Test
  include Geodetic

  # --- Construction from string ---

  def test_from_string_precision_5
    g = Coordinate::GARS.new("006AG")
    assert_equal "006AG", g.to_s
    assert_equal 5, g.precision
  end

  def test_from_string_precision_6
    g = Coordinate::GARS.new("006AG3")
    assert_equal "006AG3", g.to_s
    assert_equal 6, g.precision
  end

  def test_from_string_precision_7
    g = Coordinate::GARS.new("006AG39")
    assert_equal "006AG39", g.to_s
    assert_equal 7, g.precision
  end

  def test_from_string_case_insensitive
    g = Coordinate::GARS.new("006ag39")
    assert_equal "006AG39", g.to_s
  end

  # --- Construction from LLA ---

  def test_from_lla
    lla = Coordinate::LLA.new(lat: 40.7128, lng: -74.0060)
    g = Coordinate::GARS.new(lla)
    assert_equal 7, g.precision
    assert g.valid?
  end

  def test_from_lla_30min_precision
    lla = Coordinate::LLA.new(lat: 40.7128, lng: -74.0060)
    g = Coordinate::GARS.new(lla, precision: 5)
    assert_equal 5, g.precision
  end

  def test_from_lla_15min_precision
    lla = Coordinate::LLA.new(lat: 40.7128, lng: -74.0060)
    g = Coordinate::GARS.new(lla, precision: 6)
    assert_equal 6, g.precision
  end

  # --- Roundtrip encoding/decoding ---

  def test_roundtrip_new_york
    lla = Coordinate::LLA.new(lat: 40.7128, lng: -74.0060)
    g = Coordinate::GARS.new(lla)
    result = g.to_lla
    # 5-minute precision ≈ 0.083°
    assert_in_delta 40.7128, result.lat, 0.1
    assert_in_delta(-74.0060, result.lng, 0.1)
  end

  def test_roundtrip_london
    lla = Coordinate::LLA.new(lat: 51.5074, lng: -0.1278)
    g = Coordinate::GARS.new(lla)
    result = g.to_lla
    assert_in_delta 51.5074, result.lat, 0.1
    assert_in_delta(-0.1278, result.lng, 0.1)
  end

  def test_roundtrip_tokyo
    lla = Coordinate::LLA.new(lat: 35.6762, lng: 139.6503)
    g = Coordinate::GARS.new(lla)
    result = g.to_lla
    assert_in_delta 35.6762, result.lat, 0.1
    assert_in_delta 139.6503, result.lng, 0.1
  end

  def test_roundtrip_sydney
    lla = Coordinate::LLA.new(lat: -33.8688, lng: 151.2093)
    g = Coordinate::GARS.new(lla)
    result = g.to_lla
    assert_in_delta(-33.8688, result.lat, 0.1)
    assert_in_delta 151.2093, result.lng, 0.1
  end

  def test_roundtrip_equator_prime_meridian
    lla = Coordinate::LLA.new(lat: 0.0, lng: 0.0)
    g = Coordinate::GARS.new(lla)
    result = g.to_lla
    assert_in_delta 0.0, result.lat, 0.1
    assert_in_delta 0.0, result.lng, 0.1
  end

  def test_roundtrip_30min_precision
    lla = Coordinate::LLA.new(lat: 40.7128, lng: -74.0060)
    g = Coordinate::GARS.new(lla, precision: 5)
    result = g.to_lla
    assert_in_delta 40.7128, result.lat, 0.3
    assert_in_delta(-74.0060, result.lng, 0.3)
  end

  # --- Longitude bands ---

  def test_longitude_band_west_boundary
    # -180° should map to band 001
    lla = Coordinate::LLA.new(lat: 0.0, lng: -180.0)
    g = Coordinate::GARS.new(lla, precision: 5)
    assert_equal "001", g.to_s[0, 3]
  end

  def test_longitude_band_east
    # 0° maps to band 361
    lla = Coordinate::LLA.new(lat: 0.0, lng: 0.0)
    g = Coordinate::GARS.new(lla, precision: 5)
    assert_equal "361", g.to_s[0, 3]
  end

  # --- Latitude bands ---

  def test_latitude_band_south_pole
    # -90° should map to AA
    lla = Coordinate::LLA.new(lat: -89.9, lng: 0.0)
    g = Coordinate::GARS.new(lla, precision: 5)
    assert_equal "AA", g.to_s[3, 2]
  end

  def test_latitude_band_equator
    # 0° maps to lat_band 181
    lla = Coordinate::LLA.new(lat: 0.0, lng: 0.0)
    g = Coordinate::GARS.new(lla, precision: 5)
    lat_letters = g.to_s[3, 2]
    # Band 181: first_idx = 180/24 = 7 = H, second_idx = 180%24 = 12 = N
    assert_equal "HN", lat_letters
  end

  # --- Quadrant layout ---

  def test_quadrant_nw_is_1
    # Create a point in the NW quadrant of a 30' cell
    lla = Coordinate::LLA.new(lat: 0.4, lng: 0.1)  # upper-left of cell
    g = Coordinate::GARS.new(lla, precision: 6)
    quadrant = g.to_s[5]
    assert_equal "1", quadrant
  end

  def test_quadrant_ne_is_2
    lla = Coordinate::LLA.new(lat: 0.4, lng: 0.4)  # upper-right of cell
    g = Coordinate::GARS.new(lla, precision: 6)
    quadrant = g.to_s[5]
    assert_equal "2", quadrant
  end

  def test_quadrant_sw_is_3
    lla = Coordinate::LLA.new(lat: 0.1, lng: 0.1)  # lower-left of cell
    g = Coordinate::GARS.new(lla, precision: 6)
    quadrant = g.to_s[5]
    assert_equal "3", quadrant
  end

  def test_quadrant_se_is_4
    lla = Coordinate::LLA.new(lat: 0.1, lng: 0.4)  # lower-right of cell
    g = Coordinate::GARS.new(lla, precision: 6)
    quadrant = g.to_s[5]
    assert_equal "4", quadrant
  end

  # --- Keypad layout ---

  def test_keypad_center_is_5
    # Center of a quadrant should be keypad 5
    lla = Coordinate::LLA.new(lat: 0.125, lng: 0.125)
    g = Coordinate::GARS.new(lla, precision: 7)
    keypad = g.to_s[6]
    assert_equal "5", keypad
  end

  # --- Edge cases ---

  def test_near_north_pole
    lla = Coordinate::LLA.new(lat: 89.9, lng: 0.0)
    g = Coordinate::GARS.new(lla)
    result = g.to_lla
    assert_in_delta 89.9, result.lat, 0.1
  end

  def test_near_south_pole
    lla = Coordinate::LLA.new(lat: -89.9, lng: 0.0)
    g = Coordinate::GARS.new(lla)
    result = g.to_lla
    assert_in_delta(-89.9, result.lat, 0.1)
  end

  def test_antimeridian_east
    lla = Coordinate::LLA.new(lat: 0.0, lng: 179.9)
    g = Coordinate::GARS.new(lla)
    result = g.to_lla
    assert_in_delta 179.9, result.lng, 0.1
  end

  def test_antimeridian_west
    lla = Coordinate::LLA.new(lat: 0.0, lng: -179.9)
    g = Coordinate::GARS.new(lla)
    result = g.to_lla
    assert_in_delta(-179.9, result.lng, 0.1)
  end

  # --- Validation ---

  def test_valid
    assert Coordinate::GARS.new("006AG").valid?
    assert Coordinate::GARS.new("006AG3").valid?
    assert Coordinate::GARS.new("006AG39").valid?
  end

  def test_raises_on_empty
    assert_raises(ArgumentError) { Coordinate::GARS.new("") }
  end

  def test_raises_on_invalid_length
    assert_raises(ArgumentError) { Coordinate::GARS.new("006A") }     # too short
    assert_raises(ArgumentError) { Coordinate::GARS.new("006AG391") } # too long
  end

  def test_raises_on_invalid_lon_band
    assert_raises(ArgumentError) { Coordinate::GARS.new("000AG") }   # 0 invalid
    assert_raises(ArgumentError) { Coordinate::GARS.new("721AG") }   # 721 invalid
  end

  def test_raises_on_invalid_letters
    assert_raises(ArgumentError) { Coordinate::GARS.new("006IO") }   # I and O invalid
  end

  def test_raises_on_invalid_quadrant
    assert_raises(ArgumentError) { Coordinate::GARS.new("006AG0") }  # 0 invalid
    assert_raises(ArgumentError) { Coordinate::GARS.new("006AG5") }  # 5 invalid
  end

  def test_raises_on_invalid_keypad
    assert_raises(ArgumentError) { Coordinate::GARS.new("006AG30") } # 0 invalid
  end

  # --- Equality ---

  def test_equality
    a = Coordinate::GARS.new("006AG39")
    b = Coordinate::GARS.new("006AG39")
    assert_equal a, b
  end

  def test_inequality
    a = Coordinate::GARS.new("006AG39")
    b = Coordinate::GARS.new("006AG38")
    refute_equal a, b
  end

  # --- to_s with truncation ---

  def test_to_s_truncation
    g = Coordinate::GARS.new("006AG39")
    assert_equal "006AG", g.to_s(5)
    assert_equal "006AG3", g.to_s(6)
  end

  # --- to_a ---

  def test_to_a
    g = Coordinate::GARS.new("006AG39")
    lat, lng = g.to_a
    assert_instance_of Float, lat
    assert_instance_of Float, lng
  end

  # --- Conversion to/from LLA ---

  def test_to_lla
    g = Coordinate::GARS.new("006AG39")
    lla = g.to_lla
    assert_instance_of Coordinate::LLA, lla
    assert_equal 0.0, lla.alt
  end

  def test_from_lla_class_method
    lla = Coordinate::LLA.new(lat: 40.0, lng: -74.0)
    g = Coordinate::GARS.from_lla(lla)
    assert_instance_of Coordinate::GARS, g
  end

  # --- Conversion to/from other coordinate systems ---

  def test_to_ecef
    g = Coordinate::GARS.new("361HN35")
    ecef = g.to_ecef
    assert_instance_of Coordinate::ECEF, ecef
  end

  def test_to_utm
    g = Coordinate::GARS.new("361HN35")
    utm = g.to_utm
    assert_instance_of Coordinate::UTM, utm
  end

  def test_from_utm
    utm = Coordinate::UTM.new(easting: 583960.0, northing: 4507523.0, zone: 18, hemisphere: 'N')
    g = Coordinate::GARS.from_utm(utm)
    assert_instance_of Coordinate::GARS, g
  end

  # --- Cross-hash conversions ---

  def test_to_georef
    g = Coordinate::GARS.new("361HN35")
    georef = g.to_georef
    assert_instance_of Coordinate::GEOREF, georef
  end

  def test_to_gh
    g = Coordinate::GARS.new("361HN35")
    gh = g.to_gh
    assert_instance_of Coordinate::GH, gh
  end

  def test_to_ham
    g = Coordinate::GARS.new("361HN35")
    ham = g.to_ham
    assert_instance_of Coordinate::HAM, ham
  end

  def test_to_olc
    g = Coordinate::GARS.new("361HN35")
    olc = g.to_olc
    assert_instance_of Coordinate::OLC, olc
  end

  # --- Non-hash class conversions to GARS ---

  def test_lla_to_gars
    lla = Coordinate::LLA.new(lat: 40.0, lng: -74.0)
    g = lla.to_gars
    assert_instance_of Coordinate::GARS, g
  end

  def test_utm_to_gars
    utm = Coordinate::UTM.new(easting: 583960.0, northing: 4507523.0, zone: 18, hemisphere: 'N')
    g = utm.to_gars
    assert_instance_of Coordinate::GARS, g
  end

  def test_ecef_to_gars
    ecef = Coordinate::ECEF.new(x: 1334075.0, y: -4653937.0, z: 4138729.0)
    g = ecef.to_gars
    assert_instance_of Coordinate::GARS, g
  end

  # --- Neighbors ---

  def test_neighbors
    g = Coordinate::GARS.new("361HN35")
    n = g.neighbors
    assert_equal 8, n.size
    assert_instance_of Coordinate::GARS, n[:N]
    assert_instance_of Coordinate::GARS, n[:S]
    assert_instance_of Coordinate::GARS, n[:E]
    assert_instance_of Coordinate::GARS, n[:W]
  end

  # --- to_area ---

  def test_to_area
    g = Coordinate::GARS.new("361HN35")
    area = g.to_area
    assert_instance_of Geodetic::Areas::BoundingBox, area
  end

  # --- precision_in_meters ---

  def test_precision_in_meters_5min
    g = Coordinate::GARS.new("361HN35")
    meters = g.precision_in_meters
    assert_instance_of Hash, meters
    assert meters[:lat] > 0
    assert meters[:lng] > 0
    # 5-minute ≈ ~9.3 km latitude
    assert_in_delta 9260, meters[:lat], 500
  end

  def test_precision_in_meters_30min
    g = Coordinate::GARS.new("361HN")
    meters = g.precision_in_meters
    # 30-minute ≈ ~55.6 km latitude
    assert_in_delta 55600, meters[:lat], 2000
  end

  # --- Distance and bearing methods ---

  def test_distance_to
    a = Coordinate::GARS.new("361HN35")
    b = Coordinate::GARS.new("212LX43")
    d = a.distance_to(b)
    assert_instance_of Geodetic::Distance, d
    assert d.to_f > 0
  end

  def test_bearing_to
    a = Coordinate::GARS.new("361HN35")
    b = Coordinate::GARS.new("212LX43")
    b_result = a.bearing_to(b)
    assert_instance_of Geodetic::Bearing, b_result
  end

  # --- from_string / from_array ---

  def test_from_string
    g = Coordinate::GARS.from_string("361HN35")
    assert_equal "361HN35", g.to_s
  end

  def test_from_array
    g = Coordinate::GARS.from_array([40.0, -74.0])
    assert_instance_of Coordinate::GARS, g
  end
end
