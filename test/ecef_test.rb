# frozen_string_literal: true

require "test_helper"
require_relative "../lib/geodetic/coordinate/ecef"
require_relative "../lib/geodetic/coordinate/lla"
require_relative "../lib/geodetic/coordinate/utm"
require_relative "../lib/geodetic/coordinate/enu"
require_relative "../lib/geodetic/coordinate/ned"
require_relative "../lib/geodetic/coordinate/mgrs"
require_relative "../lib/geodetic/coordinate/usng"
require_relative "../lib/geodetic/coordinate/web_mercator"
require_relative "../lib/geodetic/coordinate/ups"
require_relative "../lib/geodetic/coordinate/state_plane"
require_relative "../lib/geodetic/coordinate/bng"
require_relative "../lib/geodetic/coordinate/gh36"

class EcefTest < Minitest::Test
  ECEF = Geodetic::Coordinate::ECEF
  LLA  = Geodetic::Coordinate::LLA
  UTM  = Geodetic::Coordinate::UTM
  ENU  = Geodetic::Coordinate::ENU
  NED  = Geodetic::Coordinate::NED
  MGRS = Geodetic::Coordinate::MGRS
  USNG = Geodetic::Coordinate::USNG
  WM   = Geodetic::Coordinate::WebMercator
  UPS  = Geodetic::Coordinate::UPS
  SP   = Geodetic::Coordinate::StatePlane
  BNG  = Geodetic::Coordinate::BNG
  GH36 = Geodetic::Coordinate::GH36

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
  end

  def test_y_reader
    ecef = ECEF.new(y: 42.5)
    assert_in_delta 42.5, ecef.y, 1e-10
  end

  def test_z_reader
    ecef = ECEF.new(z: 42.5)
    assert_in_delta 42.5, ecef.z, 1e-10
  end

  # --- Setters ---

  def test_x_setter
    ecef = ECEF.new(x: 42.5)
    ecef.x = 99.9
    assert_in_delta 99.9, ecef.x, 1e-10
  end

  def test_y_setter
    ecef = ECEF.new(y: 42.5)
    ecef.y = 99.9
    assert_in_delta 99.9, ecef.y, 1e-10
  end

  def test_z_setter
    ecef = ECEF.new(z: 42.5)
    ecef.z = 99.9
    assert_in_delta 99.9, ecef.z, 1e-10
  end

  def test_setters_coerce_to_float
    ecef = ECEF.new
    ecef.x = "123.45"
    ecef.y = "678.90"
    ecef.z = "111.22"
    assert_in_delta 123.45, ecef.x, 1e-10
    assert_in_delta 678.90, ecef.y, 1e-10
    assert_in_delta 111.22, ecef.z, 1e-10
  end

  # --- to_s ---

  def test_to_s
    ecef = ECEF.new(x: 1.5, y: 2.5, z: 3.5)
    assert_equal "1.50, 2.50, 3.50", ecef.to_s
  end

  def test_to_s_with_precision
    ecef = ECEF.new(x: 1234.5678, y: 2345.6789, z: 3456.7890)
    assert_equal "1234.568, 2345.679, 3456.789", ecef.to_s(3)
    assert_equal "1235, 2346, 3457", ecef.to_s(0)
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

  # --- from_lla class method ---

  def test_from_lla_class_method
    lla = LLA.new(lat: 47.6205, lng: -122.3493, alt: 184.0)
    ecef = ECEF.from_lla(lla)
    assert_instance_of ECEF, ecef
    # Roundtrip back to LLA
    lla2 = ecef.to_lla
    assert_in_delta 47.6205, lla2.lat, 0.1
    assert_in_delta(-122.3493, lla2.lng, 0.1)
  end

  # --- to_mgrs / from_mgrs ---

  def test_to_mgrs
    mgrs = SEATTLE_ECEF.to_mgrs
    assert_instance_of MGRS, mgrs
    # Roundtrip via LLA
    lla = mgrs.to_lla
    assert_in_delta 47.6205, lla.lat, 1.0
    assert_in_delta(-122.3493, lla.lng, 1.0)
  end

  def test_from_mgrs
    mgrs = SEATTLE_ECEF.to_mgrs
    ecef = ECEF.from_mgrs(mgrs)
    assert_instance_of ECEF, ecef
    lla = ecef.to_lla
    assert_in_delta 47.6205, lla.lat, 1.0
    assert_in_delta(-122.3493, lla.lng, 1.0)
  end

  # --- to_usng / from_usng ---

  def test_to_usng
    usng = SEATTLE_ECEF.to_usng
    assert_instance_of USNG, usng
    lla = usng.to_lla
    assert_in_delta 47.6205, lla.lat, 1.0
    assert_in_delta(-122.3493, lla.lng, 1.0)
  end

  def test_from_usng
    usng = SEATTLE_ECEF.to_usng
    ecef = ECEF.from_usng(usng)
    assert_instance_of ECEF, ecef
    lla = ecef.to_lla
    assert_in_delta 47.6205, lla.lat, 1.0
    assert_in_delta(-122.3493, lla.lng, 1.0)
  end

  # --- to_web_mercator / from_web_mercator ---

  def test_to_web_mercator
    wm = SEATTLE_ECEF.to_web_mercator
    assert_instance_of WM, wm
    lla = wm.to_lla
    assert_in_delta 47.6205, lla.lat, 0.1
    assert_in_delta(-122.3493, lla.lng, 0.1)
  end

  def test_from_web_mercator
    wm = SEATTLE_ECEF.to_web_mercator
    ecef = ECEF.from_web_mercator(wm)
    assert_instance_of ECEF, ecef
    lla = ecef.to_lla
    assert_in_delta 47.6205, lla.lat, 0.1
    assert_in_delta(-122.3493, lla.lng, 0.1)
  end

  # --- to_ups / from_ups (high-latitude point) ---

  def test_to_ups
    # North pole area: lat 89, lng 0
    polar_lla = LLA.new(lat: 89.0, lng: 0.0, alt: 0.0)
    polar_ecef = polar_lla.to_ecef
    ups = polar_ecef.to_ups
    assert_instance_of UPS, ups
    assert_equal "N", ups.hemisphere
    # UPS is designed for polar regions; verify type and hemisphere
    lla = ups.to_lla
    assert_in_delta 0.0, lla.lng, 0.1
    assert lla.lat > 84.0, "Expected polar latitude from UPS roundtrip"
  end

  def test_from_ups
    polar_lla = LLA.new(lat: 89.0, lng: 0.0, alt: 0.0)
    polar_ecef = polar_lla.to_ecef
    ups = polar_ecef.to_ups
    ecef = ECEF.from_ups(ups)
    assert_instance_of ECEF, ecef
    lla = ecef.to_lla
    assert_in_delta 0.0, lla.lng, 0.1
    assert lla.lat > 84.0, "Expected polar latitude from UPS roundtrip"
  end

  # --- to_state_plane / from_state_plane ---

  def test_to_state_plane
    # Use a point in Northern California for CA_I zone
    ca_lla = LLA.new(lat: 40.5, lng: -122.0, alt: 0.0)
    ca_ecef = ca_lla.to_ecef
    sp = ca_ecef.to_state_plane("CA_I")
    assert_instance_of SP, sp
    assert_equal "CA_I", sp.zone_code
    assert sp.easting > 0, "Expected positive easting"
    assert sp.northing > 0, "Expected positive northing"
  end

  def test_from_state_plane
    ca_lla = LLA.new(lat: 40.5, lng: -122.0, alt: 0.0)
    ca_ecef = ca_lla.to_ecef
    sp = ca_ecef.to_state_plane("CA_I")
    ecef = ECEF.from_state_plane(sp)
    assert_instance_of ECEF, ecef
    # Verify we get a valid ECEF back (non-zero magnitude)
    magnitude = Math.sqrt(ecef.x**2 + ecef.y**2 + ecef.z**2)
    assert magnitude > 6_000_000, "Expected Earth-radius-scale ECEF magnitude"
  end

  # --- to_bng / from_bng (UK point) ---

  def test_to_bng
    uk_lla = LLA.new(lat: 51.5, lng: -0.1, alt: 0.0)
    uk_ecef = uk_lla.to_ecef
    bng = uk_ecef.to_bng
    assert_instance_of BNG, bng
    lla = bng.to_lla
    assert_in_delta 51.5, lla.lat, 1.0
    assert_in_delta(-0.1, lla.lng, 1.0)
  end

  def test_from_bng
    uk_lla = LLA.new(lat: 51.5, lng: -0.1, alt: 0.0)
    uk_ecef = uk_lla.to_ecef
    bng = uk_ecef.to_bng
    ecef = ECEF.from_bng(bng)
    assert_instance_of ECEF, ecef
    lla = ecef.to_lla
    assert_in_delta 51.5, lla.lat, 1.0
    assert_in_delta(-0.1, lla.lng, 1.0)
  end

  # --- to_gh36 / from_gh36 ---

  def test_to_gh36
    gh36 = SEATTLE_ECEF.to_gh36
    assert_instance_of GH36, gh36
    lla = gh36.to_lla
    assert_in_delta 47.6205, lla.lat, 0.1
    assert_in_delta(-122.3493, lla.lng, 0.1)
  end

  def test_from_gh36
    gh36 = SEATTLE_ECEF.to_gh36
    ecef = ECEF.from_gh36(gh36)
    assert_instance_of ECEF, ecef
    lla = ecef.to_lla
    assert_in_delta 47.6205, lla.lat, 0.1
    assert_in_delta(-122.3493, lla.lng, 0.1)
  end

  # --- Pole singularity ---

  def test_pole_singularity_north
    # ECEF at approximate north pole (x:0, y:0, z: semi-minor axis)
    north_pole_ecef = ECEF.new(x: 0.0, y: 0.0, z: 6356752.0)
    lla = north_pole_ecef.to_lla
    assert_in_delta 90.0, lla.lat, 0.1
  end

  def test_pole_singularity_south
    south_pole_ecef = ECEF.new(x: 0.0, y: 0.0, z: -6356752.0)
    lla = south_pole_ecef.to_lla
    assert_in_delta(-90.0, lla.lat, 0.1)
  end

  # ── ECEF-native ENU/NED conversions ────────────────────────

  def test_from_enu_class_method
    ref_ecef = LLA.new(lat: 40.0, lng: -74.0, alt: 0.0).to_ecef
    enu = ref_ecef.to_enu(ref_ecef)
    result = ECEF.from_enu(enu, ref_ecef)
    assert_instance_of ECEF, result
  end

  def test_to_ned_via_ecef
    ref_ecef = LLA.new(lat: 40.0, lng: -74.0, alt: 0.0).to_ecef
    target_ecef = LLA.new(lat: 40.001, lng: -74.001, alt: 0.0).to_ecef
    ned = target_ecef.to_ned(ref_ecef)
    assert_instance_of NED, ned
  end

  def test_from_ned_class_method
    ref_ecef = LLA.new(lat: 40.0, lng: -74.0, alt: 0.0).to_ecef
    target_ecef = LLA.new(lat: 40.001, lng: -74.001, alt: 0.0).to_ecef
    ned = target_ecef.to_ned(ref_ecef)
    result = ECEF.from_ned(ned, ref_ecef)
    assert_instance_of ECEF, result
  end

  def test_from_utm_class_method
    utm = UTM.new(easting: 583960.0, northing: 4507351.0, zone: 18, hemisphere: 'N')
    result = ECEF.from_utm(utm)
    assert_instance_of ECEF, result
  end
end
