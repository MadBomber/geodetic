# frozen_string_literal: true

require "test_helper"
require_relative "../lib/geodetic/coordinate/ned"
require_relative "../lib/geodetic/coordinate/enu"
require_relative "../lib/geodetic/coordinate/lla"
require_relative "../lib/geodetic/coordinate/ecef"

class NedTest < Minitest::Test
  NED   = Geodetic::Coordinate::NED
  ENU   = Geodetic::Coordinate::ENU
  LLA   = Geodetic::Coordinate::LLA
  ECEF  = Geodetic::Coordinate::ECEF
  UTM   = Geodetic::Coordinate::UTM
  MGRS  = Geodetic::Coordinate::MGRS
  USNG  = Geodetic::Coordinate::USNG
  WM    = Geodetic::Coordinate::WebMercator
  UPS_C = Geodetic::Coordinate::UPS
  SP    = Geodetic::Coordinate::StatePlane
  BNG   = Geodetic::Coordinate::BNG
  GH36  = Geodetic::Coordinate::GH36

  # 1. Constructor

  def test_default_constructor
    ned = NED.new
    assert_in_delta 0.0, ned.n, 1e-10
    assert_in_delta 0.0, ned.e, 1e-10
    assert_in_delta 0.0, ned.d, 1e-10
  end

  def test_keyword_args_constructor
    ned = NED.new(n: 100.0, e: 200.0, d: 300.0)
    assert_in_delta 100.0, ned.n, 1e-10
    assert_in_delta 200.0, ned.e, 1e-10
    assert_in_delta 300.0, ned.d, 1e-10
  end

  # 2. Accessors and aliases

  def test_north_alias
    ned = NED.new(n: 42.5, e: 0.0, d: 0.0)
    assert_in_delta 42.5, ned.north, 1e-10
  end

  def test_east_alias
    ned = NED.new(n: 0.0, e: 55.3, d: 0.0)
    assert_in_delta 55.3, ned.east, 1e-10
  end

  def test_down_alias
    ned = NED.new(n: 0.0, e: 0.0, d: 77.7)
    assert_in_delta 77.7, ned.down, 1e-10
  end

  # Setters

  def test_n_setter
    ned = NED.new(n: 100.0)
    ned.n = 200.0
    assert_in_delta 200.0, ned.n, 1e-10
  end

  def test_e_setter
    ned = NED.new(e: 100.0)
    ned.e = 200.0
    assert_in_delta 200.0, ned.e, 1e-10
  end

  def test_d_setter
    ned = NED.new(d: 100.0)
    ned.d = 200.0
    assert_in_delta 200.0, ned.d, 1e-10
  end

  def test_setter_aliases
    ned = NED.new
    ned.north = 10.0
    ned.east = 20.0
    ned.down = 30.0
    assert_in_delta 10.0, ned.n, 1e-10
    assert_in_delta 20.0, ned.e, 1e-10
    assert_in_delta 30.0, ned.d, 1e-10
  end

  def test_setters_coerce_to_float
    ned = NED.new
    ned.n = "123.45"
    ned.e = "678.90"
    ned.d = "111.22"
    assert_in_delta 123.45, ned.n, 1e-10
    assert_in_delta 678.90, ned.e, 1e-10
    assert_in_delta 111.22, ned.d, 1e-10
  end

  # 3. to_s, to_a, from_array, from_string roundtrips

  def test_to_s
    ned = NED.new(n: 1.5, e: 2.5, d: 3.5)
    assert_equal "1.50, 2.50, 3.50", ned.to_s
  end

  def test_to_s_with_precision
    ned = NED.new(n: 100.123, e: 200.456, d: 50.789)
    assert_equal "100.1, 200.5, 50.8", ned.to_s(1)
    assert_equal "100, 200, 51", ned.to_s(0)
  end

  def test_to_a
    ned = NED.new(n: 1.5, e: 2.5, d: 3.5)
    assert_equal [1.5, 2.5, 3.5], ned.to_a
  end

  def test_from_array_roundtrip
    original = NED.new(n: 10.1, e: 20.2, d: 30.3)
    restored = NED.from_array(original.to_a)
    assert_in_delta original.n, restored.n, 1e-10
    assert_in_delta original.e, restored.e, 1e-10
    assert_in_delta original.d, restored.d, 1e-10
  end

  def test_from_string_roundtrip
    original = NED.new(n: 10.1, e: 20.2, d: 30.3)
    restored = NED.from_string(original.to_s)
    assert_in_delta original.n, restored.n, 1e-10
    assert_in_delta original.e, restored.e, 1e-10
    assert_in_delta original.d, restored.d, 1e-10
  end

  # 4. Equality

  def test_equal_ned
    a = NED.new(n: 1.0, e: 2.0, d: 3.0)
    b = NED.new(n: 1.0, e: 2.0, d: 3.0)
    assert_equal a, b
  end

  def test_unequal_ned
    a = NED.new(n: 1.0, e: 2.0, d: 3.0)
    b = NED.new(n: 1.0, e: 2.0, d: 999.0)
    refute_equal a, b
  end

  def test_not_equal_to_non_ned
    ned = NED.new(n: 1.0, e: 2.0, d: 3.0)
    refute_equal ned, "not a NED"
  end

  # 5. to_enu

  def test_to_enu
    ned = NED.new(n: 200.0, e: 100.0, d: -300.0)
    enu = ned.to_enu
    assert_in_delta 100.0, enu.e, 1e-10
    assert_in_delta 200.0, enu.n, 1e-10
    assert_in_delta 300.0, enu.u, 1e-10
  end

  # 6. to_enu / from_enu roundtrip

  def test_to_enu_from_enu_roundtrip
    original = NED.new(n: 50.0, e: 75.0, d: 120.0)
    enu = original.to_enu
    restored = NED.from_enu(enu)
    assert_in_delta original.n, restored.n, 1e-10
    assert_in_delta original.e, restored.e, 1e-10
    assert_in_delta original.d, restored.d, 1e-10
  end

  # 7. to_lla roundtrip with reference LLA

  def test_to_lla_roundtrip
    ref_lla = LLA.new(lat: 37.7749, lng: -122.4194, alt: 10.0)
    original_ned = NED.new(n: 200.0, e: 100.0, d: -50.0)

    lla = original_ned.to_lla(ref_lla)
    restored_ned = NED.from_lla(lla, ref_lla)

    assert_in_delta original_ned.n, restored_ned.n, 0.01
    assert_in_delta original_ned.e, restored_ned.e, 0.01
    assert_in_delta original_ned.d, restored_ned.d, 0.01
  end

  # 8. distance_to

  def test_distance_to
    a = NED.new(n: 0.0, e: 0.0, d: 0.0)
    b = NED.new(n: 3.0, e: 4.0, d: 0.0)
    # NED is a relative coordinate system and cannot convert to LLA without a reference
    assert_raises(ArgumentError) { a.distance_to(b) }
  end

  # 9. horizontal_distance_to

  def test_horizontal_distance_to
    a = NED.new(n: 0.0, e: 0.0, d: 0.0)
    b = NED.new(n: 3.0, e: 4.0, d: 999.0)
    assert_in_delta 5.0, a.horizontal_distance_to(b), 1e-10
  end

  # 10. local_bearing_to

  def test_local_bearing_to_due_east
    a = NED.new(n: 0.0, e: 0.0, d: 0.0)
    b = NED.new(n: 0.0, e: 100.0, d: 0.0)
    assert_in_delta 90.0, a.local_bearing_to(b), 1e-10
  end

  def test_local_bearing_to_due_north
    a = NED.new(n: 0.0, e: 0.0, d: 0.0)
    b = NED.new(n: 100.0, e: 0.0, d: 0.0)
    assert_in_delta 0.0, a.local_bearing_to(b), 1e-10
  end

  def test_local_bearing_to_due_south
    a = NED.new(n: 0.0, e: 0.0, d: 0.0)
    b = NED.new(n: -100.0, e: 0.0, d: 0.0)
    assert_in_delta 180.0, a.local_bearing_to(b), 1e-10
  end

  def test_local_bearing_to_due_west
    a = NED.new(n: 0.0, e: 0.0, d: 0.0)
    b = NED.new(n: 0.0, e: -100.0, d: 0.0)
    assert_in_delta 270.0, a.local_bearing_to(b), 1e-10
  end

  # 11. local_elevation_angle_to

  def test_local_elevation_angle_to_above
    a = NED.new(n: 0.0, e: 0.0, d: 0.0)
    b = NED.new(n: 100.0, e: 0.0, d: -100.0)
    assert_in_delta 45.0, a.local_elevation_angle_to(b), 1e-10
  end

  def test_local_elevation_angle_to_below
    a = NED.new(n: 0.0, e: 0.0, d: 0.0)
    b = NED.new(n: 100.0, e: 0.0, d: 100.0)
    assert_in_delta(-45.0, a.local_elevation_angle_to(b), 1e-10)
  end

  def test_local_elevation_angle_to_same_altitude
    a = NED.new(n: 0.0, e: 0.0, d: 50.0)
    b = NED.new(n: 100.0, e: 0.0, d: 50.0)
    assert_in_delta 0.0, a.local_elevation_angle_to(b), 1e-10
  end

  # 12. distance_to_origin, elevation_angle, bearing_from_origin, horizontal_distance_to_origin

  def test_distance_to_origin
    ned = NED.new(n: 3.0, e: 4.0, d: 0.0)
    assert_in_delta 5.0, ned.distance_to_origin, 1e-10
  end

  def test_elevation_angle
    ned = NED.new(n: 100.0, e: 0.0, d: -100.0)
    # atan2(-(-100), 100) = atan2(100, 100) = 45 degrees
    assert_in_delta 45.0, ned.elevation_angle, 1e-10
  end

  def test_elevation_angle_downward
    ned = NED.new(n: 100.0, e: 0.0, d: 100.0)
    # atan2(-100, 100) = -45 degrees
    assert_in_delta(-45.0, ned.elevation_angle, 1e-10)
  end

  def test_bearing_from_origin
    ned = NED.new(n: 0.0, e: 100.0, d: 0.0)
    assert_in_delta 90.0, ned.bearing_from_origin, 1e-10

    ned2 = NED.new(n: 100.0, e: 0.0, d: 0.0)
    assert_in_delta 0.0, ned2.bearing_from_origin, 1e-10
  end

  def test_horizontal_distance_to_origin
    ned = NED.new(n: 3.0, e: 4.0, d: 999.0)
    assert_in_delta 5.0, ned.horizontal_distance_to_origin, 1e-10
  end

  # --- Cross-system conversions ---

  def test_to_utm
    ref = LLA.new(lat: 47.0, lng: -122.0, alt: 0.0)
    ned = NED.new(n: 200.0, e: 100.0, d: -50.0)
    utm = ned.to_utm(ref)
    assert_instance_of UTM, utm
  end

  def test_from_utm_roundtrip
    ref = LLA.new(lat: 47.0, lng: -122.0, alt: 0.0)
    ned = NED.new(n: 200.0, e: 100.0, d: -50.0)
    utm = ned.to_utm(ref)
    restored = NED.from_utm(utm, ref)
    assert_instance_of NED, restored
    lla_orig = ned.to_lla(ref)
    lla_rest = restored.to_lla(ref)
    assert_in_delta lla_orig.lat, lla_rest.lat, 1.0
    assert_in_delta lla_orig.lng, lla_rest.lng, 1.0
  end

  def test_to_mgrs
    ref = LLA.new(lat: 47.0, lng: -122.0, alt: 0.0)
    ned = NED.new(n: 200.0, e: 100.0, d: -50.0)
    mgrs = ned.to_mgrs(ref)
    assert_instance_of MGRS, mgrs
  end

  def test_from_mgrs_roundtrip
    ref = LLA.new(lat: 47.0, lng: -122.0, alt: 0.0)
    ned = NED.new(n: 200.0, e: 100.0, d: -50.0)
    mgrs = ned.to_mgrs(ref)
    restored = NED.from_mgrs(mgrs, ref)
    assert_instance_of NED, restored
    lla_orig = ned.to_lla(ref)
    lla_rest = restored.to_lla(ref)
    assert_in_delta lla_orig.lat, lla_rest.lat, 1.0
    assert_in_delta lla_orig.lng, lla_rest.lng, 1.0
  end

  def test_to_usng
    ref = LLA.new(lat: 47.0, lng: -122.0, alt: 0.0)
    ned = NED.new(n: 200.0, e: 100.0, d: -50.0)
    usng = ned.to_usng(ref)
    assert_instance_of USNG, usng
  end

  def test_from_usng_roundtrip
    ref = LLA.new(lat: 47.0, lng: -122.0, alt: 0.0)
    ned = NED.new(n: 200.0, e: 100.0, d: -50.0)
    usng = ned.to_usng(ref)
    restored = NED.from_usng(usng, ref)
    assert_instance_of NED, restored
    lla_orig = ned.to_lla(ref)
    lla_rest = restored.to_lla(ref)
    assert_in_delta lla_orig.lat, lla_rest.lat, 1.0
    assert_in_delta lla_orig.lng, lla_rest.lng, 1.0
  end

  def test_to_web_mercator
    ref = LLA.new(lat: 47.0, lng: -122.0, alt: 0.0)
    ned = NED.new(n: 200.0, e: 100.0, d: -50.0)
    wm = ned.to_web_mercator(ref)
    assert_instance_of WM, wm
  end

  def test_from_web_mercator_roundtrip
    ref = LLA.new(lat: 47.0, lng: -122.0, alt: 0.0)
    ned = NED.new(n: 200.0, e: 100.0, d: -50.0)
    wm = ned.to_web_mercator(ref)
    restored = NED.from_web_mercator(wm, ref)
    assert_instance_of NED, restored
    lla_orig = ned.to_lla(ref)
    lla_rest = restored.to_lla(ref)
    assert_in_delta lla_orig.lat, lla_rest.lat, 1.0
    assert_in_delta lla_orig.lng, lla_rest.lng, 1.0
  end

  def test_to_ups
    ref = LLA.new(lat: 47.0, lng: -122.0, alt: 0.0)
    ned = NED.new(n: 200.0, e: 100.0, d: -50.0)
    ups = ned.to_ups(ref)
    assert_instance_of UPS_C, ups
  end

  def test_from_ups_roundtrip
    ref = LLA.new(lat: 47.0, lng: -122.0, alt: 0.0)
    ned = NED.new(n: 200.0, e: 100.0, d: -50.0)
    ups = ned.to_ups(ref)
    restored = NED.from_ups(ups, ref)
    assert_instance_of NED, restored
  end

  def test_to_state_plane
    ref = LLA.new(lat: 47.0, lng: -122.0, alt: 0.0)
    ned = NED.new(n: 200.0, e: 100.0, d: -50.0)
    sp = ned.to_state_plane(ref, "CA_I")
    assert_instance_of SP, sp
  end

  def test_from_state_plane_roundtrip
    ref = LLA.new(lat: 47.0, lng: -122.0, alt: 0.0)
    ned = NED.new(n: 200.0, e: 100.0, d: -50.0)
    sp = ned.to_state_plane(ref, "CA_I")
    restored = NED.from_state_plane(sp, ref)
    assert_instance_of NED, restored
  end

  def test_to_bng
    ref = LLA.new(lat: 47.0, lng: -122.0, alt: 0.0)
    ned = NED.new(n: 200.0, e: 100.0, d: -50.0)
    bng = ned.to_bng(ref)
    assert_instance_of BNG, bng
  end

  def test_from_bng_roundtrip
    ref = LLA.new(lat: 47.0, lng: -122.0, alt: 0.0)
    ned = NED.new(n: 200.0, e: 100.0, d: -50.0)
    bng = ned.to_bng(ref)
    restored = NED.from_bng(bng, ref)
    assert_instance_of NED, restored
    lla_orig = ned.to_lla(ref)
    lla_rest = restored.to_lla(ref)
    assert_in_delta lla_orig.lat, lla_rest.lat, 1.0
    assert_in_delta lla_orig.lng, lla_rest.lng, 1.0
  end

  def test_to_gh36
    ref = LLA.new(lat: 47.0, lng: -122.0, alt: 0.0)
    ned = NED.new(n: 200.0, e: 100.0, d: -50.0)
    gh36 = ned.to_gh36(ref)
    assert_instance_of GH36, gh36
  end

  def test_from_gh36_roundtrip
    ref = LLA.new(lat: 47.0, lng: -122.0, alt: 0.0)
    ned = NED.new(n: 200.0, e: 100.0, d: -50.0)
    gh36 = ned.to_gh36(ref)
    restored = NED.from_gh36(gh36, ref)
    assert_instance_of NED, restored
    lla_orig = ned.to_lla(ref)
    lla_rest = restored.to_lla(ref)
    assert_in_delta lla_orig.lat, lla_rest.lat, 1.0
    assert_in_delta lla_orig.lng, lla_rest.lng, 1.0
  end

  # ── NED <-> ECEF conversions ────────────────────────────────

  def test_to_ecef_from_ned
    ref_ecef = LLA.new(lat: 40.0, lng: -74.0, alt: 0.0).to_ecef
    ned = NED.new(n: 100.0, e: 200.0, d: -50.0)
    result = ned.to_ecef(ref_ecef)
    assert_instance_of ECEF, result
  end

  def test_from_ecef_class_method
    ref_ecef = LLA.new(lat: 40.0, lng: -74.0, alt: 0.0).to_ecef
    target_ecef = LLA.new(lat: 40.001, lng: -74.001, alt: 0.0).to_ecef
    ned = NED.from_ecef(target_ecef, ref_ecef)
    assert_instance_of NED, ned
  end

  def test_ned_ecef_roundtrip
    ref_ecef = LLA.new(lat: 40.0, lng: -74.0, alt: 0.0).to_ecef
    ned = NED.new(n: 100.0, e: 200.0, d: -50.0)
    ecef = ned.to_ecef(ref_ecef)
    restored = NED.from_ecef(ecef, ref_ecef)
    assert_in_delta ned.n, restored.n, 1e-3
    assert_in_delta ned.e, restored.e, 1e-3
    assert_in_delta ned.d, restored.d, 1e-3
  end
end
