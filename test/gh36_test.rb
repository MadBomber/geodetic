# frozen_string_literal: true

require "test_helper"
require_relative "../lib/geodetic/coordinates/gh36"
require_relative "../lib/geodetic/coordinates/lla"

class GH36Test < Minitest::Test
  GH36 = Geodetic::Coordinates::GH36
  LLA  = Geodetic::Coordinates::LLA

  # ── Constructor from String ────────────────────────────────

  def test_from_geohash_string
    coord = GH36.new("bdrdC26BqH")
    assert_equal "bdrdC26BqH", coord.geohash
  end

  def test_raises_on_invalid_geohash_chars
    assert_raises(ArgumentError) { GH36.new("abc!@#") }
  end

  def test_raises_on_empty_geohash
    assert_raises(ArgumentError) { GH36.new("") }
  end

  # ── Constructor from coordinate ────────────────────────────

  def test_from_lla
    lla = LLA.new(lat: 51.504444, lng: -0.086666)
    coord = GH36.new(lla)
    assert_equal 10, coord.precision
  end

  def test_from_lla_custom_precision
    lla = LLA.new(lat: 0.0, lng: 0.0)
    coord = GH36.new(lla, precision: 5)
    assert_equal 5, coord.precision
  end

  def test_from_any_coordinate_with_to_lla
    lla = LLA.new(lat: 40.689167, lng: -74.044444)
    utm = lla.to_utm
    coord = GH36.new(utm)
    restored = coord.to_lla
    assert_in_delta 40.689167, restored.lat, 0.001
    assert_in_delta(-74.044444, restored.lng, 0.001)
  end

  def test_raises_on_unsupported_source
    assert_raises(ArgumentError) { GH36.new(42) }
  end

  # ── Precision ──────────────────────────────────────────────

  def test_precision_matches_hash_length
    coord = GH36.new("bdrdC")
    assert_equal 5, coord.precision
  end

  # ── to_s ───────────────────────────────────────────────────

  def test_to_s_returns_geohash
    coord = GH36.new("bdrdC26BqH")
    assert_equal "bdrdC26BqH", coord.to_s
  end

  def test_to_s_with_truncation
    coord = GH36.new("bdrdC26BqH")
    assert_equal "bdrdC", coord.to_s(5)
  end

  # ── to_a ───────────────────────────────────────────────────

  def test_to_a_returns_lat_lng
    lla = LLA.new(lat: 40.0, lng: -74.0)
    coord = GH36.new(lla)
    result = coord.to_a
    assert_equal 2, result.size
    assert_in_delta 40.0, result[0], 0.01
    assert_in_delta(-74.0, result[1], 0.01)
  end

  # ── from_array / from_string ─────────────────────────────

  def test_from_array
    coord = GH36.from_array([40.689167, -74.044444])
    lla = coord.to_lla
    assert_in_delta 40.689167, lla.lat, 0.001
    assert_in_delta(-74.044444, lla.lng, 0.001)
  end

  def test_from_string
    coord = GH36.from_string("bdrdC26BqH")
    assert_equal "bdrdC26BqH", coord.geohash
  end

  # ── Encode / Decode roundtrip ────────────────────────────

  def test_roundtrip_origin
    coord = GH36.new(LLA.new(lat: 0.0, lng: 0.0))
    restored = coord.to_lla
    assert_in_delta 0.0, restored.lat, 0.001
    assert_in_delta 0.0, restored.lng, 0.001
  end

  def test_roundtrip_statue_of_liberty
    coord = GH36.new(LLA.new(lat: 40.689167, lng: -74.044444))
    restored = coord.to_lla
    assert_in_delta 40.689167, restored.lat, 0.001
    assert_in_delta(-74.044444, restored.lng, 0.001)
  end

  def test_roundtrip_london
    coord = GH36.new(LLA.new(lat: 51.504444, lng: -0.086666))
    restored = coord.to_lla
    assert_in_delta 51.504444, restored.lat, 0.001
    assert_in_delta(-0.086666, restored.lng, 0.001)
  end

  def test_roundtrip_southern_hemisphere
    coord = GH36.new(LLA.new(lat: -33.8688, lng: 151.2093))
    restored = coord.to_lla
    assert_in_delta(-33.8688, restored.lat, 0.001)
    assert_in_delta 151.2093, restored.lng, 0.001
  end

  def test_roundtrip_extreme_coordinates
    coord = GH36.new(LLA.new(lat: 89.9, lng: 179.9))
    restored = coord.to_lla
    assert_in_delta 89.9, restored.lat, 0.01
    assert_in_delta 179.9, restored.lng, 0.01
  end

  def test_roundtrip_negative_extremes
    coord = GH36.new(LLA.new(lat: -89.9, lng: -179.9))
    restored = coord.to_lla
    assert_in_delta(-89.9, restored.lat, 0.01)
    assert_in_delta(-179.9, restored.lng, 0.01)
  end

  # ── LLA convenience methods ─────────────────────────────

  def test_lla_to_gh36
    lla = LLA.new(lat: 40.689167, lng: -74.044444)
    gh36 = lla.to_gh36
    assert_instance_of GH36, gh36
    restored = gh36.to_lla
    assert_in_delta 40.689167, restored.lat, 0.001
    assert_in_delta(-74.044444, restored.lng, 0.001)
  end

  def test_lla_from_gh36
    gh36 = GH36.new(LLA.new(lat: 40.689167, lng: -74.044444))
    lla = LLA.from_gh36(gh36)
    assert_instance_of LLA, lla
    assert_in_delta 40.689167, lla.lat, 0.001
  end

  # ── Equality ─────────────────────────────────────────────

  def test_equality_same_hash
    a = GH36.new("bdrdC26BqH")
    b = GH36.new("bdrdC26BqH")
    assert_equal a, b
  end

  def test_equality_different_hash
    a = GH36.new("bdrdC26BqH")
    b = GH36.new("bdrdC26Bq2")
    refute_equal a, b
  end

  def test_equality_non_gh36
    coord = GH36.new("bdrdC26BqH")
    refute_equal coord, "bdrdC26BqH"
  end

  # ── valid? ───────────────────────────────────────────────

  def test_valid_hash
    coord = GH36.new("bdrdC26BqH")
    assert coord.valid?
  end

  # ── Neighbors ────────────────────────────────────────────

  def test_neighbors_returns_all_eight
    coord = GH36.new("bdrdC26BqH")
    all = coord.neighbors
    assert_equal 8, all.size
    assert all.key?(:N)
    assert all.key?(:S)
    assert all.key?(:E)
    assert all.key?(:W)
    assert all.key?(:NE)
    assert all.key?(:NW)
    assert all.key?(:SE)
    assert all.key?(:SW)
  end

  def test_neighbors_returns_gh36_instances
    coord = GH36.new("bdrdC26BqH")
    all = coord.neighbors
    all.each_value do |neighbor|
      assert_instance_of GH36, neighbor
    end
  end

  def test_neighbors_differ_from_original
    coord = GH36.new("bdrdC26BqH")
    coord.neighbors.each_value do |neighbor|
      refute_equal coord, neighbor
    end
  end

  def test_north_neighbor_has_higher_latitude
    lla = LLA.new(lat: 40.0, lng: -74.0)
    coord = GH36.new(lla)
    north = coord.neighbors[:N]
    assert north.to_lla.lat > coord.to_lla.lat,
      "North neighbor should have higher latitude"
  end

  def test_south_neighbor_has_lower_latitude
    lla = LLA.new(lat: 40.0, lng: -74.0)
    coord = GH36.new(lla)
    south = coord.neighbors[:S]
    assert south.to_lla.lat < coord.to_lla.lat,
      "South neighbor should have lower latitude"
  end

  def test_east_neighbor_has_higher_longitude
    lla = LLA.new(lat: 40.0, lng: -74.0)
    coord = GH36.new(lla)
    east = coord.neighbors[:E]
    assert east.to_lla.lng > coord.to_lla.lng,
      "East neighbor should have higher longitude"
  end

  def test_west_neighbor_has_lower_longitude
    lla = LLA.new(lat: 40.0, lng: -74.0)
    coord = GH36.new(lla)
    west = coord.neighbors[:W]
    assert west.to_lla.lng < coord.to_lla.lng,
      "West neighbor should have lower longitude"
  end

  def test_neighbor_chainable
    coord = GH36.new(LLA.new(lat: 40.0, lng: -74.0))
    north_lla = coord.neighbors[:N].to_lla
    assert_instance_of LLA, north_lla
  end

  # ── to_area ──────────────────────────────────────────────

  def test_to_area_returns_rectangle
    coord = GH36.new("bdrdC26BqH")
    area = coord.to_area
    assert_instance_of Geodetic::Areas::Rectangle, area
  end

  def test_to_area_contains_midpoint
    lla = LLA.new(lat: 40.0, lng: -74.0)
    coord = GH36.new(lla)
    area = coord.to_area
    assert area.includes?(coord.to_lla)
  end

  def test_to_area_excludes_distant_point
    lla = LLA.new(lat: 40.0, lng: -74.0)
    coord = GH36.new(lla)
    area = coord.to_area
    assert area.excludes?(LLA.new(lat: 0.0, lng: 0.0))
  end

  # ── Precision in meters ─────────────────────────────────

  def test_precision_in_meters
    lla = LLA.new(lat: 0.0, lng: 0.0)
    coord = GH36.new(lla)
    prec = coord.precision_in_meters
    assert prec[:lat] > 0
    assert prec[:lng] > 0
    assert prec[:lng] > prec[:lat], "Longitude precision should be coarser than latitude"
  end

  def test_longer_hash_has_finer_precision
    lla = LLA.new(lat: 0.0, lng: 0.0)
    short = GH36.new(lla, precision: 5)
    long  = GH36.new(lla, precision: 10)
    assert long.precision_in_meters[:lat] < short.precision_in_meters[:lat]
  end

  # ── to_slug ──────────────────────────────────────────────

  def test_to_slug_alias
    coord = GH36.new("bdrdC26BqH")
    assert_equal coord.to_s, coord.to_slug
  end

  # ── distance_to (via mixin) ─────────────────────────────

  def test_distance_to
    a = GH36.new(LLA.new(lat: 40.689167, lng: -74.044444))
    b = GH36.new(LLA.new(lat: 51.504444, lng: -0.086666))
    dist = a.distance_to(b)
    assert_instance_of Geodetic::Distance, dist
    # NYC to London is roughly 5,570 km
    assert_in_delta 5_570_000, dist.to_f, 50_000
  end

  # ── bearing_to (via mixin) ──────────────────────────────

  def test_bearing_to
    a = GH36.new(LLA.new(lat: 40.689167, lng: -74.044444))
    b = GH36.new(LLA.new(lat: 51.504444, lng: -0.086666))
    bearing = a.bearing_to(b)
    assert_instance_of Geodetic::Bearing, bearing
    # NYC to London bearing is roughly 51 degrees
    assert_in_delta 51.0, bearing.degrees, 5.0
  end

  # ── Cross-system conversion ─────────────────────────────

  def test_to_ecef_roundtrip
    gh36 = GH36.new(LLA.new(lat: 40.689167, lng: -74.044444))
    ecef = gh36.to_ecef
    restored = GH36.new(ecef)
    restored_lla = restored.to_lla
    assert_in_delta 40.689167, restored_lla.lat, 0.001
    assert_in_delta(-74.044444, restored_lla.lng, 0.001)
  end

  def test_to_utm_roundtrip
    gh36 = GH36.new(LLA.new(lat: 40.689167, lng: -74.044444))
    utm = gh36.to_utm
    restored = GH36.new(utm)
    restored_lla = restored.to_lla
    assert_in_delta 40.689167, restored_lla.lat, 0.001
    assert_in_delta(-74.044444, restored_lla.lng, 0.001)
  end

  def test_to_web_mercator_roundtrip
    gh36 = GH36.new(LLA.new(lat: 40.689167, lng: -74.044444))
    wm = gh36.to_web_mercator
    restored = GH36.new(wm)
    restored_lla = restored.to_lla
    assert_in_delta 40.689167, restored_lla.lat, 0.001
    assert_in_delta(-74.044444, restored_lla.lng, 0.001)
  end
end
