# frozen_string_literal: true

require "minitest/autorun"
require_relative "../lib/geodetic"

class GeoJSONTest < Minitest::Test
  def setup
    @seattle  = Geodetic::Coordinate::LLA.new(lat: 47.6205, lng: -122.3493, alt: 0.0)
    @portland = Geodetic::Coordinate::LLA.new(lat: 45.5152, lng: -122.6784, alt: 0.0)
    @sf       = Geodetic::Coordinate::LLA.new(lat: 37.7749, lng: -122.4194, alt: 100.0)
  end

  # --- Coordinate → Point ---

  def test_lla_to_geojson
    result = @seattle.to_geojson
    assert_equal "Point", result["type"]
    assert_equal [-122.3493, 47.6205], result["coordinates"]
  end

  def test_lla_to_geojson_with_altitude
    result = @sf.to_geojson
    assert_equal "Point", result["type"]
    assert_equal [-122.4194, 37.7749, 100.0], result["coordinates"]
  end

  def test_utm_to_geojson
    utm = @seattle.to_utm
    result = utm.to_geojson
    assert_equal "Point", result["type"]
    assert_in_delta(-122.3493, result["coordinates"][0], 0.001)
    assert_in_delta(47.6205, result["coordinates"][1], 0.001)
  end

  def test_ecef_to_geojson
    ecef = @seattle.to_ecef
    result = ecef.to_geojson
    assert_equal "Point", result["type"]
    assert_in_delta(-122.3493, result["coordinates"][0], 0.001)
    assert_in_delta(47.6205, result["coordinates"][1], 0.001)
  end

  def test_all_coordinate_systems_respond_to_to_geojson
    Geodetic::Coordinate.systems.each do |klass|
      assert klass.method_defined?(:to_geojson), "#{klass} should respond to to_geojson"
    end
  end

  def test_enu_to_geojson_raises
    enu = Geodetic::Coordinate::ENU.new(e: 100, n: 200, u: 10)
    assert_raises(ArgumentError) { enu.to_geojson }
  end

  def test_ned_to_geojson_raises
    ned = Geodetic::Coordinate::NED.new(n: 200, e: 100, d: -10)
    assert_raises(ArgumentError) { ned.to_geojson }
  end

  # --- Segment → LineString ---

  def test_segment_to_geojson
    seg = Geodetic::Segment.new(@seattle, @portland)
    result = seg.to_geojson
    assert_equal "LineString", result["type"]
    assert_equal 2, result["coordinates"].length
    assert_equal [-122.3493, 47.6205], result["coordinates"][0]
    assert_equal [-122.6784, 45.5152], result["coordinates"][1]
  end

  def test_segment_with_altitude
    seg = Geodetic::Segment.new(@seattle, @sf)
    result = seg.to_geojson
    coords = result["coordinates"]
    assert_equal 2, coords[0].length   # no alt (0.0)
    assert_equal 3, coords[1].length   # has alt (100.0)
  end

  # --- Path → LineString / Polygon ---

  def test_path_to_geojson
    path = Geodetic::Path.new(coordinates: [@seattle, @portland, @sf])
    result = path.to_geojson
    assert_equal "LineString", result["type"]
    assert_equal 3, result["coordinates"].length
  end

  def test_path_to_geojson_as_polygon
    a = Geodetic::Coordinate::LLA.new(lat: 47.0, lng: -122.0, alt: 0)
    b = Geodetic::Coordinate::LLA.new(lat: 46.0, lng: -121.0, alt: 0)
    c = Geodetic::Coordinate::LLA.new(lat: 46.0, lng: -123.0, alt: 0)
    path = Geodetic::Path.new(coordinates: [a, b, c])
    result = path.to_geojson(as: :polygon)
    assert_equal "Polygon", result["type"]
    ring = result["coordinates"][0]
    assert_equal ring.first, ring.last  # closed
    assert_equal 4, ring.length         # 3 points + closing
  end

  def test_empty_path_raises
    path = Geodetic::Path.new(coordinates: [])
    assert_raises(ArgumentError) { path.to_geojson }
  end

  def test_single_point_path_raises_for_line_string
    path = Geodetic::Path.new(coordinates: [@seattle])
    assert_raises(ArgumentError) { path.to_geojson }
  end

  def test_two_point_path_raises_for_polygon
    path = Geodetic::Path.new(coordinates: [@seattle, @portland])
    assert_raises(ArgumentError) { path.to_geojson(as: :polygon) }
  end

  # --- Polygon → Polygon ---

  def test_polygon_to_geojson
    a = Geodetic::Coordinate::LLA.new(lat: 47.0, lng: -122.0, alt: 0)
    b = Geodetic::Coordinate::LLA.new(lat: 46.0, lng: -121.0, alt: 0)
    c = Geodetic::Coordinate::LLA.new(lat: 46.0, lng: -123.0, alt: 0)
    poly = Geodetic::Areas::Polygon.new(boundary: [a, b, c])
    result = poly.to_geojson
    assert_equal "Polygon", result["type"]
    ring = result["coordinates"][0]
    assert_equal ring.first, ring.last  # closed
  end

  def test_triangle_to_geojson
    a = Geodetic::Coordinate::LLA.new(lat: 47.0, lng: -122.0, alt: 0)
    b = Geodetic::Coordinate::LLA.new(lat: 46.0, lng: -121.0, alt: 0)
    c = Geodetic::Coordinate::LLA.new(lat: 46.0, lng: -123.0, alt: 0)
    tri = Geodetic::Areas::Triangle.new(vertices: [a, b, c])
    result = tri.to_geojson
    assert_equal "Polygon", result["type"]
  end

  # --- Circle → Polygon ---

  def test_circle_to_geojson_default_segments
    circle = Geodetic::Areas::Circle.new(centroid: @seattle, radius: 1000.0)
    result = circle.to_geojson
    assert_equal "Polygon", result["type"]
    ring = result["coordinates"][0]
    assert_equal 33, ring.length  # 32 points + closing
    assert_equal ring.first, ring.last
  end

  def test_circle_to_geojson_custom_segments
    circle = Geodetic::Areas::Circle.new(centroid: @seattle, radius: 1000.0)
    result = circle.to_geojson(segments: 8)
    ring = result["coordinates"][0]
    assert_equal 9, ring.length  # 8 points + closing
  end

  # --- BoundingBox → Polygon ---

  def test_bounding_box_to_geojson
    bbox = Geodetic::Areas::BoundingBox.new(
      nw: Geodetic::Coordinate::LLA.new(lat: 48.0, lng: -123.0, alt: 0),
      se: Geodetic::Coordinate::LLA.new(lat: 46.0, lng: -121.0, alt: 0)
    )
    result = bbox.to_geojson
    assert_equal "Polygon", result["type"]
    ring = result["coordinates"][0]
    assert_equal 5, ring.length         # 4 corners + closing
    assert_equal ring.first, ring.last  # closed
  end

  # --- Feature → Feature ---

  def test_feature_with_point_geometry
    f = Geodetic::Feature.new(label: "Seattle", geometry: @seattle, metadata: { pop: 750_000 })
    result = f.to_geojson
    assert_equal "Feature", result["type"]
    assert_equal "Point", result["geometry"]["type"]
    assert_equal "Seattle", result["properties"]["name"]
    assert_equal 750_000, result["properties"]["pop"]
  end

  def test_feature_with_polygon_geometry
    a = Geodetic::Coordinate::LLA.new(lat: 47.0, lng: -122.0, alt: 0)
    b = Geodetic::Coordinate::LLA.new(lat: 46.0, lng: -121.0, alt: 0)
    c = Geodetic::Coordinate::LLA.new(lat: 46.0, lng: -123.0, alt: 0)
    poly = Geodetic::Areas::Polygon.new(boundary: [a, b, c])
    f = Geodetic::Feature.new(label: "Triangle Park", geometry: poly)
    result = f.to_geojson
    assert_equal "Feature", result["type"]
    assert_equal "Polygon", result["geometry"]["type"]
    assert_equal "Triangle Park", result["properties"]["name"]
  end

  def test_feature_with_path_geometry
    path = Geodetic::Path.new(coordinates: [@seattle, @portland])
    f = Geodetic::Feature.new(label: "Route", geometry: path)
    result = f.to_geojson
    assert_equal "Feature", result["type"]
    assert_equal "LineString", result["geometry"]["type"]
  end

  def test_feature_with_nil_label
    f = Geodetic::Feature.new(label: nil, geometry: @seattle)
    result = f.to_geojson
    refute result["properties"].key?("name")
  end

  def test_feature_with_symbol_metadata_keys
    f = Geodetic::Feature.new(label: "Test", geometry: @seattle, metadata: { color: "red", size: 5 })
    result = f.to_geojson
    assert_equal "red", result["properties"]["color"]
    assert_equal 5, result["properties"]["size"]
  end

  # --- GeoJSON class (FeatureCollection) ---

  def test_new_empty
    gj = Geodetic::GeoJSON.new
    assert gj.empty?
    assert_equal 0, gj.size
  end

  def test_new_with_objects
    gj = Geodetic::GeoJSON.new(@seattle, @portland)
    assert_equal 2, gj.size
  end

  def test_new_with_array
    gj = Geodetic::GeoJSON.new([@seattle, @portland])
    assert_equal 2, gj.size
  end

  def test_shovel_single_object
    gj = Geodetic::GeoJSON.new
    gj << @seattle
    assert_equal 1, gj.size
  end

  def test_shovel_array
    gj = Geodetic::GeoJSON.new
    gj << [@seattle, @portland]
    assert_equal 2, gj.size
  end

  def test_shovel_returns_self
    gj = Geodetic::GeoJSON.new
    assert_same gj, gj << @seattle
  end

  def test_delete
    gj = Geodetic::GeoJSON.new(@seattle, @portland)
    gj.delete(@seattle)
    assert_equal 1, gj.size
  end

  def test_clear
    gj = Geodetic::GeoJSON.new(@seattle, @portland)
    gj.clear
    assert gj.empty?
  end

  def test_enumerable
    gj = Geodetic::GeoJSON.new(@seattle, @portland)
    assert_equal [@seattle, @portland], gj.to_a
  end

  def test_to_h
    gj = Geodetic::GeoJSON.new(@seattle)
    h = gj.to_h
    assert_equal "FeatureCollection", h["type"]
    assert_equal 1, h["features"].length
    assert_equal "Feature", h["features"][0]["type"]
    assert_equal "Point", h["features"][0]["geometry"]["type"]
    assert_equal({}, h["features"][0]["properties"])
  end

  def test_to_h_with_feature
    f = Geodetic::Feature.new(label: "Seattle", geometry: @seattle, metadata: { state: "WA" })
    gj = Geodetic::GeoJSON.new(f)
    h = gj.to_h
    props = h["features"][0]["properties"]
    assert_equal "Seattle", props["name"]
    assert_equal "WA", props["state"]
  end

  def test_to_h_mixed_objects
    path = Geodetic::Path.new(coordinates: [@seattle, @portland])
    circle = Geodetic::Areas::Circle.new(centroid: @sf, radius: 500.0)
    feature = Geodetic::Feature.new(label: "City", geometry: @seattle)

    gj = Geodetic::GeoJSON.new
    gj << @portland
    gj << path
    gj << circle
    gj << feature

    h = gj.to_h
    assert_equal "FeatureCollection", h["type"]
    assert_equal 4, h["features"].length

    types = h["features"].map { |f| f["geometry"]["type"] }
    assert_equal ["Point", "LineString", "Polygon", "Point"], types
  end

  def test_to_json_compact
    gj = Geodetic::GeoJSON.new(@seattle)
    json = gj.to_json
    assert json.is_a?(String)
    refute json.include?("\n")
    parsed = JSON.parse(json)
    assert_equal "FeatureCollection", parsed["type"]
  end

  def test_to_json_pretty
    gj = Geodetic::GeoJSON.new(@seattle)
    json = gj.to_json(pretty: true)
    assert json.include?("\n")
    parsed = JSON.parse(json)
    assert_equal "FeatureCollection", parsed["type"]
  end

  def test_save_and_read_back
    gj = Geodetic::GeoJSON.new(@seattle, @portland)
    path = File.join(Dir.tmpdir, "geodetic_test_#{$$}.geojson")

    begin
      gj.save(path)
      content = File.read(path)
      parsed = JSON.parse(content)
      assert_equal "FeatureCollection", parsed["type"]
      assert_equal 2, parsed["features"].length
    ensure
      File.delete(path) if File.exist?(path)
    end
  end

  def test_save_pretty
    gj = Geodetic::GeoJSON.new(@seattle)
    path = File.join(Dir.tmpdir, "geodetic_test_pretty_#{$$}.geojson")

    begin
      gj.save(path, pretty: true)
      content = File.read(path)
      assert content.include?("\n")
    ensure
      File.delete(path) if File.exist?(path)
    end
  end

  def test_to_s
    gj = Geodetic::GeoJSON.new(@seattle, @portland)
    assert_equal "GeoJSON::FeatureCollection(2 features)", gj.to_s
  end

  def test_empty_collection_to_h
    gj = Geodetic::GeoJSON.new
    h = gj.to_h
    assert_equal "FeatureCollection", h["type"]
    assert_equal [], h["features"]
  end

  # --- Load / Parse ---

  def test_load_point
    result = save_and_load(Geodetic::GeoJSON.new(@seattle))
    assert_equal 1, result.length
    assert_instance_of Geodetic::Coordinate::LLA, result[0]
    assert_in_delta(-122.3493, result[0].lng, 1e-6)
    assert_in_delta(47.6205, result[0].lat, 1e-6)
  end

  def test_load_point_with_altitude
    result = save_and_load(Geodetic::GeoJSON.new(@sf))
    coord = result[0]
    assert_in_delta(100.0, coord.alt, 1e-6)
  end

  def test_load_segment
    seg = Geodetic::Segment.new(@seattle, @portland)
    result = save_and_load(Geodetic::GeoJSON.new(seg))
    assert_equal 1, result.length
    assert_instance_of Geodetic::Segment, result[0]
    assert_in_delta(@seattle.lat, result[0].start_point.lat, 1e-6)
    assert_in_delta(@portland.lat, result[0].end_point.lat, 1e-6)
  end

  def test_load_path
    path = Geodetic::Path.new(coordinates: [@seattle, @portland, @sf])
    result = save_and_load(Geodetic::GeoJSON.new(path))
    assert_equal 1, result.length
    assert_instance_of Geodetic::Path, result[0]
    assert_equal 3, result[0].size
  end

  def test_load_polygon
    a = Geodetic::Coordinate::LLA.new(lat: 47.0, lng: -122.0, alt: 0)
    b = Geodetic::Coordinate::LLA.new(lat: 46.0, lng: -121.0, alt: 0)
    c = Geodetic::Coordinate::LLA.new(lat: 46.0, lng: -123.0, alt: 0)
    poly = Geodetic::Areas::Polygon.new(boundary: [a, b, c])
    result = save_and_load(Geodetic::GeoJSON.new(poly))
    assert_equal 1, result.length
    assert_instance_of Geodetic::Areas::Polygon, result[0]
  end

  def test_load_feature_with_label
    f = Geodetic::Feature.new(label: "Seattle", geometry: @seattle)
    result = save_and_load(Geodetic::GeoJSON.new(f))
    assert_equal 1, result.length
    assert_instance_of Geodetic::Feature, result[0]
    assert_equal "Seattle", result[0].label
  end

  def test_load_feature_with_metadata
    f = Geodetic::Feature.new(label: "Seattle", geometry: @seattle, metadata: { state: "WA", pop: 750_000 })
    result = save_and_load(Geodetic::GeoJSON.new(f))
    feature = result[0]
    assert_instance_of Geodetic::Feature, feature
    assert_equal "Seattle", feature.label
    assert_equal "WA", feature.metadata[:state]
    assert_equal 750_000, feature.metadata[:pop]
  end

  def test_load_feature_empty_properties_returns_geometry
    result = save_and_load(Geodetic::GeoJSON.new(@seattle))
    assert_instance_of Geodetic::Coordinate::LLA, result[0]
  end

  def test_load_feature_with_path_geometry
    path = Geodetic::Path.new(coordinates: [@seattle, @portland])
    f = Geodetic::Feature.new(label: "Route", geometry: path, metadata: { mode: "driving" })
    result = save_and_load(Geodetic::GeoJSON.new(f))
    feature = result[0]
    assert_instance_of Geodetic::Feature, feature
    assert_equal "Route", feature.label
    assert_instance_of Geodetic::Segment, feature.geometry  # 2-point LineString → Segment
    assert_equal "driving", feature.metadata[:mode]
  end

  def test_load_mixed_collection
    f1 = Geodetic::Feature.new(label: "City", geometry: @seattle, metadata: { type: "city" })
    seg = Geodetic::Segment.new(@seattle, @portland)
    gj = Geodetic::GeoJSON.new(f1, seg, @sf)
    result = save_and_load(gj)
    assert_equal 3, result.length
    assert_instance_of Geodetic::Feature, result[0]
    assert_instance_of Geodetic::Segment, result[1]
    assert_instance_of Geodetic::Coordinate::LLA, result[2]
  end

  def test_load_empty_collection
    result = save_and_load(Geodetic::GeoJSON.new)
    assert_equal [], result
  end

  def test_roundtrip_preserves_coordinates
    gj = Geodetic::GeoJSON.new(@seattle, @portland, @sf)
    result = save_and_load(gj)
    result.zip([@seattle, @portland, @sf]).each do |loaded, original|
      assert_in_delta(original.lat, loaded.lat, 1e-6)
      assert_in_delta(original.lng, loaded.lng, 1e-6)
      assert_in_delta(original.alt, loaded.alt, 1e-6)
    end
  end

  def test_roundtrip_feature_with_polygon
    a = Geodetic::Coordinate::LLA.new(lat: 47.0, lng: -122.0, alt: 0)
    b = Geodetic::Coordinate::LLA.new(lat: 46.0, lng: -121.0, alt: 0)
    c = Geodetic::Coordinate::LLA.new(lat: 46.0, lng: -123.0, alt: 0)
    poly = Geodetic::Areas::Polygon.new(boundary: [a, b, c])
    f = Geodetic::Feature.new(label: "Park", geometry: poly, metadata: { area: 12.5 })
    result = save_and_load(Geodetic::GeoJSON.new(f))
    feature = result[0]
    assert_instance_of Geodetic::Feature, feature
    assert_equal "Park", feature.label
    assert_instance_of Geodetic::Areas::Polygon, feature.geometry
    assert_equal 12.5, feature.metadata[:area]
  end

  def test_parse_bare_point
    data = { "type" => "Point", "coordinates" => [-122.35, 47.62] }
    result = Geodetic::GeoJSON.parse(data)
    assert_equal 1, result.length
    assert_instance_of Geodetic::Coordinate::LLA, result[0]
  end

  def test_parse_geometry_collection
    data = {
      "type" => "GeometryCollection",
      "geometries" => [
        { "type" => "Point", "coordinates" => [-122.35, 47.62] },
        { "type" => "Point", "coordinates" => [-122.68, 45.52] }
      ]
    }
    result = Geodetic::GeoJSON.parse(data)
    assert_equal 2, result.length
    assert result.all? { |r| r.is_a?(Geodetic::Coordinate::LLA) }
  end

  def test_parse_multi_point
    data = {
      "type" => "Feature",
      "geometry" => {
        "type" => "MultiPoint",
        "coordinates" => [[-122.35, 47.62], [-122.68, 45.52]]
      },
      "properties" => {}
    }
    result = Geodetic::GeoJSON.parse(data)
    assert_equal 2, result.length
  end

  def test_parse_feature_name_only
    data = {
      "type" => "Feature",
      "geometry" => { "type" => "Point", "coordinates" => [-122.35, 47.62] },
      "properties" => { "name" => "Seattle" }
    }
    result = Geodetic::GeoJSON.parse(data)
    assert_equal 1, result.length
    assert_instance_of Geodetic::Feature, result[0]
    assert_equal "Seattle", result[0].label
    assert_equal({}, result[0].metadata)
  end

  private

  def save_and_load(gj)
    path = File.join(Dir.tmpdir, "geodetic_roundtrip_#{$$}.geojson")
    gj.save(path)
    Geodetic::GeoJSON.load(path)
  ensure
    File.delete(path) if File.exist?(path)
  end
end
