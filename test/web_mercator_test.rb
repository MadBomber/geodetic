# frozen_string_literal: true

require "test_helper"
require_relative "../lib/geodetic/coordinates/web_mercator"
require_relative "../lib/geodetic/coordinates/lla"

class WebMercatorTest < Minitest::Test
  WebMercator = Geodetic::Coordinates::WebMercator
  LLA         = Geodetic::Coordinates::LLA

  # ── Constructor ──────────────────────────────────────────────

  def test_default_values
    coord = WebMercator.new
    assert_in_delta 0.0, coord.x, 1e-6
    assert_in_delta 0.0, coord.y, 1e-6
  end

  def test_keyword_arguments
    coord = WebMercator.new(x: 1000.0, y: 2000.0)
    assert_in_delta 1000.0, coord.x, 1e-6
    assert_in_delta 2000.0, coord.y, 1e-6
  end

  # ── Accessors ──────────────────────────────────────────────

  def test_x_reader
    coord = WebMercator.new(x: 123.456)
    assert_in_delta 123.456, coord.x, 1e-6
  end

  def test_y_reader
    coord = WebMercator.new(y: 654.321)
    assert_in_delta 654.321, coord.y, 1e-6
  end

  # ── Setters ──────────────────────────────────────────────

  def test_x_setter
    coord = WebMercator.new(x: 123.456)
    coord.x = 789.0
    assert_in_delta 789.0, coord.x, 1e-6
  end

  def test_y_setter
    coord = WebMercator.new(y: 654.321)
    coord.y = 111.0
    assert_in_delta 111.0, coord.y, 1e-6
  end

  def test_setters_coerce_to_float
    coord = WebMercator.new
    coord.x = "1234.5"
    coord.y = "6789.0"
    assert_in_delta 1234.5, coord.x, 1e-6
    assert_in_delta 6789.0, coord.y, 1e-6
  end

  # ── to_s ───────────────────────────────────────────────────

  def test_to_s
    coord = WebMercator.new(x: 1000.5, y: 2000.5)
    assert_equal "1000.50, 2000.50", coord.to_s
  end

  def test_to_s_with_precision
    coord = WebMercator.new(x: 1234.5678, y: 5678.1234)
    assert_equal "1234.568, 5678.123", coord.to_s(3)
    assert_equal "1235, 5678", coord.to_s(0)
  end

  # ── to_a ───────────────────────────────────────────────────

  def test_to_a
    coord = WebMercator.new(x: 1000.0, y: 2000.0)
    result = coord.to_a
    assert_equal 2, result.size
    assert_in_delta 1000.0, result[0], 1e-6
    assert_in_delta 2000.0, result[1], 1e-6
  end

  # ── from_array ─────────────────────────────────────────────

  def test_from_array_roundtrip
    original = WebMercator.new(x: 1234.5, y: 6789.0)
    restored = WebMercator.from_array(original.to_a)
    assert_in_delta original.x, restored.x, 1e-6
    assert_in_delta original.y, restored.y, 1e-6
  end

  # ── from_string ────────────────────────────────────────────

  def test_from_string_roundtrip
    original = WebMercator.new(x: 1234.5, y: 6789.0)
    restored = WebMercator.from_string(original.to_s)
    assert_in_delta original.x, restored.x, 1e-6
    assert_in_delta original.y, restored.y, 1e-6
  end

  # ── == ─────────────────────────────────────────────────────

  def test_equality_equal_coords
    a = WebMercator.new(x: 1000.0, y: 2000.0)
    b = WebMercator.new(x: 1000.0, y: 2000.0)
    assert_equal a, b
  end

  def test_equality_unequal_coords
    a = WebMercator.new(x: 1000.0, y: 2000.0)
    b = WebMercator.new(x: 1001.0, y: 2000.0)
    refute_equal a, b
  end

  def test_equality_non_web_mercator
    coord = WebMercator.new(x: 1000.0, y: 2000.0)
    refute_equal coord, "not a WebMercator"
  end

  # ── from_lla / to_lla roundtrip ────────────────────────────

  def test_lla_roundtrip
    lla = LLA.new(lat: 47.6205, lng: -122.3493)
    wm = WebMercator.from_lla(lla)
    restored = wm.to_lla
    assert_in_delta 47.6205, restored.lat, 1e-4
    assert_in_delta(-122.3493, restored.lng, 1e-4)
  end

  # ── valid? ─────────────────────────────────────────────────

  def test_valid_within_bounds
    coord = WebMercator.new(x: 0.0, y: 0.0)
    assert coord.valid?
  end

  def test_valid_at_origin_shift_boundary
    coord = WebMercator.new(x: WebMercator::ORIGIN_SHIFT, y: WebMercator::ORIGIN_SHIFT)
    assert coord.valid?
  end

  def test_invalid_outside_bounds
    coord = WebMercator.new(x: WebMercator::ORIGIN_SHIFT + 1.0, y: 0.0)
    refute coord.valid?
  end

  # ── clamp! ─────────────────────────────────────────────────

  def test_clamp_within_bounds_unchanged
    coord = WebMercator.new(x: 1000.0, y: 2000.0)
    coord.clamp!
    assert_in_delta 1000.0, coord.x, 1e-6
    assert_in_delta 2000.0, coord.y, 1e-6
  end

  def test_clamp_exceeding_bounds
    over = WebMercator::ORIGIN_SHIFT + 5000.0
    coord = WebMercator.new(x: over, y: -over)
    coord.clamp!
    assert_in_delta WebMercator::ORIGIN_SHIFT, coord.x, 1e-6
    assert_in_delta(-WebMercator::ORIGIN_SHIFT, coord.y, 1e-6)
  end

  def test_clamp_returns_self
    coord = WebMercator.new(x: 0.0, y: 0.0)
    assert_same coord, coord.clamp!
  end

  # ── distance_to ────────────────────────────────────────────

  def test_distance_to
    a = WebMercator.new(x: 0.0, y: 0.0)
    b = WebMercator.new(x: 100000.0, y: 100000.0)
    dist = a.distance_to(b)
    assert_instance_of Geodetic::Distance, dist
    assert dist > 0.0, "Expected positive distance between different WebMercator points"
  end

  # ── to_tile_coordinates / from_tile_coordinates ────────────

  def test_tile_coordinates_roundtrip_zoom_10
    lla = LLA.new(lat: 47.6205, lng: -122.3493)
    wm = WebMercator.from_lla(lla)
    tile = wm.to_tile_coordinates(10)

    assert_equal 3, tile.size
    assert_equal 10, tile[2]
    assert_kind_of Integer, tile[0]
    assert_kind_of Integer, tile[1]

    restored = WebMercator.from_tile_coordinates(tile[0], tile[1], tile[2])
    restored_lla = restored.to_lla
    # Tile coordinates represent the NW corner of a tile, so tolerance is large
    assert_in_delta 47.6205, restored_lla.lat, 1.0
    assert_in_delta(-122.3493, restored_lla.lng, 1.0)
  end

  # ── to_pixel_coordinates / from_pixel_coordinates ──────────

  def test_pixel_coordinates_roundtrip
    lla = LLA.new(lat: 47.6205, lng: -122.3493)
    wm = WebMercator.from_lla(lla)
    pixel = wm.to_pixel_coordinates(10)

    assert_equal 3, pixel.size
    assert_equal 10, pixel[2]
    assert_kind_of Integer, pixel[0]
    assert_kind_of Integer, pixel[1]

    restored = WebMercator.from_pixel_coordinates(pixel[0], pixel[1], pixel[2])
    restored_lla = restored.to_lla
    assert_in_delta 47.6205, restored_lla.lat, 0.01
    assert_in_delta(-122.3493, restored_lla.lng, 0.01)
  end
end
