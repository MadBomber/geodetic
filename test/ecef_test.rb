# frozen_string_literal: true

require "test_helper"
require_relative "../lib/geodetic/coordinates/ecef"
require_relative "../lib/geodetic/coordinates/lla"
require_relative "../lib/geodetic/coordinates/utm"
require_relative "../lib/geodetic/coordinates/enu"
require_relative "../lib/geodetic/coordinates/ned"

class EcefTest < Minitest::Test
  ECEF = Geodetic::Coordinates::ECEF
  LLA  = Geodetic::Coordinates::LLA
  UTM  = Geodetic::Coordinates::UTM
  ENU  = Geodetic::Coordinates::ENU
  NED  = Geodetic::Coordinates::NED

  # Known reference: Seattle Space Needle area
  # LLA: 47.6205, -122.3493, 184.0
  # Approximate ECEF values computed from that LLA
  SEATTLE_LLA = LLA.new(lat: 47.6205, lng: -122.3493, alt: 184.0)
  SEATTLE_ECEF = SEATTLE_LLA.to_ecef

  # --- Constructor ---

  def test_default_constructor
    ecef = ECEF.new
    assert_in_delta 0.0, ecef.x, 1e-10
    assert_in_delta 0.0, ecef.y, 1e-10
    assert_in_delta 0.0, ecef.z, 1e-10
  end

  def test_keyword_args_constructor
    ecef = ECEF.new(x: 1000.0, y: 2000.0, z: 3000.0)
    assert_in_delta 1000.0, ecef.x, 1e-10
    assert_in_delta 2000.0, ecef.y, 1e-10
    assert_in_delta 3000.0, ecef.z, 1e-10
  end

  # --- Accessors ---

  def test_x_reader
    ecef = ECEF.new(x: 42.5)
    assert_in_delta 42.5, ecef.x, 1e-10
    assert_raises(NoMethodError) { ecef.x = 99.9 }
  end

  def test_y_reader
    ecef = ECEF.new(y: 42.5)
    assert_in_delta 42.5, ecef.y, 1e-10
    assert_raises(NoMethodError) { ecef.y = 99.9 }
  end

  def test_z_reader
    ecef = ECEF.new(z: 42.5)
    assert_in_delta 42.5, ecef.z, 1e-10
    assert_raises(NoMethodError) { ecef.z = 99.9 }
  end

  # --- to_s ---

  def test_to_s
    ecef = ECEF.new(x: 1.5, y: 2.5, z: 3.5)
    assert_equal "1.5, 2.5, 3.5", ecef.to_s
  end

  # --- to_a ---

  def test_to_a
    ecef = ECEF.new(x: 1.5, y: 2.5, z: 3.5)
    assert_equal [1.5, 2.5, 3.5], ecef.to_a
  end

  # --- from_array ---

  def test_from_array_roundtrip
    original = ECEF.new(x: 100.0, y: 200.0, z: 300.0)
    arr = original.to_a
    restored = ECEF.from_array(arr)
    assert_equal original, restored
  end

  # --- from_string ---

  def test_from_string_roundtrip
    original = ECEF.new(x: 100.0, y: 200.0, z: 300.0)
    str = original.to_s
    restored = ECEF.from_string(str)
    assert_equal original, restored
  end

  # --- == ---

  def test_equality_equal
    a = ECEF.new(x: 1.0, y: 2.0, z: 3.0)
    b = ECEF.new(x: 1.0, y: 2.0, z: 3.0)
    assert_equal a, b
  end

  def test_equality_unequal
    a = ECEF.new(x: 1.0, y: 2.0, z: 3.0)
    b = ECEF.new(x: 10.0, y: 20.0, z: 30.0)
    refute_equal a, b
  end

  def test_equality_non_ecef
    a = ECEF.new(x: 1.0, y: 2.0, z: 3.0)
    refute_equal a, "not an ecef"
  end

  # --- to_lla roundtrip ---

  def test_to_lla_roundtrip
    ecef = SEATTLE_ECEF
    lla = ecef.to_lla
    assert_in_delta 47.6205, lla.lat, 1e-4
    assert_in_delta(-122.3493, lla.lng, 1e-4)
    assert_in_delta 184.0, lla.alt, 1.0

    ecef2 = lla.to_ecef
    assert_in_delta ecef.x, ecef2.x, 0.01
    assert_in_delta ecef.y, ecef2.y, 0.01
    assert_in_delta ecef.z, ecef2.z, 0.01
  end

  # --- to_utm roundtrip ---

  def test_to_utm_roundtrip
    ecef = SEATTLE_ECEF
    utm = ecef.to_utm

    assert_instance_of UTM, utm
    # Seattle should be in UTM zone 10N
    assert_equal 10, utm.zone
    assert_equal "N", utm.hemisphere
    assert utm.easting > 0
    assert utm.northing >= 0

    # Verify ECEF -> UTM matches LLA -> UTM (same code path)
    utm_via_lla = SEATTLE_LLA.to_utm
    assert_in_delta utm_via_lla.easting, utm.easting, 0.01
    assert_in_delta utm_via_lla.northing, utm.northing, 0.01
    assert_equal utm_via_lla.zone, utm.zone
  end

  # --- to_enu / to_ned ---

  def test_to_enu_with_reference
    ref_ecef = SEATTLE_ECEF
    # Create a point slightly offset
    target_ecef = ECEF.new(x: ref_ecef.x + 100.0, y: ref_ecef.y + 100.0, z: ref_ecef.z + 100.0)
    enu = target_ecef.to_enu(ref_ecef)

    assert_instance_of ENU, enu
    # The ENU offset should be non-zero
    refute_in_delta 0.0, enu.e, 1e-3
  end

  def test_to_ned_with_reference
    ref_ecef = SEATTLE_ECEF
    target_ecef = ECEF.new(x: ref_ecef.x + 100.0, y: ref_ecef.y + 100.0, z: ref_ecef.z + 100.0)
    ned = target_ecef.to_ned(ref_ecef)

    assert_instance_of NED, ned
    # NED north should equal ENU north, NED east should equal ENU east
    enu = target_ecef.to_enu(ref_ecef)
    assert_in_delta enu.n, ned.n, 1e-6
    assert_in_delta enu.e, ned.e, 1e-6
    assert_in_delta(-enu.u, ned.d, 1e-6)
  end

  # --- distance_to ---

  def test_distance_to_known_points
    # Two identical ECEF points should have distance 0.0
    a = SEATTLE_ECEF
    assert_in_delta 0.0, a.distance_to(a), 1e-6

    # Two different ECEF points should return a positive Float (Vincenty via LLA)
    b = LLA.new(lat: 37.7749, lng: -122.4194, alt: 0.0).to_ecef
    dist = a.distance_to(b)
    assert_instance_of Geodetic::Distance, dist
    assert dist > 0.0, "Expected positive distance between different points"
  end

  def test_distance_to_raises_for_non_coordinate
    a = ECEF.new
    assert_raises(NoMethodError) { a.distance_to("not ecef") }
  end
end
