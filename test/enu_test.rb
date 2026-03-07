# frozen_string_literal: true

require "test_helper"
require_relative "../lib/geodetic/coordinates/enu"
require_relative "../lib/geodetic/coordinates/ned"
require_relative "../lib/geodetic/coordinates/lla"
require_relative "../lib/geodetic/coordinates/ecef"

class EnuTest < Minitest::Test
  ENU  = Geodetic::Coordinates::ENU
  NED  = Geodetic::Coordinates::NED
  LLA  = Geodetic::Coordinates::LLA
  ECEF = Geodetic::Coordinates::ECEF

  # 1. Constructor

  def test_default_constructor
    enu = ENU.new
    assert_in_delta 0.0, enu.e, 1e-10
    assert_in_delta 0.0, enu.n, 1e-10
    assert_in_delta 0.0, enu.u, 1e-10
  end

  def test_keyword_args_constructor
    enu = ENU.new(e: 100.0, n: 200.0, u: 300.0)
    assert_in_delta 100.0, enu.e, 1e-10
    assert_in_delta 200.0, enu.n, 1e-10
    assert_in_delta 300.0, enu.u, 1e-10
  end

  # 2. Accessors and aliases

  def test_east_alias
    enu = ENU.new(e: 42.5, n: 0.0, u: 0.0)
    assert_in_delta 42.5, enu.east, 1e-10
  end

  def test_north_alias
    enu = ENU.new(e: 0.0, n: 55.3, u: 0.0)
    assert_in_delta 55.3, enu.north, 1e-10
  end

  def test_up_alias
    enu = ENU.new(e: 0.0, n: 0.0, u: 77.7)
    assert_in_delta 77.7, enu.up, 1e-10
  end

  # 3. to_s, to_a, from_array, from_string roundtrips

  def test_to_s
    enu = ENU.new(e: 1.5, n: 2.5, u: 3.5)
    assert_equal "1.5, 2.5, 3.5", enu.to_s
  end

  def test_to_a
    enu = ENU.new(e: 1.5, n: 2.5, u: 3.5)
    assert_equal [1.5, 2.5, 3.5], enu.to_a
  end

  def test_from_array_roundtrip
    original = ENU.new(e: 10.1, n: 20.2, u: 30.3)
    restored = ENU.from_array(original.to_a)
    assert_in_delta original.e, restored.e, 1e-10
    assert_in_delta original.n, restored.n, 1e-10
    assert_in_delta original.u, restored.u, 1e-10
  end

  def test_from_string_roundtrip
    original = ENU.new(e: 10.1, n: 20.2, u: 30.3)
    restored = ENU.from_string(original.to_s)
    assert_in_delta original.e, restored.e, 1e-10
    assert_in_delta original.n, restored.n, 1e-10
    assert_in_delta original.u, restored.u, 1e-10
  end

  # 4. Equality

  def test_equal_enu
    a = ENU.new(e: 1.0, n: 2.0, u: 3.0)
    b = ENU.new(e: 1.0, n: 2.0, u: 3.0)
    assert_equal a, b
  end

  def test_unequal_enu
    a = ENU.new(e: 1.0, n: 2.0, u: 3.0)
    b = ENU.new(e: 1.0, n: 2.0, u: 999.0)
    refute_equal a, b
  end

  def test_not_equal_to_non_enu
    enu = ENU.new(e: 1.0, n: 2.0, u: 3.0)
    refute_equal enu, "not an ENU"
  end

  # 5. to_ned

  def test_to_ned
    enu = ENU.new(e: 100.0, n: 200.0, u: 300.0)
    ned = enu.to_ned
    assert_in_delta 200.0, ned.n, 1e-10
    assert_in_delta 100.0, ned.e, 1e-10
    assert_in_delta(-300.0, ned.d, 1e-10)
  end

  # 6. to_ned / from_ned roundtrip

  def test_to_ned_from_ned_roundtrip
    original = ENU.new(e: 50.0, n: 75.0, u: 120.0)
    ned = original.to_ned
    restored = ENU.from_ned(ned)
    assert_in_delta original.e, restored.e, 1e-10
    assert_in_delta original.n, restored.n, 1e-10
    assert_in_delta original.u, restored.u, 1e-10
  end

  # 7. to_lla roundtrip with reference LLA

  def test_to_lla_roundtrip
    ref_lla = LLA.new(lat: 37.7749, lng: -122.4194, alt: 10.0)
    original_enu = ENU.new(e: 100.0, n: 200.0, u: 50.0)

    lla = original_enu.to_lla(ref_lla)
    restored_enu = ENU.from_lla(lla, ref_lla)

    assert_in_delta original_enu.e, restored_enu.e, 0.01
    assert_in_delta original_enu.n, restored_enu.n, 0.01
    assert_in_delta original_enu.u, restored_enu.u, 0.01
  end

  # 8. to_ecef roundtrip with reference ECEF and LLA

  def test_to_ecef_roundtrip
    ref_lla  = LLA.new(lat: 37.7749, lng: -122.4194, alt: 10.0)
    ref_ecef = ref_lla.to_ecef

    original_enu = ENU.new(e: 100.0, n: 200.0, u: 50.0)
    ecef = original_enu.to_ecef(ref_ecef, ref_lla)
    restored_enu = ENU.from_ecef(ecef, ref_ecef, ref_lla)

    assert_in_delta original_enu.e, restored_enu.e, 0.01
    assert_in_delta original_enu.n, restored_enu.n, 0.01
    assert_in_delta original_enu.u, restored_enu.u, 0.01
  end

  # 9. distance_to

  def test_distance_to
    a = ENU.new(e: 0.0, n: 0.0, u: 0.0)
    b = ENU.new(e: 3.0, n: 4.0, u: 0.0)
    # ENU is a relative coordinate system and cannot convert to LLA without a reference
    assert_raises(ArgumentError) { a.distance_to(b) }
  end

  # 10. horizontal_distance_to

  def test_horizontal_distance_to
    a = ENU.new(e: 0.0, n: 0.0, u: 0.0)
    b = ENU.new(e: 3.0, n: 4.0, u: 999.0)
    assert_in_delta 5.0, a.horizontal_distance_to(b), 1e-10
  end

  # 11. local_bearing_to

  def test_local_bearing_to_due_east
    a = ENU.new(e: 0.0, n: 0.0, u: 0.0)
    b = ENU.new(e: 100.0, n: 0.0, u: 0.0)
    assert_in_delta 90.0, a.local_bearing_to(b), 1e-10
  end

  def test_local_bearing_to_due_north
    a = ENU.new(e: 0.0, n: 0.0, u: 0.0)
    b = ENU.new(e: 0.0, n: 100.0, u: 0.0)
    assert_in_delta 0.0, a.local_bearing_to(b), 1e-10
  end

  def test_local_bearing_to_due_south
    a = ENU.new(e: 0.0, n: 0.0, u: 0.0)
    b = ENU.new(e: 0.0, n: -100.0, u: 0.0)
    assert_in_delta 180.0, a.local_bearing_to(b), 1e-10
  end

  def test_local_bearing_to_due_west
    a = ENU.new(e: 0.0, n: 0.0, u: 0.0)
    b = ENU.new(e: -100.0, n: 0.0, u: 0.0)
    assert_in_delta 270.0, a.local_bearing_to(b), 1e-10
  end

  # 12. distance_to_origin, bearing_from_origin, horizontal_distance_to_origin

  def test_distance_to_origin
    enu = ENU.new(e: 3.0, n: 4.0, u: 0.0)
    assert_in_delta 5.0, enu.distance_to_origin, 1e-10
  end

  def test_bearing_from_origin
    enu = ENU.new(e: 100.0, n: 0.0, u: 0.0)
    assert_in_delta 90.0, enu.bearing_from_origin, 1e-10

    enu2 = ENU.new(e: 0.0, n: 100.0, u: 0.0)
    assert_in_delta 0.0, enu2.bearing_from_origin, 1e-10
  end

  def test_horizontal_distance_to_origin
    enu = ENU.new(e: 3.0, n: 4.0, u: 999.0)
    assert_in_delta 5.0, enu.horizontal_distance_to_origin, 1e-10
  end
end
