# frozen_string_literal: true

require "minitest/autorun"
require_relative "../lib/geodetic"

class WktTest < Minitest::Test
  def setup
    @seattle  = Geodetic::Coordinate::LLA.new(lat: 47.6205, lng: -122.3493, alt: 0.0)
    @portland = Geodetic::Coordinate::LLA.new(lat: 45.5152, lng: -122.6784, alt: 0.0)
    @sf       = Geodetic::Coordinate::LLA.new(lat: 37.7749, lng: -122.4194, alt: 100.0)
  end

  # --- Coordinate → POINT ---

  def test_lla_to_wkt
    result = @seattle.to_wkt
    assert_equal "POINT(-122.3493 47.6205)", result
  end

  def test_lla_to_wkt_with_altitude
    result = @sf.to_wkt
    assert_equal "POINT Z(-122.4194 37.7749 100.0)", result
  end

  def test_lla_to_wkt_with_precision
    result = @seattle.to_wkt(precision: 2)
    assert_equal "POINT(-122.35 47.62)", result
  end

  def test_lla_to_wkt_with_srid
    result = @seattle.to_wkt(srid: 4326)
    assert_equal "SRID=4326;POINT(-122.3493 47.6205)", result
  end

  def test_lla_to_wkt_with_srid_and_altitude
    result = @sf.to_wkt(srid: 4326)
    assert_equal "SRID=4326;POINT Z(-122.4194 37.7749 100.0)", result
  end

  def test_utm_to_wkt
    utm = @seattle.to_utm
    result = utm.to_wkt
    assert_match(/\APOINT\(/, result)
    # Should round-trip through LLA
    parsed = Geodetic::WKT.parse(result)
    assert_in_delta(@seattle.lat, parsed.lat, 0.001)
    assert_in_delta(@seattle.lng, parsed.lng, 0.001)
  end

  def test_ecef_to_wkt
    ecef = @seattle.to_ecef
    result = ecef.to_wkt
    assert_match(/\APOINT/, result)
  end

  def test_all_coordinate_systems_respond_to_to_wkt
    Geodetic::Coordinate.systems.each do |klass|
      assert klass.method_defined?(:to_wkt), "#{klass} should respond to to_wkt"
    end
  end

  def test_enu_to_wkt_raises
    enu = Geodetic::Coordinate::ENU.new(e: 100, n: 200, u: 10)
    assert_raises(ArgumentError) { enu.to_wkt }
  end

  def test_ned_to_wkt_raises
    ned = Geodetic::Coordinate::NED.new(n: 200, e: 100, d: -10)
    assert_raises(ArgumentError) { ned.to_wkt }
  end

  # --- Segment → LINESTRING ---

  def test_segment_to_wkt
    seg = Geodetic::Segment.new(@seattle, @portland)
    result = seg.to_wkt
    assert_equal "LINESTRING(-122.3493 47.6205, -122.6784 45.5152)", result
  end

  def test_segment_with_altitude_uses_z
    seg = Geodetic::Segment.new(@seattle, @sf)
    result = seg.to_wkt
    assert_match(/\ALINESTRING Z\(/, result)
    # When one point has altitude, all points get Z
    assert_match(/-122\.3493 47\.6205 0\.0/, result)
    assert_match(/-122\.4194 37\.7749 100\.0/, result)
  end

  def test_segment_with_srid
    seg = Geodetic::Segment.new(@seattle, @portland)
    result = seg.to_wkt(srid: 4326)
    assert result.start_with?("SRID=4326;")
  end

  # --- Path → LINESTRING / POLYGON ---

  def test_path_to_wkt
    path = Geodetic::Path.new(coordinates: [@seattle, @portland, @sf])
    result = path.to_wkt
    assert_match(/\ALINESTRING Z?\(/, result)
  end

  def test_path_to_wkt_as_polygon
    a = Geodetic::Coordinate::LLA.new(lat: 47.0, lng: -122.0, alt: 0)
    b = Geodetic::Coordinate::LLA.new(lat: 46.0, lng: -121.0, alt: 0)
    c = Geodetic::Coordinate::LLA.new(lat: 46.0, lng: -123.0, alt: 0)
    path = Geodetic::Path.new(coordinates: [a, b, c])
    result = path.to_wkt(as: :polygon)
    assert_match(/\APOLYGON\(\(/, result)
    # Should be auto-closed
    coords = result[/\((.+)\)/, 1]
    assert coords.end_with?("-122.0 47.0)")  # closing = first point
  end

  def test_empty_path_raises
    path = Geodetic::Path.new(coordinates: [])
    assert_raises(ArgumentError) { path.to_wkt }
  end

  def test_single_point_path_raises
    path = Geodetic::Path.new(coordinates: [@seattle])
    assert_raises(ArgumentError) { path.to_wkt }
  end

  def test_two_point_path_raises_for_polygon
    path = Geodetic::Path.new(coordinates: [@seattle, @portland])
    assert_raises(ArgumentError) { path.to_wkt(as: :polygon) }
  end

  # --- Polygon → POLYGON ---

  def test_polygon_to_wkt
    a = Geodetic::Coordinate::LLA.new(lat: 47.0, lng: -122.0, alt: 0)
    b = Geodetic::Coordinate::LLA.new(lat: 46.0, lng: -121.0, alt: 0)
    c = Geodetic::Coordinate::LLA.new(lat: 46.0, lng: -123.0, alt: 0)
    poly = Geodetic::Areas::Polygon.new(boundary: [a, b, c])
    result = poly.to_wkt
    assert_match(/\APOLYGON\(\(/, result)
  end

  def test_triangle_to_wkt
    a = Geodetic::Coordinate::LLA.new(lat: 47.0, lng: -122.0, alt: 0)
    b = Geodetic::Coordinate::LLA.new(lat: 46.0, lng: -121.0, alt: 0)
    c = Geodetic::Coordinate::LLA.new(lat: 46.0, lng: -123.0, alt: 0)
    tri = Geodetic::Areas::Triangle.new(vertices: [a, b, c])
    result = tri.to_wkt
    assert_match(/\APOLYGON\(\(/, result)
  end

  # --- Circle → POLYGON ---

  def test_circle_to_wkt
    circle = Geodetic::Areas::Circle.new(centroid: @seattle, radius: 1000.0)
    result = circle.to_wkt
    assert_match(/\APOLYGON\(\(/, result)
  end

  def test_circle_to_wkt_custom_segments
    circle = Geodetic::Areas::Circle.new(centroid: @seattle, radius: 1000.0)
    result = circle.to_wkt(segments: 8)
    assert_match(/\APOLYGON\(\(/, result)
    # 8 segments + closing point = 9 coordinate pairs
    coords = result[/\(\((.+)\)\)/, 1]
    assert_equal 9, coords.split(",").length
  end

  # --- BoundingBox → POLYGON ---

  def test_bounding_box_to_wkt
    bbox = Geodetic::Areas::BoundingBox.new(
      nw: Geodetic::Coordinate::LLA.new(lat: 48.0, lng: -123.0, alt: 0),
      se: Geodetic::Coordinate::LLA.new(lat: 46.0, lng: -121.0, alt: 0)
    )
    result = bbox.to_wkt
    assert_match(/\APOLYGON\(\(/, result)
    # 4 corners + closing = 5 points
    coords = result[/\(\((.+)\)\)/, 1]
    assert_equal 5, coords.split(",").length
  end

  # --- Feature delegates ---

  def test_feature_to_wkt
    f = Geodetic::Feature.new(label: "Seattle", geometry: @seattle, metadata: { pop: 750_000 })
    result = f.to_wkt
    assert_equal "POINT(-122.3493 47.6205)", result
  end

  def test_feature_to_wkt_with_srid
    f = Geodetic::Feature.new(label: "Seattle", geometry: @seattle)
    result = f.to_wkt(srid: 4326)
    assert_equal "SRID=4326;POINT(-122.3493 47.6205)", result
  end

  # --- Parse ---

  def test_parse_point
    result = Geodetic::WKT.parse("POINT(-122.3493 47.6205)")
    assert_instance_of Geodetic::Coordinate::LLA, result
    assert_in_delta(-122.3493, result.lng, 1e-6)
    assert_in_delta(47.6205, result.lat, 1e-6)
    assert_in_delta(0.0, result.alt, 1e-6)
  end

  def test_parse_point_z
    result = Geodetic::WKT.parse("POINT Z(-122.4194 37.7749 100.0)")
    assert_in_delta(100.0, result.alt, 1e-6)
  end

  def test_parse_linestring_2_points
    result = Geodetic::WKT.parse("LINESTRING(-122.3493 47.6205, -122.6784 45.5152)")
    assert_instance_of Geodetic::Segment, result
    assert_in_delta(47.6205, result.start_point.lat, 1e-6)
    assert_in_delta(45.5152, result.end_point.lat, 1e-6)
  end

  def test_parse_linestring_3_points
    result = Geodetic::WKT.parse("LINESTRING(-122.35 47.62, -122.68 45.52, -122.42 37.77)")
    assert_instance_of Geodetic::Path, result
    assert_equal 3, result.size
  end

  def test_parse_linestring_z
    result = Geodetic::WKT.parse("LINESTRING Z(-122.35 47.62 0.0, -122.42 37.77 100.0)")
    assert_instance_of Geodetic::Segment, result
    assert_in_delta(100.0, result.end_point.alt, 1e-6)
  end

  def test_parse_polygon
    result = Geodetic::WKT.parse("POLYGON((-122.0 47.0, -121.0 46.0, -123.0 46.0, -122.0 47.0))")
    assert_instance_of Geodetic::Areas::Polygon, result
  end

  def test_parse_polygon_z
    result = Geodetic::WKT.parse("POLYGON Z((-122.0 47.0 10.0, -121.0 46.0 20.0, -123.0 46.0 30.0, -122.0 47.0 10.0))")
    assert_instance_of Geodetic::Areas::Polygon, result
  end

  def test_parse_multipoint
    result = Geodetic::WKT.parse("MULTIPOINT((-122.35 47.62), (-122.68 45.52))")
    assert_instance_of Array, result
    assert_equal 2, result.length
    assert result.all? { |r| r.is_a?(Geodetic::Coordinate::LLA) }
  end

  def test_parse_multilinestring
    result = Geodetic::WKT.parse("MULTILINESTRING((-122.35 47.62, -122.68 45.52), (-122.42 37.77, -118.24 34.05))")
    assert_instance_of Array, result
    assert_equal 2, result.length
    assert result.all? { |r| r.is_a?(Geodetic::Segment) }
  end

  def test_parse_multipolygon
    result = Geodetic::WKT.parse(
      "MULTIPOLYGON(((-122.0 47.0, -121.0 46.0, -123.0 46.0, -122.0 47.0)), " \
      "((-118.0 34.0, -117.0 33.0, -119.0 33.0, -118.0 34.0)))"
    )
    assert_instance_of Array, result
    assert_equal 2, result.length
    assert result.all? { |r| r.is_a?(Geodetic::Areas::Polygon) }
  end

  def test_parse_geometry_collection
    result = Geodetic::WKT.parse(
      "GEOMETRYCOLLECTION(POINT(-122.35 47.62), LINESTRING(-122.35 47.62, -122.68 45.52))"
    )
    assert_instance_of Array, result
    assert_equal 2, result.length
    assert_instance_of Geodetic::Coordinate::LLA, result[0]
    assert_instance_of Geodetic::Segment, result[1]
  end

  def test_parse_with_srid
    obj, srid = Geodetic::WKT.parse_with_srid("SRID=4326;POINT(-122.3493 47.6205)")
    assert_equal 4326, srid
    assert_instance_of Geodetic::Coordinate::LLA, obj
    assert_in_delta(-122.3493, obj.lng, 1e-6)
  end

  def test_parse_with_srid_no_srid
    obj, srid = Geodetic::WKT.parse_with_srid("POINT(-122.3493 47.6205)")
    assert_nil srid
    assert_instance_of Geodetic::Coordinate::LLA, obj
  end

  def test_parse_unknown_type_raises
    assert_raises(ArgumentError) { Geodetic::WKT.parse("CURVE(1 2, 3 4)") }
  end

  # --- Roundtrip ---

  def test_roundtrip_point
    wkt = @seattle.to_wkt
    parsed = Geodetic::WKT.parse(wkt)
    assert_in_delta(@seattle.lat, parsed.lat, 1e-6)
    assert_in_delta(@seattle.lng, parsed.lng, 1e-6)
  end

  def test_roundtrip_point_with_altitude
    wkt = @sf.to_wkt
    parsed = Geodetic::WKT.parse(wkt)
    assert_in_delta(@sf.lat, parsed.lat, 1e-6)
    assert_in_delta(@sf.lng, parsed.lng, 1e-6)
    assert_in_delta(@sf.alt, parsed.alt, 1e-6)
  end

  def test_roundtrip_segment
    seg = Geodetic::Segment.new(@seattle, @portland)
    wkt = seg.to_wkt
    parsed = Geodetic::WKT.parse(wkt)
    assert_instance_of Geodetic::Segment, parsed
    assert_in_delta(@seattle.lat, parsed.start_point.lat, 1e-6)
    assert_in_delta(@portland.lat, parsed.end_point.lat, 1e-6)
  end

  def test_roundtrip_path
    path = Geodetic::Path.new(coordinates: [@seattle, @portland, @sf])
    wkt = path.to_wkt
    parsed = Geodetic::WKT.parse(wkt)
    assert_instance_of Geodetic::Path, parsed
    assert_equal 3, parsed.size
  end

  def test_roundtrip_polygon
    a = Geodetic::Coordinate::LLA.new(lat: 47.0, lng: -122.0, alt: 0)
    b = Geodetic::Coordinate::LLA.new(lat: 46.0, lng: -121.0, alt: 0)
    c = Geodetic::Coordinate::LLA.new(lat: 46.0, lng: -123.0, alt: 0)
    poly = Geodetic::Areas::Polygon.new(boundary: [a, b, c])
    wkt = poly.to_wkt
    parsed = Geodetic::WKT.parse(wkt)
    assert_instance_of Geodetic::Areas::Polygon, parsed
  end

  def test_roundtrip_srid
    wkt = @seattle.to_wkt(srid: 4326)
    obj, srid = Geodetic::WKT.parse_with_srid(wkt)
    assert_equal 4326, srid
    assert_in_delta(@seattle.lat, obj.lat, 1e-6)
  end

  def test_roundtrip_bounding_box
    bbox = Geodetic::Areas::BoundingBox.new(
      nw: Geodetic::Coordinate::LLA.new(lat: 48.0, lng: -123.0, alt: 0),
      se: Geodetic::Coordinate::LLA.new(lat: 46.0, lng: -121.0, alt: 0)
    )
    wkt = bbox.to_wkt
    parsed = Geodetic::WKT.parse(wkt)
    assert_instance_of Geodetic::Areas::Polygon, parsed
  end

  # --- File I/O ---

  def test_save_and_load
    path = File.join(Dir.tmpdir, "geodetic_wkt_test_#{$$}.wkt")
    seg = Geodetic::Segment.new(@seattle, @portland)
    poly = Geodetic::Areas::Polygon.new(boundary: [
      Geodetic::Coordinate::LLA.new(lat: 47.0, lng: -122.0, alt: 0),
      Geodetic::Coordinate::LLA.new(lat: 46.0, lng: -121.0, alt: 0),
      Geodetic::Coordinate::LLA.new(lat: 46.0, lng: -123.0, alt: 0)
    ])

    begin
      Geodetic::WKT.save!(path, @seattle, seg, poly)
      lines = File.readlines(path, chomp: true)
      assert_equal 3, lines.length
      assert_match(/\APOINT\(/, lines[0])
      assert_match(/\ALINESTRING\(/, lines[1])
      assert_match(/\APOLYGON\(/, lines[2])

      objects = Geodetic::WKT.load(path)
      assert_equal 3, objects.length
      assert_instance_of Geodetic::Coordinate::LLA, objects[0]
      assert_instance_of Geodetic::Segment, objects[1]
      assert_instance_of Geodetic::Areas::Polygon, objects[2]
      assert_in_delta(@seattle.lat, objects[0].lat, 1e-6)
    ensure
      File.delete(path) if File.exist?(path)
    end
  end

  def test_save_with_srid
    path = File.join(Dir.tmpdir, "geodetic_wkt_srid_#{$$}.wkt")
    begin
      Geodetic::WKT.save!(path, @seattle, @portland, srid: 4326)
      lines = File.readlines(path, chomp: true)
      assert lines.all? { |l| l.start_with?("SRID=4326;") }
    ensure
      File.delete(path) if File.exist?(path)
    end
  end

  def test_save_with_array
    path = File.join(Dir.tmpdir, "geodetic_wkt_arr_#{$$}.wkt")
    begin
      Geodetic::WKT.save!(path, [@seattle, @portland])
      objects = Geodetic::WKT.load(path)
      assert_equal 2, objects.length
    ensure
      File.delete(path) if File.exist?(path)
    end
  end

  def test_load_skips_blank_lines
    path = File.join(Dir.tmpdir, "geodetic_wkt_blank_#{$$}.wkt")
    begin
      File.write(path, "POINT(-122.3493 47.6205)\n\n  \nPOINT(-122.6784 45.5152)\n")
      objects = Geodetic::WKT.load(path)
      assert_equal 2, objects.length
    ensure
      File.delete(path) if File.exist?(path)
    end
  end

  def test_file_roundtrip
    path = File.join(Dir.tmpdir, "geodetic_wkt_rt_#{$$}.wkt")
    seg = Geodetic::Segment.new(@seattle, @portland)
    begin
      Geodetic::WKT.save!(path, @seattle, @sf, seg)
      objects = Geodetic::WKT.load(path)

      assert_in_delta(@seattle.lat, objects[0].lat, 1e-6)
      assert_in_delta(@sf.alt, objects[1].alt, 1e-6)
      assert_instance_of Geodetic::Segment, objects[2]
    ensure
      File.delete(path) if File.exist?(path)
    end
  end

  # --- Z-dimension consistency ---

  def test_z_consistency_all_points_get_z_when_any_has_altitude
    # Seattle has alt=0, SF has alt=100 → both should get Z
    path = Geodetic::Path.new(coordinates: [@seattle, @sf])
    wkt = path.to_wkt
    assert_match(/\ALINESTRING Z\(/, wkt)
    # Seattle should show 0.0 for altitude
    assert_match(/-122\.3493 47\.6205 0\.0/, wkt)
  end

  def test_no_z_when_all_altitudes_zero
    path = Geodetic::Path.new(coordinates: [@seattle, @portland])
    wkt = path.to_wkt
    assert_match(/\ALINESTRING\(/, wkt)
    refute_match(/LINESTRING Z/, wkt)
  end
end
