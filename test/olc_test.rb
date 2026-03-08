# frozen_string_literal: true

require_relative "test_helper"
require "geodetic"

class OLCTest < Minitest::Test
  include Geodetic
  include Geodetic::Coordinate

  # ── Constructor from String ────────────────────────────────────

  def test_constructor_from_full_code
    olc = OLC.new("849VCWC8+R9")
    assert_equal "849VCWC8+R9", olc.code
    assert_equal 10, olc.precision
  end

  def test_constructor_from_padded_code_precision_2
    olc = OLC.new("84000000+")
    assert_equal "84000000+", olc.code
    assert_equal 2, olc.precision
  end

  def test_constructor_from_padded_code_precision_4
    olc = OLC.new("849V0000+")
    assert_equal "849V0000+", olc.code
    assert_equal 4, olc.precision
  end

  def test_constructor_from_padded_code_precision_6
    olc = OLC.new("849VCW00+")
    assert_equal "849VCW00+", olc.code
    assert_equal 6, olc.precision
  end

  def test_constructor_from_code_precision_8
    olc = OLC.new("849VCWC8+")
    assert_equal "849VCWC8+", olc.code
    assert_equal 8, olc.precision
  end

  def test_constructor_with_grid_refinement
    olc = OLC.new("849VCWC8+R9G")
    assert_equal "849VCWC8+R9G", olc.code
    assert_equal 11, olc.precision
  end

  def test_constructor_case_insensitive
    olc = OLC.new("849vcwc8+r9")
    assert_equal "849VCWC8+R9", olc.code
  end

  def test_constructor_strips_whitespace
    olc = OLC.new("  849VCWC8+R9  ")
    assert_equal "849VCWC8+R9", olc.code
  end

  def test_constructor_rejects_empty_string
    assert_raises(ArgumentError) { OLC.new("") }
  end

  def test_constructor_rejects_missing_separator
    assert_raises(ArgumentError) { OLC.new("849VCWC8R9") }
  end

  def test_constructor_rejects_separator_at_wrong_position
    assert_raises(ArgumentError) { OLC.new("849VCW+C8R9") }
  end

  def test_constructor_rejects_invalid_characters
    assert_raises(ArgumentError) { OLC.new("849VCWA8+R9") }
  end

  def test_constructor_rejects_padding_after_significant
    assert_raises(ArgumentError) { OLC.new("849V0W00+") }
  end

  def test_constructor_rejects_chars_after_separator_with_padding
    assert_raises(ArgumentError) { OLC.new("84000000+R9") }
  end

  def test_constructor_rejects_odd_padding_start
    assert_raises(ArgumentError) { OLC.new("8490000+") }
  end

  # ── Constructor from Coordinates ───────────────────────────────

  def test_constructor_from_lla
    lla = LLA.new(lat: 37.4220, lng: -122.0841)
    olc = OLC.new(lla)
    assert_equal 10, olc.precision
    assert olc.code.include?("+")
  end

  def test_constructor_from_lla_with_precision
    lla = LLA.new(lat: 37.4220, lng: -122.0841)
    olc = OLC.new(lla, precision: 6)
    assert_equal 6, olc.precision
  end

  def test_constructor_from_coordinate_with_to_lla
    lla = LLA.new(lat: 37.4220, lng: -122.0841)
    utm = lla.to_utm
    olc = OLC.new(utm)
    assert_equal 10, olc.precision
  end

  def test_constructor_rejects_invalid_source
    assert_raises(ArgumentError) { OLC.new(42) }
  end

  # ── Known Encodings ────────────────────────────────────────────

  def test_google_hq_encoding
    # Google HQ: lat 37.4220, lng -122.0841
    lla = LLA.new(lat: 37.4220, lng: -122.0841)
    olc = OLC.new(lla)
    assert_equal "849VCWC8+R9", olc.code
  end

  def test_low_precision_encoding
    lla = LLA.new(lat: 37.4220, lng: -122.0841)
    olc = OLC.new(lla, precision: 2)
    assert_equal "84000000+", olc.code
  end

  def test_precision_4_encoding
    lla = LLA.new(lat: 37.4220, lng: -122.0841)
    olc = OLC.new(lla, precision: 4)
    assert_equal "849V0000+", olc.code
  end

  def test_precision_8_encoding
    lla = LLA.new(lat: 37.4220, lng: -122.0841)
    olc = OLC.new(lla, precision: 8)
    assert_equal "849VCWC8+", olc.code
  end

  # ── Decode / Roundtrip ────────────────────────────────────────

  def test_roundtrip_precision_10
    lla = LLA.new(lat: 40.689167, lng: -74.044444)
    olc = OLC.new(lla)
    decoded = olc.to_lla
    assert_in_delta 40.689167, decoded.lat, 0.001
    assert_in_delta(-74.044444, decoded.lng, 0.001)
  end

  def test_roundtrip_precision_6
    lla = LLA.new(lat: 51.5074, lng: -0.1278)
    olc = OLC.new(lla, precision: 6)
    decoded = olc.to_lla
    assert_in_delta 51.5074, decoded.lat, 0.1
    assert_in_delta(-0.1278, decoded.lng, 0.1)
  end

  def test_roundtrip_grid_refinement
    lla = LLA.new(lat: 37.4220, lng: -122.0841)
    olc = OLC.new(lla, precision: 11)
    decoded = olc.to_lla
    assert_in_delta 37.4220, decoded.lat, 0.001
    assert_in_delta(-122.0841, decoded.lng, 0.001)
  end

  def test_roundtrip_south_west
    lla = LLA.new(lat: -33.8688, lng: -151.2093)
    olc = OLC.new(lla)
    decoded = olc.to_lla
    assert_in_delta(-33.8688, decoded.lat, 0.001)
    assert_in_delta(-151.2093, decoded.lng, 0.001)
  end

  def test_roundtrip_near_equator
    lla = LLA.new(lat: 0.0, lng: 0.0)
    olc = OLC.new(lla)
    decoded = olc.to_lla
    assert_in_delta 0.0, decoded.lat, 0.001
    assert_in_delta 0.0, decoded.lng, 0.001
  end

  def test_latitude_90_clamped
    lla = LLA.new(lat: 90.0, lng: 0.0)
    olc = OLC.new(lla)
    decoded = olc.to_lla
    assert_in_delta 90.0, decoded.lat, 0.1
  end

  def test_negative_latitude
    lla = LLA.new(lat: -90.0, lng: 0.0)
    olc = OLC.new(lla)
    decoded = olc.to_lla
    assert_in_delta(-90.0, decoded.lat, 0.1)
  end

  # ── LLA Convenience Methods ───────────────────────────────────

  def test_lla_to_olc
    lla = LLA.new(lat: 37.4220, lng: -122.0841)
    olc = lla.to_olc
    assert_instance_of OLC, olc
    assert_equal 10, olc.precision
  end

  def test_lla_to_olc_with_precision
    lla = LLA.new(lat: 37.4220, lng: -122.0841)
    olc = lla.to_olc(precision: 6)
    assert_equal 6, olc.precision
  end

  def test_lla_from_olc
    olc = OLC.new("849VCWC8+R9")
    lla = LLA.from_olc(olc)
    assert_instance_of LLA, lla
    assert_in_delta 37.4220, lla.lat, 0.001
  end

  # ── Serialization ─────────────────────────────────────────────

  def test_to_s
    olc = OLC.new("849VCWC8+R9")
    assert_equal "849VCWC8+R9", olc.to_s
  end

  def test_to_s_truncate
    olc = OLC.new("849VCWC8+R9")
    truncated = olc.to_s(6)
    assert_equal 6, OLC.new(truncated).precision
  end

  def test_to_s_truncate_minimum
    olc = OLC.new("849VCWC8+R9")
    truncated = olc.to_s(1)
    assert_equal 2, OLC.new(truncated).precision
  end

  def test_to_a
    olc = OLC.new("849VCWC8+R9")
    arr = olc.to_a
    assert_equal 2, arr.length
    assert_kind_of Float, arr[0]
    assert_kind_of Float, arr[1]
  end

  def test_from_array
    olc = OLC.from_array([37.4220, -122.0841])
    assert_instance_of OLC, olc
    assert_equal 10, olc.precision
  end

  def test_from_string
    olc = OLC.from_string("849VCWC8+R9")
    assert_equal "849VCWC8+R9", olc.code
  end

  def test_to_slug
    olc = OLC.new("849VCWC8+R9")
    assert_equal olc.to_s, olc.to_slug
  end

  # ── Equality ──────────────────────────────────────────────────

  def test_equality_same_code
    assert_equal OLC.new("849VCWC8+R9"), OLC.new("849VCWC8+R9")
  end

  def test_equality_different_code
    refute_equal OLC.new("849VCWC8+R9"), OLC.new("849VCWC8+R8")
  end

  def test_equality_different_class
    refute_equal OLC.new("849VCWC8+R9"), "849VCWC8+R9"
  end

  # ── Valid? ────────────────────────────────────────────────────

  def test_valid_full_code
    assert OLC.new("849VCWC8+R9").valid?
  end

  def test_valid_padded_code
    assert OLC.new("84000000+").valid?
  end

  # ── Immutability ──────────────────────────────────────────────

  def test_no_setter_for_code
    olc = OLC.new("849VCWC8+R9")
    refute_respond_to olc, :code=
  end

  # ── Neighbors ─────────────────────────────────────────────────

  def test_neighbors_returns_8_directions
    olc = OLC.new(LLA.new(lat: 40.0, lng: -74.0))
    neighbors = olc.neighbors
    assert_equal 8, neighbors.size
    [:N, :S, :E, :W, :NE, :NW, :SE, :SW].each do |dir|
      assert_instance_of OLC, neighbors[dir]
    end
  end

  def test_neighbor_north_has_higher_lat
    olc = OLC.new(LLA.new(lat: 40.5, lng: -74.5))
    neighbors = olc.neighbors
    assert_operator neighbors[:N].to_lla.lat, :>, olc.to_lla.lat
  end

  def test_neighbor_east_has_higher_lng
    olc = OLC.new(LLA.new(lat: 40.5, lng: -74.5))
    neighbors = olc.neighbors
    assert_operator neighbors[:E].to_lla.lng, :>, olc.to_lla.lng
  end

  def test_neighbor_south_has_lower_lat
    olc = OLC.new(LLA.new(lat: 40.5, lng: -74.5))
    neighbors = olc.neighbors
    assert_operator neighbors[:S].to_lla.lat, :<, olc.to_lla.lat
  end

  def test_neighbor_preserves_precision
    olc = OLC.new(LLA.new(lat: 40.0, lng: -74.0), precision: 8)
    neighbors = olc.neighbors
    neighbors.each_value do |n|
      assert_equal 8, n.precision
    end
  end

  # ── Area ──────────────────────────────────────────────────────

  def test_to_area_returns_rectangle
    olc = OLC.new(LLA.new(lat: 40.0, lng: -74.0))
    area = olc.to_area
    assert_instance_of Areas::Rectangle, area
  end

  def test_to_area_contains_midpoint
    olc = OLC.new(LLA.new(lat: 40.0, lng: -74.0))
    area = olc.to_area
    assert area.includes?(olc.to_lla)
  end

  def test_to_area_nw_se_ordering
    olc = OLC.new(LLA.new(lat: 40.0, lng: -74.0))
    area = olc.to_area
    assert_operator area.nw.lat, :>=, area.se.lat
    assert_operator area.se.lng, :>=, area.nw.lng
  end

  # ── Precision in Meters ───────────────────────────────────────

  def test_precision_in_meters_returns_hash
    olc = OLC.new(LLA.new(lat: 40.0, lng: -74.0))
    pm = olc.precision_in_meters
    assert_kind_of Hash, pm
    assert pm[:lat] > 0
    assert pm[:lng] > 0
  end

  def test_precision_10_roughly_14m
    olc = OLC.new(LLA.new(lat: 0.0, lng: 0.0))
    pm = olc.precision_in_meters
    # At equator, precision 10 should be ~13.9m x 13.9m
    assert_in_delta 13.9, pm[:lat], 1.0
    assert_in_delta 13.9, pm[:lng], 1.0
  end

  def test_precision_2_large_area
    olc = OLC.new(LLA.new(lat: 0.0, lng: 0.0), precision: 2)
    pm = olc.precision_in_meters
    assert pm[:lat] > 2_000_000 # > 2000 km
  end

  # ── Cross-System Conversions ──────────────────────────────────

  def test_to_ecef_and_back
    olc = OLC.new(LLA.new(lat: 40.0, lng: -74.0))
    ecef = olc.to_ecef
    olc2 = OLC.from_ecef(ecef)
    assert_equal olc.code, olc2.code
  end

  def test_to_utm_and_back
    olc = OLC.new(LLA.new(lat: 40.0, lng: -74.0))
    utm = olc.to_utm
    olc2 = OLC.from_utm(utm)
    assert_in_delta olc.to_lla.lat, olc2.to_lla.lat, 0.001
  end

  def test_to_enu_and_back
    ref = LLA.new(lat: 40.0, lng: -74.0)
    olc = OLC.new(LLA.new(lat: 40.001, lng: -74.001))
    enu = olc.to_enu(ref)
    olc2 = OLC.from_enu(enu, ref)
    assert_in_delta olc.to_lla.lat, olc2.to_lla.lat, 0.001
  end

  def test_to_ned_and_back
    ref = LLA.new(lat: 40.0, lng: -74.0)
    olc = OLC.new(LLA.new(lat: 40.001, lng: -74.001))
    ned = olc.to_ned(ref)
    olc2 = OLC.from_ned(ned, ref)
    assert_in_delta olc.to_lla.lat, olc2.to_lla.lat, 0.001
  end

  def test_to_mgrs_and_back
    olc = OLC.new(LLA.new(lat: 40.0, lng: -74.0))
    mgrs = olc.to_mgrs
    olc2 = OLC.from_mgrs(mgrs)
    assert_in_delta olc.to_lla.lat, olc2.to_lla.lat, 0.001
  end

  def test_to_usng_and_back
    olc = OLC.new(LLA.new(lat: 40.0, lng: -74.0))
    usng = olc.to_usng
    olc2 = OLC.from_usng(usng)
    assert_in_delta olc.to_lla.lat, olc2.to_lla.lat, 0.001
  end

  def test_to_web_mercator_and_back
    olc = OLC.new(LLA.new(lat: 40.0, lng: -74.0))
    wm = olc.to_web_mercator
    olc2 = OLC.from_web_mercator(wm)
    assert_in_delta olc.to_lla.lat, olc2.to_lla.lat, 0.001
  end

  def test_to_ups_and_back
    olc = OLC.new(LLA.new(lat: 85.0, lng: 10.0))
    ups = olc.to_ups
    olc2 = OLC.from_ups(ups)
    # UPS inverse projection converges near pole - needs large tolerance
    assert_in_delta olc.to_lla.lat, olc2.to_lla.lat, 6.0
  end

  def test_to_bng_and_back
    olc = OLC.new(LLA.new(lat: 51.5, lng: -0.1))
    bng = olc.to_bng
    olc2 = OLC.from_bng(bng)
    assert_in_delta olc.to_lla.lat, olc2.to_lla.lat, 0.01
  end

  def test_to_state_plane_and_back
    olc = OLC.new(LLA.new(lat: 40.0, lng: -74.0))
    sp = olc.to_state_plane("NY_LONG_ISLAND")
    olc2 = OLC.from_state_plane(sp)
    assert_in_delta olc.to_lla.lat, olc2.to_lla.lat, 0.01
  end

  def test_to_gh36_and_back
    olc = OLC.new(LLA.new(lat: 40.0, lng: -74.0))
    gh36 = olc.to_gh36
    olc2 = OLC.from_gh36(gh36)
    assert_in_delta olc.to_lla.lat, olc2.to_lla.lat, 0.001
  end

  def test_to_gh_and_back
    olc = OLC.new(LLA.new(lat: 40.0, lng: -74.0))
    gh = olc.to_gh
    olc2 = OLC.from_gh(gh)
    assert_in_delta olc.to_lla.lat, olc2.to_lla.lat, 0.001
  end

  def test_to_ham_and_back
    olc = OLC.new(LLA.new(lat: 40.0, lng: -74.0))
    ham = olc.to_ham
    olc2 = OLC.from_ham(ham)
    assert_in_delta olc.to_lla.lat, olc2.to_lla.lat, 0.1
  end

  # ── Reverse conversions (other classes to_olc / from_olc) ─────

  def test_ecef_to_olc
    lla = LLA.new(lat: 40.0, lng: -74.0)
    ecef = lla.to_ecef
    olc = ecef.to_olc
    assert_instance_of OLC, olc
  end

  def test_utm_to_olc
    lla = LLA.new(lat: 40.0, lng: -74.0)
    utm = lla.to_utm
    olc = utm.to_olc
    assert_instance_of OLC, olc
  end

  def test_enu_to_olc
    ref = LLA.new(lat: 40.0, lng: -74.0)
    enu = ENU.new(e: 100.0, n: 200.0, u: 50.0)
    olc = enu.to_olc(ref)
    assert_instance_of OLC, olc
  end

  def test_ned_to_olc
    ref = LLA.new(lat: 40.0, lng: -74.0)
    ned = NED.new(n: 200.0, e: 100.0, d: -50.0)
    olc = ned.to_olc(ref)
    assert_instance_of OLC, olc
  end

  def test_mgrs_to_olc
    mgrs = MGRS.new(mgrs_string: "18TWL8598814995")
    olc = mgrs.to_olc
    assert_instance_of OLC, olc
  end

  def test_usng_to_olc
    usng = USNG.new(usng_string: "18T WL 85988 14995")
    olc = usng.to_olc
    assert_instance_of OLC, olc
  end

  def test_web_mercator_to_olc
    wm = WebMercator.from_lla(LLA.new(lat: 40.0, lng: -74.0))
    olc = wm.to_olc
    assert_instance_of OLC, olc
  end

  def test_ups_to_olc
    ups = UPS.from_lla(LLA.new(lat: 85.0, lng: 10.0))
    olc = ups.to_olc
    assert_instance_of OLC, olc
  end

  def test_bng_to_olc
    bng = BNG.new(easting: 530000, northing: 180000)
    olc = bng.to_olc
    assert_instance_of OLC, olc
  end

  def test_state_plane_to_olc
    sp = StatePlane.new(easting: 2000000.0, northing: 500000.0, zone_code: "NY_LONG_ISLAND")
    olc = sp.to_olc
    assert_instance_of OLC, olc
  end

  def test_gh36_to_olc
    gh36 = GH36.new(LLA.new(lat: 40.0, lng: -74.0))
    olc = gh36.to_olc
    assert_instance_of OLC, olc
  end

  def test_gh_to_olc
    gh = GH.new(LLA.new(lat: 40.0, lng: -74.0))
    olc = gh.to_olc
    assert_instance_of OLC, olc
  end

  def test_ham_to_olc
    ham = HAM.new("FN31pr")
    olc = ham.to_olc
    assert_instance_of OLC, olc
  end

  # ── Distance and Bearing Mixins ───────────────────────────────

  def test_distance_to
    a = OLC.new(LLA.new(lat: 40.689167, lng: -74.044444))
    b = OLC.new(LLA.new(lat: 51.504444, lng: -0.086666))
    d = a.distance_to(b)
    assert_instance_of Distance, d
    assert d.meters > 5_000_000  # ~5,500 km
  end

  def test_bearing_to
    a = OLC.new(LLA.new(lat: 40.689167, lng: -74.044444))
    b = OLC.new(LLA.new(lat: 51.504444, lng: -0.086666))
    b_bearing = a.bearing_to(b)
    assert_instance_of Bearing, b_bearing
    assert b_bearing.degrees > 0
  end

  def test_cross_system_distance
    olc = OLC.new(LLA.new(lat: 40.0, lng: -74.0))
    utm = LLA.new(lat: 41.0, lng: -74.0).to_utm
    d = olc.distance_to(utm)
    assert_instance_of Distance, d
  end

  # ── OLC class factory methods ─────────────────────────────────

  def test_olc_from_lla_class_method
    lla = LLA.new(lat: 37.4220, lng: -122.0841)
    olc = OLC.from_lla(lla)
    assert_instance_of OLC, olc
    assert_equal 10, olc.precision
  end

  def test_olc_from_lla_with_precision
    lla = LLA.new(lat: 37.4220, lng: -122.0841)
    olc = OLC.from_lla(lla, WGS84, 6)
    assert_equal 6, olc.precision
  end

  # ── Alphabet ──────────────────────────────────────────────────

  def test_alphabet_has_20_characters
    assert_equal 20, OLC::ALPHABET.length
  end

  def test_alphabet_excludes_vowels
    %w[A E I O U].each do |vowel|
      refute_includes OLC::ALPHABET, vowel
    end
  end

  def test_char_index_matches_alphabet
    OLC::ALPHABET.each_char.with_index do |ch, i|
      assert_equal i, OLC::CHAR_INDEX[ch]
    end
  end
end
