# frozen_string_literal: true

require_relative "test_helper"

class GEOREFTest < Minitest::Test
  include Geodetic

  # --- Construction from string ---

  def test_from_string_precision_2
    g = Coordinate::GEOREF.new("HJ")
    assert_equal "HJ", g.to_s
    assert_equal 2, g.precision
  end

  def test_from_string_precision_4
    g = Coordinate::GEOREF.new("HJAL")
    assert_equal "HJAL", g.to_s
    assert_equal 4, g.precision
  end

  def test_from_string_precision_8
    g = Coordinate::GEOREF.new("GJPJ3417")
    assert_equal "GJPJ3417", g.to_s
    assert_equal 8, g.precision
  end

  def test_from_string_precision_10
    g = Coordinate::GEOREF.new("GJPJ342171")
    assert_equal "GJPJ342171", g.to_s
    assert_equal 10, g.precision
  end

  def test_from_string_precision_12
    g = Coordinate::GEOREF.new("GJPJ34211712")
    assert_equal "GJPJ34211712", g.to_s
    assert_equal 12, g.precision
  end

  def test_from_string_case_insensitive
    g = Coordinate::GEOREF.new("gjpj3417")
    assert_equal "GJPJ3417", g.to_s
  end

  # --- Construction from LLA ---

  def test_from_lla
    lla = Coordinate::LLA.new(lat: 40.7128, lng: -74.0060)
    g = Coordinate::GEOREF.new(lla)
    assert_equal 8, g.precision
    assert g.valid?
  end

  def test_from_lla_with_precision
    lla = Coordinate::LLA.new(lat: 40.7128, lng: -74.0060)
    g = Coordinate::GEOREF.new(lla, precision: 4)
    assert_equal 4, g.precision
  end

  def test_from_lla_tile_only
    lla = Coordinate::LLA.new(lat: 40.7128, lng: -74.0060)
    g = Coordinate::GEOREF.new(lla, precision: 2)
    assert_equal 2, g.precision
    assert_equal 2, g.to_s.length
  end

  # --- Roundtrip encoding/decoding ---

  def test_roundtrip_new_york
    lla = Coordinate::LLA.new(lat: 40.7128, lng: -74.0060)
    g = Coordinate::GEOREF.new(lla)
    result = g.to_lla
    assert_in_delta 40.7128, result.lat, 0.02  # 1-minute precision
    assert_in_delta(-74.0060, result.lng, 0.02)
  end

  def test_roundtrip_london
    lla = Coordinate::LLA.new(lat: 51.5074, lng: -0.1278)
    g = Coordinate::GEOREF.new(lla)
    result = g.to_lla
    assert_in_delta 51.5074, result.lat, 0.02
    assert_in_delta(-0.1278, result.lng, 0.02)
  end

  def test_roundtrip_tokyo
    lla = Coordinate::LLA.new(lat: 35.6762, lng: 139.6503)
    g = Coordinate::GEOREF.new(lla)
    result = g.to_lla
    assert_in_delta 35.6762, result.lat, 0.02
    assert_in_delta 139.6503, result.lng, 0.02
  end

  def test_roundtrip_sydney
    lla = Coordinate::LLA.new(lat: -33.8688, lng: 151.2093)
    g = Coordinate::GEOREF.new(lla)
    result = g.to_lla
    assert_in_delta(-33.8688, result.lat, 0.02)
    assert_in_delta 151.2093, result.lng, 0.02
  end

  def test_roundtrip_equator_prime_meridian
    lla = Coordinate::LLA.new(lat: 0.0, lng: 0.0)
    g = Coordinate::GEOREF.new(lla)
    result = g.to_lla
    assert_in_delta 0.0, result.lat, 0.02
    assert_in_delta 0.0, result.lng, 0.02
  end

  def test_roundtrip_high_precision
    lla = Coordinate::LLA.new(lat: 38.2861, lng: -76.4117)
    g = Coordinate::GEOREF.new(lla, precision: 12)
    result = g.to_lla
    assert_in_delta 38.2861, result.lat, 0.0005  # 0.01-minute precision
    assert_in_delta(-76.4117, result.lng, 0.0005)
  end

  # --- Edge cases ---

  def test_north_pole
    lla = Coordinate::LLA.new(lat: 89.9999, lng: 0.0)
    g = Coordinate::GEOREF.new(lla)
    result = g.to_lla
    assert_in_delta 89.9999, result.lat, 0.02
  end

  def test_south_pole
    lla = Coordinate::LLA.new(lat: -89.9999, lng: 0.0)
    g = Coordinate::GEOREF.new(lla)
    result = g.to_lla
    assert_in_delta(-89.9999, result.lat, 0.02)
  end

  def test_antimeridian_east
    lla = Coordinate::LLA.new(lat: 0.0, lng: 179.9)
    g = Coordinate::GEOREF.new(lla)
    result = g.to_lla
    assert_in_delta 179.9, result.lng, 0.02
  end

  def test_antimeridian_west
    lla = Coordinate::LLA.new(lat: 0.0, lng: -179.9)
    g = Coordinate::GEOREF.new(lla)
    result = g.to_lla
    assert_in_delta(-179.9, result.lng, 0.02)
  end

  # --- Validation ---

  def test_valid
    assert Coordinate::GEOREF.new("GJPJ3417").valid?
    assert Coordinate::GEOREF.new("HJ").valid?
    assert Coordinate::GEOREF.new("HJAL").valid?
  end

  def test_raises_on_empty
    assert_raises(ArgumentError) { Coordinate::GEOREF.new("") }
  end

  def test_raises_on_invalid_length
    assert_raises(ArgumentError) { Coordinate::GEOREF.new("GJPJ34") }  # length 6 invalid
    assert_raises(ArgumentError) { Coordinate::GEOREF.new("GJP") }     # length 3 invalid
    assert_raises(ArgumentError) { Coordinate::GEOREF.new("GJPJ3") }   # length 5 invalid
  end

  def test_raises_on_invalid_characters
    assert_raises(ArgumentError) { Coordinate::GEOREF.new("OIAA0000") }  # O and I invalid
    assert_raises(ArgumentError) { Coordinate::GEOREF.new("AAIO0000") }  # I and O invalid in degree
  end

  # --- Equality ---

  def test_equality
    a = Coordinate::GEOREF.new("GJPJ3417")
    b = Coordinate::GEOREF.new("GJPJ3417")
    assert_equal a, b
  end

  def test_inequality
    a = Coordinate::GEOREF.new("GJPJ3417")
    b = Coordinate::GEOREF.new("GJPJ3418")
    refute_equal a, b
  end

  # --- to_s with truncation ---

  def test_to_s_truncation
    g = Coordinate::GEOREF.new("GJPJ3417")
    assert_equal "GJPJ", g.to_s(4)
    assert_equal "GJ", g.to_s(2)
  end

  # --- to_a ---

  def test_to_a
    g = Coordinate::GEOREF.new("GJPJ3417")
    lat, lng = g.to_a
    assert_instance_of Float, lat
    assert_instance_of Float, lng
  end

  # --- Conversion to/from LLA ---

  def test_to_lla
    g = Coordinate::GEOREF.new("GJPJ3417")
    lla = g.to_lla
    assert_instance_of Coordinate::LLA, lla
    assert_equal 0.0, lla.alt
  end

  def test_from_lla_class_method
    lla = Coordinate::LLA.new(lat: 40.0, lng: -74.0)
    g = Coordinate::GEOREF.from_lla(lla)
    assert_instance_of Coordinate::GEOREF, g
  end

  # --- Conversion to/from other coordinate systems ---

  def test_to_ecef
    g = Coordinate::GEOREF.new("GJPJ3417")
    ecef = g.to_ecef
    assert_instance_of Coordinate::ECEF, ecef
  end

  def test_to_utm
    g = Coordinate::GEOREF.new("GJPJ3417")
    utm = g.to_utm
    assert_instance_of Coordinate::UTM, utm
  end

  def test_from_utm
    utm = Coordinate::UTM.new(easting: 583960.0, northing: 4507523.0, zone: 18, hemisphere: 'N')
    g = Coordinate::GEOREF.from_utm(utm)
    assert_instance_of Coordinate::GEOREF, g
  end

  # --- Cross-hash conversions ---

  def test_to_gars
    g = Coordinate::GEOREF.new("GJPJ3417")
    gars = g.to_gars
    assert_instance_of Coordinate::GARS, gars
  end

  def test_to_gh
    g = Coordinate::GEOREF.new("GJPJ3417")
    gh = g.to_gh
    assert_instance_of Coordinate::GH, gh
  end

  def test_to_ham
    g = Coordinate::GEOREF.new("GJPJ3417")
    ham = g.to_ham
    assert_instance_of Coordinate::HAM, ham
  end

  def test_to_olc
    g = Coordinate::GEOREF.new("GJPJ3417")
    olc = g.to_olc
    assert_instance_of Coordinate::OLC, olc
  end

  # --- Non-hash class conversions to GEOREF ---

  def test_lla_to_georef
    lla = Coordinate::LLA.new(lat: 40.0, lng: -74.0)
    g = lla.to_georef
    assert_instance_of Coordinate::GEOREF, g
  end

  def test_utm_to_georef
    utm = Coordinate::UTM.new(easting: 583960.0, northing: 4507523.0, zone: 18, hemisphere: 'N')
    g = utm.to_georef
    assert_instance_of Coordinate::GEOREF, g
  end

  def test_ecef_to_georef
    ecef = Coordinate::ECEF.new(x: 1334075.0, y: -4653937.0, z: 4138729.0)
    g = ecef.to_georef
    assert_instance_of Coordinate::GEOREF, g
  end

  # --- Neighbors ---

  def test_neighbors
    g = Coordinate::GEOREF.new("GJPJ3417")
    n = g.neighbors
    assert_equal 8, n.size
    assert_instance_of Coordinate::GEOREF, n[:N]
    assert_instance_of Coordinate::GEOREF, n[:S]
    assert_instance_of Coordinate::GEOREF, n[:E]
    assert_instance_of Coordinate::GEOREF, n[:W]
  end

  # --- to_area ---

  def test_to_area
    g = Coordinate::GEOREF.new("GJPJ3417")
    area = g.to_area
    assert_instance_of Geodetic::Areas::Rectangle, area
  end

  # --- precision_in_meters ---

  def test_precision_in_meters
    g = Coordinate::GEOREF.new("GJPJ3417")
    meters = g.precision_in_meters
    assert_instance_of Hash, meters
    assert meters[:lat] > 0
    assert meters[:lng] > 0
    # 1-minute precision should be roughly 1.8 km
    assert_in_delta 1850, meters[:lat], 200
  end

  # --- Distance and bearing methods ---

  def test_distance_to
    a = Coordinate::GEOREF.new("GJPJ3417")
    b = Coordinate::GEOREF.new("HJAL4243")
    d = a.distance_to(b)
    assert_instance_of Geodetic::Distance, d
    assert d.to_f > 0
  end

  def test_bearing_to
    a = Coordinate::GEOREF.new("GJPJ3417")
    b = Coordinate::GEOREF.new("HJAL4243")
    b_result = a.bearing_to(b)
    assert_instance_of Geodetic::Bearing, b_result
  end

  # --- from_string / from_array ---

  def test_from_string
    g = Coordinate::GEOREF.from_string("GJPJ3417")
    assert_equal "GJPJ3417", g.to_s
  end

  def test_from_array
    g = Coordinate::GEOREF.from_array([38.0, -76.0])
    assert_instance_of Coordinate::GEOREF, g
  end
end
