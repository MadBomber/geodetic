# frozen_string_literal: true

require "test_helper"

class MapBaseTest < Minitest::Test
  LLA        = Geodetic::Coordinate::LLA
  UTM        = Geodetic::Coordinate::UTM
  ECEF       = Geodetic::Coordinate::ECEF
  Path       = Geodetic::Path
  Segment    = Geodetic::Segment
  Feature    = Geodetic::Feature
  Polygon    = Geodetic::Areas::Polygon
  Circle     = Geodetic::Areas::Circle
  BBox       = Geodetic::Areas::BoundingBox
  Hexagon    = Geodetic::Areas::Hexagon
  Base       = Geodetic::Map::Base

  def setup
    @nyc     = LLA.new(lat: 40.7128, lng: -74.0060, alt: 0)
    @dc      = LLA.new(lat: 38.9072, lng: -77.0369, alt: 0)
    @philly  = LLA.new(lat: 39.9526, lng: -75.1652, alt: 0)
    @boston   = LLA.new(lat: 42.3601, lng: -71.0589, alt: 0)
    @map     = Base.new
  end

  # ── add coordinate ──────────────────────────────────────────

  def test_add_lla
    @map.add(@nyc)
    assert_equal 1, @map.size
    assert_equal :point, @map.layers.first[:type]
    assert_equal @nyc, @map.layers.first[:lla]
  end

  def test_add_non_lla_coordinate
    utm = UTM.new(zone: 18, hemisphere: "N", easting: 583960, northing: 4507523)
    @map.add(utm)
    assert_equal 1, @map.size
    assert_equal :point, @map.layers.first[:type]
    assert_in_delta utm.to_lla.latitude, @map.layers.first[:lla].latitude, 0.001
  end

  def test_add_coordinate_with_style
    @map.add(@nyc, color: "red", label: "NYC")
    style = @map.layers.first[:style]
    assert_equal "red", style[:color]
    assert_equal "NYC", style[:label]
  end

  # ── add path ────────────────────────────────────────────────

  def test_add_path
    path = Path.new(coordinates: [@nyc, @philly, @dc])
    @map.add(path)
    assert_equal 1, @map.size
    assert_equal :line, @map.layers.first[:type]
    assert_equal 3, @map.layers.first[:llas].length
  end

  def test_add_path_with_style
    path = Path.new(coordinates: [@nyc, @dc])
    @map.add(path, color: "blue", width: 3)
    style = @map.layers.first[:style]
    assert_equal "blue", style[:color]
    assert_equal 3, style[:width]
  end

  # ── add segment ─────────────────────────────────────────────

  def test_add_segment
    seg = Segment.new(@nyc, @dc)
    @map.add(seg)
    assert_equal 1, @map.size
    assert_equal :line, @map.layers.first[:type]
    assert_equal 2, @map.layers.first[:llas].length
  end

  # ── add polygon ─────────────────────────────────────────────

  def test_add_polygon
    poly = Polygon.new(boundary: [@nyc, @philly, @dc])
    @map.add(poly)
    assert_equal 1, @map.size
    assert_equal :polygon, @map.layers.first[:type]
  end

  def test_add_regular_polygon_subclass
    hex = Hexagon.new(center: @nyc, radius: 1000)
    @map.add(hex)
    assert_equal 1, @map.size
    assert_equal :polygon, @map.layers.first[:type]
  end

  # ── add circle ──────────────────────────────────────────────

  def test_add_circle
    circle = Circle.new(centroid: @nyc, radius: 5000)
    @map.add(circle)
    assert_equal 1, @map.size
    assert_equal :polygon, @map.layers.first[:type]
    assert_equal 33, @map.layers.first[:llas].length  # 32 segments + closing point
  end

  def test_add_circle_custom_segments
    circle = Circle.new(centroid: @nyc, radius: 5000)
    @map.add(circle, segments: 6)
    assert_equal 7, @map.layers.first[:llas].length  # 6 + closing
  end

  # ── add bounding box ────────────────────────────────────────

  def test_add_bounding_box
    nw = LLA.new(lat: 42.0, lng: -77.5, alt: 0)
    se = LLA.new(lat: 38.5, lng: -71.0, alt: 0)
    bbox = BBox.new(nw: nw, se: se)
    @map.add(bbox)
    assert_equal 1, @map.size
    assert_equal :polygon, @map.layers.first[:type]
    assert_equal 5, @map.layers.first[:llas].length  # 4 corners + closing
  end

  # ── add feature ─────────────────────────────────────────────

  def test_add_feature_with_coordinate
    feat = Feature.new(label: "NYC", geometry: @nyc)
    @map.add(feat)
    assert_equal 1, @map.size
    assert_equal :point, @map.layers.first[:type]
    assert_equal "NYC", @map.layers.first[:style][:label]
  end

  def test_add_feature_with_polygon
    poly = Polygon.new(boundary: [@nyc, @philly, @dc])
    feat = Feature.new(label: "Triangle", geometry: poly, metadata: { zone: "east" })
    @map.add(feat)
    assert_equal 1, @map.size
    assert_equal :polygon, @map.layers.first[:type]
    assert_equal "Triangle", @map.layers.first[:style][:label]
  end

  def test_add_feature_explicit_style_overrides
    feat = Feature.new(label: "NYC", geometry: @nyc)
    @map.add(feat, label: "Override", color: "green")
    style = @map.layers.first[:style]
    assert_equal "Override", style[:label]
    assert_equal "green", style[:color]
  end

  # ── add_to_map mixin ────────────────────────────────────────

  def test_coordinate_add_to_map
    @nyc.add_to_map(@map, color: "red")
    assert_equal 1, @map.size
    assert_equal :point, @map.layers.first[:type]
  end

  def test_path_add_to_map
    path = Path.new(coordinates: [@nyc, @dc])
    path.add_to_map(@map, color: "blue")
    assert_equal 1, @map.size
    assert_equal :line, @map.layers.first[:type]
  end

  def test_polygon_add_to_map
    poly = Polygon.new(boundary: [@nyc, @philly, @dc])
    poly.add_to_map(@map, fill: "green")
    assert_equal 1, @map.size
    assert_equal :polygon, @map.layers.first[:type]
  end

  def test_feature_add_to_map
    feat = Feature.new(label: "NYC", geometry: @nyc)
    feat.add_to_map(@map)
    assert_equal 1, @map.size
  end

  # ── ENU/NED rejection ──────────────────────────────────────

  def test_rejects_enu
    enu = Geodetic::Coordinate::ENU.new(e: 100, n: 200, u: 50)
    assert_raises(ArgumentError) { @map.add(enu) }
  end

  def test_rejects_ned
    ned = Geodetic::Coordinate::NED.new(n: 200, e: 100, d: -50)
    assert_raises(ArgumentError) { @map.add(ned) }
  end

  # ── unsupported type ────────────────────────────────────────

  def test_rejects_unsupported_type
    assert_raises(ArgumentError) { @map.add("not a geodetic object") }
  end

  # ── chaining ────────────────────────────────────────────────

  def test_add_returns_self_for_chaining
    result = @map.add(@nyc).add(@dc)
    assert_equal @map, result
    assert_equal 2, @map.size
  end

  # ── clear ───────────────────────────────────────────────────

  def test_clear
    @map.add(@nyc).add(@dc)
    assert_equal 2, @map.size
    @map.clear
    assert @map.empty?
  end

  # ── render raises on base ───────────────────────────────────

  def test_base_render_raises
    assert_raises(NotImplementedError) { @map.render("out.png") }
  end
end

class MapLibGdGisTest < Minitest::Test
  LLA  = Geodetic::Coordinate::LLA
  BBox = Geodetic::Areas::BoundingBox

  def test_resolve_bbox_from_array
    map = Geodetic::Map::LibGdGis.new(bbox: [-74.5, 40.0, -73.5, 41.0], zoom: 12)
    assert_equal 0, map.size
  end

  def test_resolve_bbox_from_bounding_box
    nw = LLA.new(lat: 41.0, lng: -74.5, alt: 0)
    se = LLA.new(lat: 40.0, lng: -73.5, alt: 0)
    bbox = BBox.new(nw: nw, se: se)

    map = Geodetic::Map::LibGdGis.new(bbox: bbox, zoom: 12)
    assert_equal 0, map.size
  end

  def test_resolve_bbox_rejects_single_coordinate
    pt = LLA.new(lat: 40.0, lng: -74.0, alt: 0)
    assert_raises(ArgumentError) { Geodetic::Map::LibGdGis.new(bbox: pt) }
  end

  def test_nil_bbox_allowed
    map = Geodetic::Map::LibGdGis.new(zoom: 10)
    assert_equal 0, map.size
  end
end
