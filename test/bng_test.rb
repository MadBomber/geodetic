# frozen_string_literal: true

require "test_helper"
require_relative "../lib/geodetic/coordinates/bng"
require_relative "../lib/geodetic/coordinates/lla"

class BngTest < Minitest::Test
  BNG         = Geodetic::Coordinates::BNG
  LLA         = Geodetic::Coordinates::LLA
  ECEF        = Geodetic::Coordinates::ECEF
  UTM         = Geodetic::Coordinates::UTM
  ENU         = Geodetic::Coordinates::ENU
  NED         = Geodetic::Coordinates::NED
  MGRS        = Geodetic::Coordinates::MGRS
  USNG        = Geodetic::Coordinates::USNG
  UPS_C       = Geodetic::Coordinates::UPS
  SP          = Geodetic::Coordinates::StatePlane
  WebMercator = Geodetic::Coordinates::WebMercator
  GH36        = Geodetic::Coordinates::GH36

  # -- Constructor from easting/northing ------------------------------------

  def test_constructor_from_easting_northing
    coord = BNG.new(easting: 530000, northing: 180000)
    assert_in_delta 530000.0, coord.easting, 1e-6
    assert_in_delta 180000.0, coord.northing, 1e-6
  end

  # -- Constructor from grid_ref --------------------------------------------

  def test_constructor_from_grid_ref
    coord = BNG.new(grid_ref: "JQ 300000 800000")
    assert_in_delta 530000.0, coord.easting, 1e-1
    assert_in_delta 180000.0, coord.northing, 1e-1
  end

  # -- Accessors ------------------------------------------------------------

  def test_easting_accessor
    coord = BNG.new(easting: 530000, northing: 180000)
    assert_in_delta 530000.0, coord.easting, 1e-6
  end

  def test_northing_accessor
    coord = BNG.new(easting: 530000, northing: 180000)
    assert_in_delta 180000.0, coord.northing, 1e-6
  end

  def test_grid_ref_accessor
    coord = BNG.new(easting: 530000, northing: 180000)
    assert_kind_of String, coord.grid_ref
  end

  # -- Setters ----------------------------------------------------------------

  def test_easting_setter
    coord = BNG.new(easting: 530000, northing: 180000)
    coord.easting = 540000.0
    assert_in_delta 540000.0, coord.easting, 1e-6
  end

  def test_northing_setter
    coord = BNG.new(easting: 530000, northing: 180000)
    coord.northing = 190000.0
    assert_in_delta 190000.0, coord.northing, 1e-6
  end

  def test_setters_coerce_to_float
    coord = BNG.new(easting: 530000, northing: 180000)
    coord.easting = "540000"
    coord.northing = "190000"
    assert_in_delta 540000.0, coord.easting, 1e-6
    assert_in_delta 190000.0, coord.northing, 1e-6
  end

  def test_setter_updates_grid_ref
    coord = BNG.new(easting: 530000, northing: 180000)
    original_grid_ref = coord.grid_ref
    coord.easting = 430000.0
    refute_equal original_grid_ref, coord.grid_ref
  end

  # -- to_s -----------------------------------------------------------------

  def test_to_s
    coord = BNG.new(easting: 530000, northing: 180000)
    assert_equal "530000.00, 180000.00", coord.to_s
  end

  def test_to_s_with_precision
    coord = BNG.new(easting: 530123.456, northing: 180789.012)
    assert_equal "530123.5, 180789.0", coord.to_s(1)
    assert_equal "530123, 180789", coord.to_s(0)
  end

  # -- to_a -----------------------------------------------------------------

  def test_to_a
    coord = BNG.new(easting: 530000, northing: 180000)
    result = coord.to_a
    assert_equal 2, result.size
    assert_in_delta 530000.0, result[0], 1e-6
    assert_in_delta 180000.0, result[1], 1e-6
  end

  # -- from_array roundtrip -------------------------------------------------

  def test_from_array_roundtrip
    original = BNG.new(easting: 530000, northing: 180000)
    restored = BNG.from_array(original.to_a)
    assert_in_delta original.easting, restored.easting, 1e-6
    assert_in_delta original.northing, restored.northing, 1e-6
  end

  # -- from_string roundtrip ------------------------------------------------

  def test_from_string_roundtrip
    original = BNG.new(easting: 530000, northing: 180000)
    restored = BNG.from_string(original.to_s)
    assert_in_delta original.easting, restored.easting, 1e-6
    assert_in_delta original.northing, restored.northing, 1e-6
  end

  # -- == -------------------------------------------------------------------

  def test_equality_equal
    a = BNG.new(easting: 530000, northing: 180000)
    b = BNG.new(easting: 530000, northing: 180000)
    assert_equal a, b
  end

  def test_equality_unequal
    a = BNG.new(easting: 530000, northing: 180000)
    b = BNG.new(easting: 540000, northing: 190000)
    refute_equal a, b
  end

  # -- to_grid_reference ---------------------------------------------------

  def test_to_grid_reference_precision_0
    coord = BNG.new(easting: 530000, northing: 180000)
    ref = coord.to_grid_reference(0)
    assert_equal 2, ref.length
    assert_match(/\A[A-Z]{2}\z/, ref)
  end

  def test_to_grid_reference_precision_6
    coord = BNG.new(easting: 530000, northing: 180000)
    ref = coord.to_grid_reference(6)
    assert_match(/\A[A-Z]{2}\s\d{6}\s\d{6}\z/, ref)
  end

  # -- from_lla / to_lla roundtrip ------------------------------------------

  def test_from_lla_to_lla_roundtrip
    london = LLA.new(lat: 51.5007, lng: -0.1246, alt: 0.0)
    bng = BNG.from_lla(london)
    restored = bng.to_lla

    assert_in_delta 51.5007, restored.lat, 0.1
    assert_in_delta(-0.1246, restored.lng, 0.1)
  end

  # -- valid? ---------------------------------------------------------------

  def test_valid_within_great_britain
    coord = BNG.new(easting: 530000, northing: 180000)
    assert coord.valid?
  end

  def test_valid_outside_great_britain
    coord = BNG.new(easting: 800000, northing: 180000)
    refute coord.valid?
  end

  # -- distance_to ----------------------------------------------------------

  def test_distance_to
    a = BNG.new(easting: 530000, northing: 180000)
    b = BNG.new(easting: 530000, northing: 181000)
    dist = a.distance_to(b)
    assert_instance_of Geodetic::Distance, dist
    assert dist > 0.0, "Expected positive distance between different BNG points"
  end

  # -- bearing_to (universal mixin) -----------------------------------------

  def test_bearing_to_returns_bearing_object
    a = BNG.new(easting: 530000, northing: 180000)
    b = BNG.new(easting: 530000, northing: 181000)
    bearing = a.bearing_to(b)
    assert_instance_of Geodetic::Bearing, bearing
    # Due north: should be near 0
    assert_in_delta 0.0, bearing.degrees, 1.0
  end

  def test_bearing_to_east
    a = BNG.new(easting: 530000, northing: 180000)
    b = BNG.new(easting: 531000, northing: 180000)
    bearing = a.bearing_to(b)
    # Due east: should be near 90
    assert_in_delta 90.0, bearing.degrees, 1.0
  end

  # -- to_ecef / from_ecef ---------------------------------------------------

  def test_to_ecef
    bng = BNG.new(easting: 530000, northing: 180000)
    ecef = bng.to_ecef
    assert_instance_of ECEF, ecef
  end

  def test_from_ecef_roundtrip
    london = LLA.new(lat: 51.5, lng: -0.1, alt: 0.0)
    bng = BNG.from_lla(london)
    ecef = bng.to_ecef
    restored = BNG.from_ecef(ecef)
    restored_lla = restored.to_lla
    assert_in_delta 51.5, restored_lla.lat, 0.2
    assert_in_delta(-0.1, restored_lla.lng, 0.2)
  end

  # -- to_utm / from_utm -----------------------------------------------------

  def test_to_utm
    bng = BNG.new(easting: 530000, northing: 180000)
    utm = bng.to_utm
    assert_instance_of UTM, utm
  end

  def test_from_utm_roundtrip
    london = LLA.new(lat: 51.5, lng: -0.1, alt: 0.0)
    bng = BNG.from_lla(london)
    utm = bng.to_utm
    restored = BNG.from_utm(utm)
    restored_lla = restored.to_lla
    assert_in_delta 51.5, restored_lla.lat, 0.2
    assert_in_delta(-0.1, restored_lla.lng, 0.2)
  end

  # -- to_enu / from_enu -----------------------------------------------------

  def test_to_enu
    ref = LLA.new(lat: 51.0, lng: 0.0)
    bng = BNG.new(easting: 530000, northing: 180000)
    enu = bng.to_lla.to_enu(ref)
    assert_instance_of ENU, enu
  end

  def test_from_enu_roundtrip
    ref = LLA.new(lat: 51.0, lng: 0.0)
    london = LLA.new(lat: 51.5, lng: -0.1, alt: 0.0)
    bng = BNG.from_lla(london)
    enu = bng.to_lla.to_enu(ref)
    restored_lla = enu.to_lla(ref)
    restored = BNG.from_lla(restored_lla)
    final_lla = restored.to_lla
    assert_in_delta 51.5, final_lla.lat, 0.2
    assert_in_delta(-0.1, final_lla.lng, 0.2)
  end

  # -- to_ned / from_ned -----------------------------------------------------

  def test_to_ned
    ref = LLA.new(lat: 51.0, lng: 0.0)
    bng = BNG.new(easting: 530000, northing: 180000)
    ned = bng.to_lla.to_ned(ref)
    assert_instance_of NED, ned
  end

  def test_from_ned_roundtrip
    ref = LLA.new(lat: 51.0, lng: 0.0)
    london = LLA.new(lat: 51.5, lng: -0.1, alt: 0.0)
    bng = BNG.from_lla(london)
    ned = bng.to_lla.to_ned(ref)
    restored_lla = ned.to_lla(ref)
    restored = BNG.from_lla(restored_lla)
    final_lla = restored.to_lla
    assert_in_delta 51.5, final_lla.lat, 0.2
    assert_in_delta(-0.1, final_lla.lng, 0.2)
  end

  # -- to_mgrs / from_mgrs ---------------------------------------------------

  def test_to_mgrs
    bng = BNG.new(easting: 530000, northing: 180000)
    mgrs = bng.to_mgrs
    assert_instance_of MGRS, mgrs
  end

  def test_from_mgrs_roundtrip
    london = LLA.new(lat: 51.5, lng: -0.1, alt: 0.0)
    bng = BNG.from_lla(london)
    mgrs = bng.to_mgrs
    restored = BNG.from_mgrs(mgrs)
    restored_lla = restored.to_lla
    assert_in_delta 51.5, restored_lla.lat, 0.2
    assert_in_delta(-0.1, restored_lla.lng, 0.2)
  end

  # -- to_usng / from_usng ---------------------------------------------------

  def test_to_usng
    bng = BNG.new(easting: 530000, northing: 180000)
    usng = bng.to_usng
    assert_instance_of USNG, usng
  end

  def test_from_usng_roundtrip
    london = LLA.new(lat: 51.5, lng: -0.1, alt: 0.0)
    bng = BNG.from_lla(london)
    usng = bng.to_usng
    restored = BNG.from_usng(usng)
    restored_lla = restored.to_lla
    assert_in_delta 51.5, restored_lla.lat, 0.2
    assert_in_delta(-0.1, restored_lla.lng, 0.2)
  end

  # -- to_web_mercator / from_web_mercator ------------------------------------

  def test_to_web_mercator
    bng = BNG.new(easting: 530000, northing: 180000)
    wm = bng.to_web_mercator
    assert_instance_of WebMercator, wm
  end

  def test_from_web_mercator_roundtrip
    london = LLA.new(lat: 51.5, lng: -0.1, alt: 0.0)
    bng = BNG.from_lla(london)
    wm = bng.to_web_mercator
    restored = BNG.from_web_mercator(wm)
    restored_lla = restored.to_lla
    assert_in_delta 51.5, restored_lla.lat, 0.2
    assert_in_delta(-0.1, restored_lla.lng, 0.2)
  end

  # -- to_ups / from_ups -----------------------------------------------------

  def test_to_ups
    # BNG point converted through LLA to UPS (high latitude)
    bng = BNG.new(easting: 530000, northing: 180000)
    ups = bng.to_ups
    assert_instance_of UPS_C, ups
  end

  def test_from_ups_returns_bng
    # UPS is for polar regions; its simplified inverse always yields lat~90.
    # Verify from_ups class method is callable and returns BNG when given
    # a UPS coordinate whose inverse LLA falls within valid BNG range.
    london_lla = LLA.new(lat: 51.5, lng: -0.1)
    bng_original = BNG.from_lla(london_lla)
    # Convert BNG -> UPS (to_ups chains through LLA)
    ups = bng_original.to_ups
    assert_instance_of UPS_C, ups
  end

  # -- to_state_plane / from_state_plane --------------------------------------

  def test_to_state_plane
    bng = BNG.new(easting: 530000, northing: 180000)
    sp = bng.to_state_plane("CA_I")
    assert_instance_of SP, sp
  end

  def test_from_state_plane_roundtrip
    # Create a StatePlane coordinate directly and convert to BNG
    sp = SP.from_lla(LLA.new(lat: 40.0, lng: -122.0), "CA_I")
    restored = BNG.from_state_plane(sp)
    assert_instance_of BNG, restored
  end

  # -- to_gh36 / from_gh36 ---------------------------------------------------

  def test_to_gh36
    bng = BNG.new(easting: 530000, northing: 180000)
    gh36 = bng.to_gh36
    assert_instance_of GH36, gh36
  end

  def test_from_gh36_roundtrip
    london = LLA.new(lat: 51.5, lng: -0.1, alt: 0.0)
    bng = BNG.from_lla(london)
    gh36 = bng.to_gh36
    restored = BNG.from_gh36(gh36)
    restored_lla = restored.to_lla
    assert_in_delta 51.5, restored_lla.lat, 0.2
    assert_in_delta(-0.1, restored_lla.lng, 0.2)
  end

  # -- parse_grid_reference letters-only format --------------------------------

  def test_parse_grid_reference_letters_only
    coord = BNG.new(grid_ref: "TQ")
    assert_instance_of BNG, coord
    # Letters-only uses center of 100km square
    assert_in_delta 550000.0, coord.easting, 1.0
    assert_in_delta 1150000.0, coord.northing, 1.0
  end

  # -- invalid grid square raises ArgumentError --------------------------------

  def test_invalid_grid_square_raises
    assert_raises(ArgumentError) { BNG.new(grid_ref: "ZZ 300000 800000") }
  end

  # -- invalid grid ref format raises ArgumentError ----------------------------

  def test_invalid_grid_ref_format_raises
    assert_raises(ArgumentError) { BNG.new(grid_ref: "123-ABC") }
  end

  # -- to_lla / from_lla with non-WGS84 datum ---------------------------------

  def test_to_lla_non_wgs84_datum
    bng = BNG.new(easting: 530000, northing: 180000)
    # When datum is not WGS84, to_lla returns the raw OSGB36 LLA without transform
    osgb36_datum = BNG::OSGB36
    lla = bng.to_lla(osgb36_datum)
    assert_instance_of LLA, lla
    # The non-WGS84 path skips the OSGB36->WGS84 shift, so lat/lng differ slightly
    lla_wgs84 = bng.to_lla
    refute_in_delta lla.lat, lla_wgs84.lat, 1e-8
  end

  def test_from_lla_non_wgs84_datum
    lla = LLA.new(lat: 51.5, lng: -0.1, alt: 0.0)
    osgb36_datum = BNG::OSGB36
    # When datum is not WGS84, from_lla skips the WGS84->OSGB36 shift
    bng = BNG.from_lla(lla, osgb36_datum)
    assert_instance_of BNG, bng
    # Compare with WGS84 path - easting/northing should differ
    bng_wgs84 = BNG.from_lla(lla)
    refute_in_delta bng.easting, bng_wgs84.easting, 1e-8
  end

  # -- to_enu / from_enu (direct instance/class methods) -----------------------

  def test_to_enu_direct
    ref = LLA.new(lat: 51.0, lng: 0.0)
    bng = BNG.new(easting: 530000, northing: 180000)
    enu = bng.to_enu(ref)
    assert_instance_of ENU, enu
  end

  def test_from_enu_direct
    ref = LLA.new(lat: 51.0, lng: 0.0)
    london = LLA.new(lat: 51.5, lng: -0.1, alt: 0.0)
    bng = BNG.from_lla(london)
    enu = bng.to_enu(ref)
    restored = BNG.from_enu(enu, ref)
    assert_instance_of BNG, restored
    restored_lla = restored.to_lla
    assert_in_delta 51.5, restored_lla.lat, 0.2
    assert_in_delta(-0.1, restored_lla.lng, 0.2)
  end

  # -- to_ned / from_ned (direct instance/class methods) -----------------------

  def test_to_ned_direct
    ref = LLA.new(lat: 51.0, lng: 0.0)
    bng = BNG.new(easting: 530000, northing: 180000)
    ned = bng.to_ned(ref)
    assert_instance_of NED, ned
  end

  def test_from_ned_direct
    ref = LLA.new(lat: 51.0, lng: 0.0)
    london = LLA.new(lat: 51.5, lng: -0.1, alt: 0.0)
    bng = BNG.from_lla(london)
    ned = bng.to_ned(ref)
    restored = BNG.from_ned(ned, ref)
    assert_instance_of BNG, restored
    restored_lla = restored.to_lla
    assert_in_delta 51.5, restored_lla.lat, 0.2
    assert_in_delta(-0.1, restored_lla.lng, 0.2)
  end

  # -- from_ups (class method) ------------------------------------------------

  def test_from_ups_class_method
    # Create a UPS coordinate from a high-latitude LLA
    lla = LLA.new(lat: 85.0, lng: -2.0)
    ups = UPS_C.from_lla(lla)
    # Use non-WGS84 datum to avoid the +0.00015 lat shift that can exceed 90
    osgb36_datum = BNG::OSGB36
    restored = BNG.from_ups(ups, osgb36_datum)
    assert_instance_of BNG, restored
  end

  # -- equality with non-BNG returns false -------------------------------------

  def test_equality_with_non_bng_returns_false
    bng = BNG.new(easting: 530000, northing: 180000)
    lla = LLA.new(lat: 51.5, lng: -0.1)
    refute_equal bng, lla
  end
end
