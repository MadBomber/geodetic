# frozen_string_literal: true

require "minitest/autorun"
require_relative "../lib/geodetic"

class WkbTest < Minitest::Test
  def setup
    @seattle  = Geodetic::Coordinate::LLA.new(lat: 47.6205, lng: -122.3493, alt: 0.0)
    @portland = Geodetic::Coordinate::LLA.new(lat: 45.5152, lng: -122.6784, alt: 0.0)
    @sf       = Geodetic::Coordinate::LLA.new(lat: 37.7749, lng: -122.4194, alt: 100.0)
  end

  # --- Known hex fixtures ---

  POINT_1_2_HEX = "0101000000000000000000f03f0000000000000040"
  LINESTRING_HEX = "010200000002000000000000000000f03f000000000000004000000000000008400000000000001040"
  POLYGON_HEX = "01030000000100000004000000000000000000f03f00000000000000400000000000000840000000000000104000000000000014400000000000001840000000000000f03f0000000000000040"
  MULTIPOINT_HEX = "0104000000020000000101000000000000000000f03f0000000000000040010100000000000000000008400000000000001040"
  GEOM_COLLECTION_HEX = "0107000000020000000101000000000000000000f03f0000000000000040010200000002000000000000000000f03f000000000000004000000000000008400000000000001040"
  SEATTLE_POINT_HEX = "01010000008a1f63ee5a965ec08195438b6ccf4740"
  SEATTLE_EWKB_HEX = "0101000020e61000008a1f63ee5a965ec08195438b6ccf4740"
  SEATTLE_LINESTRING_HEX = "0102000000020000008a1f63ee5a965ec08195438b6ccf4740cf66d5e76aab5ec01973d712f2c14640"
  SPACE_NEEDLE_Z_HEX = "01e90300008a1f63ee5a965ec08195438b6ccf47400000000000006740"

  # --- Coordinate → POINT ---

  def test_lla_to_wkb_hex
    assert_equal SEATTLE_POINT_HEX, @seattle.to_wkb_hex
  end

  def test_lla_to_wkb_returns_binary
    result = @seattle.to_wkb
    assert_equal Encoding::ASCII_8BIT, result.encoding
    assert_equal 21, result.bytesize  # 1 + 4 + 8 + 8
  end

  def test_lla_to_wkb_with_altitude
    space_needle = Geodetic::Coordinate::LLA.new(lat: 47.6205, lng: -122.3493, alt: 184.0)
    hex = space_needle.to_wkb_hex
    assert_equal SPACE_NEEDLE_Z_HEX, hex
    assert_equal 29, space_needle.to_wkb.bytesize  # 1 + 4 + 8*3
  end

  def test_lla_to_wkb_with_srid
    assert_equal SEATTLE_EWKB_HEX, @seattle.to_wkb_hex(srid: 4326)
  end

  def test_utm_to_wkb
    utm = @seattle.to_utm
    result = Geodetic::WKB.parse(utm.to_wkb)
    assert_in_delta(@seattle.lat, result.lat, 0.001)
    assert_in_delta(@seattle.lng, result.lng, 0.001)
  end

  def test_all_coordinate_systems_respond_to_to_wkb
    Geodetic::Coordinate.systems.each do |klass|
      assert klass.method_defined?(:to_wkb), "#{klass} should respond to to_wkb"
      assert klass.method_defined?(:to_wkb_hex), "#{klass} should respond to to_wkb_hex"
    end
  end

  def test_enu_to_wkb_raises
    enu = Geodetic::Coordinate::ENU.new(e: 100, n: 200, u: 10)
    assert_raises(ArgumentError) { enu.to_wkb }
  end

  def test_ned_to_wkb_raises
    ned = Geodetic::Coordinate::NED.new(n: 200, e: 100, d: -10)
    assert_raises(ArgumentError) { ned.to_wkb }
  end

  # --- Segment → LINESTRING ---

  def test_segment_to_wkb_hex
    seg = Geodetic::Segment.new(@seattle, @portland)
    assert_equal SEATTLE_LINESTRING_HEX, seg.to_wkb_hex
  end

  def test_segment_with_altitude_uses_z
    seg = Geodetic::Segment.new(@seattle, @sf)
    wkb = seg.to_wkb
    # Type should be LineString Z = 1002 = 0xEA030000 LE
    type_bytes = wkb[1, 4].unpack1("V")
    assert_equal 1002, type_bytes
    # Both points get Z (3 doubles each) + header + count = 1+4+4+24+24 = 57
    assert_equal 57, wkb.bytesize
  end

  def test_segment_with_srid
    seg = Geodetic::Segment.new(@seattle, @portland)
    hex = seg.to_wkb_hex(srid: 4326)
    # SRID flag set in type
    assert hex.start_with?("01")
    type_int = [hex[2, 8]].pack("H*").unpack1("V")
    assert (type_int & 0x20000000) != 0
  end

  # --- Path → LINESTRING / POLYGON ---

  def test_path_to_wkb
    path = Geodetic::Path.new(coordinates: [@seattle, @portland, @sf])
    wkb = path.to_wkb
    type = wkb[1, 4].unpack1("V")
    # Should be LineString Z (1002) because SF has altitude
    assert_equal 1002, type
  end

  def test_path_to_wkb_as_polygon
    a = Geodetic::Coordinate::LLA.new(lat: 47.0, lng: -122.0, alt: 0)
    b = Geodetic::Coordinate::LLA.new(lat: 46.0, lng: -121.0, alt: 0)
    c = Geodetic::Coordinate::LLA.new(lat: 46.0, lng: -123.0, alt: 0)
    path = Geodetic::Path.new(coordinates: [a, b, c])
    wkb = path.to_wkb(as: :polygon)
    type = wkb[1, 4].unpack1("V")
    assert_equal 3, type  # Polygon
  end

  def test_path_to_wkb_hex
    a = Geodetic::Coordinate::LLA.new(lat: 47.0, lng: -122.0, alt: 0)
    b = Geodetic::Coordinate::LLA.new(lat: 46.0, lng: -121.0, alt: 0)
    path = Geodetic::Path.new(coordinates: [a, b])
    hex = path.to_wkb_hex
    assert hex.is_a?(String)
    assert hex.match?(/\A[0-9a-f]+\z/)
  end

  def test_empty_path_raises
    path = Geodetic::Path.new(coordinates: [])
    assert_raises(ArgumentError) { path.to_wkb }
  end

  def test_single_point_path_raises
    path = Geodetic::Path.new(coordinates: [@seattle])
    assert_raises(ArgumentError) { path.to_wkb }
  end

  def test_two_point_path_raises_for_polygon
    path = Geodetic::Path.new(coordinates: [@seattle, @portland])
    assert_raises(ArgumentError) { path.to_wkb(as: :polygon) }
  end

  # --- Areas → POLYGON ---

  def test_polygon_to_wkb
    a = Geodetic::Coordinate::LLA.new(lat: 47.0, lng: -122.0, alt: 0)
    b = Geodetic::Coordinate::LLA.new(lat: 46.0, lng: -121.0, alt: 0)
    c = Geodetic::Coordinate::LLA.new(lat: 46.0, lng: -123.0, alt: 0)
    poly = Geodetic::Areas::Polygon.new(boundary: [a, b, c])
    wkb = poly.to_wkb
    type = wkb[1, 4].unpack1("V")
    assert_equal 3, type  # Polygon
  end

  def test_triangle_to_wkb
    a = Geodetic::Coordinate::LLA.new(lat: 47.0, lng: -122.0, alt: 0)
    b = Geodetic::Coordinate::LLA.new(lat: 46.0, lng: -121.0, alt: 0)
    c = Geodetic::Coordinate::LLA.new(lat: 46.0, lng: -123.0, alt: 0)
    tri = Geodetic::Areas::Triangle.new(vertices: [a, b, c])
    wkb = tri.to_wkb
    type = wkb[1, 4].unpack1("V")
    assert_equal 3, type
  end

  def test_circle_to_wkb
    circle = Geodetic::Areas::Circle.new(centroid: @seattle, radius: 1000.0)
    wkb = circle.to_wkb
    type = wkb[1, 4].unpack1("V")
    assert_equal 3, type  # Polygon
    # Default 32 segments + closing = 33 points, each 16 bytes + ring header
  end

  def test_circle_to_wkb_custom_segments
    circle = Geodetic::Areas::Circle.new(centroid: @seattle, radius: 1000.0)
    wkb8 = circle.to_wkb(segments: 8)
    wkb32 = circle.to_wkb
    assert wkb8.bytesize < wkb32.bytesize
  end

  def test_bounding_box_to_wkb
    bbox = Geodetic::Areas::BoundingBox.new(
      nw: Geodetic::Coordinate::LLA.new(lat: 48.0, lng: -123.0, alt: 0),
      se: Geodetic::Coordinate::LLA.new(lat: 46.0, lng: -121.0, alt: 0)
    )
    wkb = bbox.to_wkb
    type = wkb[1, 4].unpack1("V")
    assert_equal 3, type  # Polygon
  end

  # --- Feature delegates ---

  def test_feature_to_wkb
    f = Geodetic::Feature.new(label: "Seattle", geometry: @seattle, metadata: { pop: 750_000 })
    assert_equal SEATTLE_POINT_HEX, f.to_wkb_hex
  end

  def test_feature_to_wkb_with_srid
    f = Geodetic::Feature.new(label: "Seattle", geometry: @seattle)
    assert_equal SEATTLE_EWKB_HEX, f.to_wkb_hex(srid: 4326)
  end

  # --- Parse known fixtures ---

  def test_parse_point_1_2
    result = Geodetic::WKB.parse(POINT_1_2_HEX)
    assert_instance_of Geodetic::Coordinate::LLA, result
    assert_in_delta(1.0, result.lng, 1e-10)
    assert_in_delta(2.0, result.lat, 1e-10)
  end

  def test_parse_seattle_point
    result = Geodetic::WKB.parse(SEATTLE_POINT_HEX)
    assert_in_delta(-122.3493, result.lng, 1e-6)
    assert_in_delta(47.6205, result.lat, 1e-6)
  end

  def test_parse_point_z
    result = Geodetic::WKB.parse(SPACE_NEEDLE_Z_HEX)
    assert_in_delta(-122.3493, result.lng, 1e-6)
    assert_in_delta(47.6205, result.lat, 1e-6)
    assert_in_delta(184.0, result.alt, 1e-6)
  end

  def test_parse_linestring
    result = Geodetic::WKB.parse(LINESTRING_HEX)
    assert_instance_of Geodetic::Segment, result  # 2 points
    assert_in_delta(1.0, result.start_point.lng, 1e-10)
    assert_in_delta(2.0, result.start_point.lat, 1e-10)
    assert_in_delta(3.0, result.end_point.lng, 1e-10)
    assert_in_delta(4.0, result.end_point.lat, 1e-10)
  end

  def test_parse_polygon
    result = Geodetic::WKB.parse(POLYGON_HEX)
    assert_instance_of Geodetic::Areas::Polygon, result
  end

  def test_parse_multipoint
    result = Geodetic::WKB.parse(MULTIPOINT_HEX)
    assert_instance_of Array, result
    assert_equal 2, result.length
    assert result.all? { |r| r.is_a?(Geodetic::Coordinate::LLA) }
    assert_in_delta(1.0, result[0].lng, 1e-10)
    assert_in_delta(3.0, result[1].lng, 1e-10)
  end

  def test_parse_geometry_collection
    result = Geodetic::WKB.parse(GEOM_COLLECTION_HEX)
    assert_instance_of Array, result
    assert_equal 2, result.length
    assert_instance_of Geodetic::Coordinate::LLA, result[0]
    assert_instance_of Geodetic::Segment, result[1]
  end

  def test_parse_ewkb_srid
    result = Geodetic::WKB.parse(SEATTLE_EWKB_HEX)
    assert_instance_of Geodetic::Coordinate::LLA, result
    assert_in_delta(-122.3493, result.lng, 1e-6)
  end

  def test_parse_with_srid
    obj, srid = Geodetic::WKB.parse_with_srid(SEATTLE_EWKB_HEX)
    assert_equal 4326, srid
    assert_in_delta(-122.3493, obj.lng, 1e-6)
  end

  def test_parse_with_srid_no_srid
    obj, srid = Geodetic::WKB.parse_with_srid(SEATTLE_POINT_HEX)
    assert_nil srid
    assert_instance_of Geodetic::Coordinate::LLA, obj
  end

  def test_parse_binary_input
    binary = [@seattle.to_wkb_hex].pack("H*")
    result = Geodetic::WKB.parse(binary)
    assert_in_delta(@seattle.lat, result.lat, 1e-6)
  end

  def test_parse_big_endian_point
    # Build a big-endian POINT(1 2): byte_order=0x00, type=0x00000001, x=1.0, y=2.0
    be_wkb = [0x00].pack("C") + [1].pack("N") + [1.0, 2.0].pack("G2")
    result = Geodetic::WKB.parse(be_wkb)
    assert_in_delta(1.0, result.lng, 1e-10)
    assert_in_delta(2.0, result.lat, 1e-10)
  end

  def test_parse_unknown_type_raises
    bad_hex = "0108000000" + "00" * 16
    assert_raises(ArgumentError) { Geodetic::WKB.parse(bad_hex) }
  end

  # --- Roundtrip ---

  def test_roundtrip_point
    wkb = @seattle.to_wkb
    parsed = Geodetic::WKB.parse(wkb)
    assert_in_delta(@seattle.lat, parsed.lat, 1e-10)
    assert_in_delta(@seattle.lng, parsed.lng, 1e-10)
  end

  def test_roundtrip_point_with_altitude
    space_needle = Geodetic::Coordinate::LLA.new(lat: 47.6205, lng: -122.3493, alt: 184.0)
    parsed = Geodetic::WKB.parse(space_needle.to_wkb)
    assert_in_delta(184.0, parsed.alt, 1e-10)
  end

  def test_roundtrip_segment
    seg = Geodetic::Segment.new(@seattle, @portland)
    parsed = Geodetic::WKB.parse(seg.to_wkb)
    assert_instance_of Geodetic::Segment, parsed
    assert_in_delta(@seattle.lat, parsed.start_point.lat, 1e-10)
    assert_in_delta(@portland.lat, parsed.end_point.lat, 1e-10)
  end

  def test_roundtrip_path
    path = Geodetic::Path.new(coordinates: [@seattle, @portland, @sf])
    parsed = Geodetic::WKB.parse(path.to_wkb)
    assert_instance_of Geodetic::Path, parsed
    assert_equal 3, parsed.size
  end

  def test_roundtrip_polygon
    a = Geodetic::Coordinate::LLA.new(lat: 47.0, lng: -122.0, alt: 0)
    b = Geodetic::Coordinate::LLA.new(lat: 46.0, lng: -121.0, alt: 0)
    c = Geodetic::Coordinate::LLA.new(lat: 46.0, lng: -123.0, alt: 0)
    poly = Geodetic::Areas::Polygon.new(boundary: [a, b, c])
    parsed = Geodetic::WKB.parse(poly.to_wkb)
    assert_instance_of Geodetic::Areas::Polygon, parsed
  end

  def test_roundtrip_srid
    wkb = @seattle.to_wkb(srid: 4326)
    obj, srid = Geodetic::WKB.parse_with_srid(wkb)
    assert_equal 4326, srid
    assert_in_delta(@seattle.lat, obj.lat, 1e-10)
  end

  def test_roundtrip_hex
    hex = @seattle.to_wkb_hex
    parsed = Geodetic::WKB.parse(hex)
    assert_in_delta(@seattle.lat, parsed.lat, 1e-10)
    assert_equal hex, parsed.to_wkb_hex
  end

  # --- Z-dimension consistency ---

  def test_z_consistency_all_points_get_z
    seg = Geodetic::Segment.new(@seattle, @sf)
    parsed = Geodetic::WKB.parse(seg.to_wkb)
    assert_instance_of Geodetic::Segment, parsed
    assert_in_delta(0.0, parsed.start_point.alt, 1e-10)
    assert_in_delta(100.0, parsed.end_point.alt, 1e-10)
  end

  def test_no_z_when_all_altitudes_zero
    seg = Geodetic::Segment.new(@seattle, @portland)
    wkb = seg.to_wkb
    type = wkb[1, 4].unpack1("V")
    assert_equal 2, type  # LineString, not LineString Z (1002)
  end

  # --- File I/O (binary) ---

  def test_save_and_load_binary
    path = File.join(Dir.tmpdir, "geodetic_wkb_test_#{$$}.wkb")
    seg = Geodetic::Segment.new(@seattle, @portland)
    begin
      Geodetic::WKB.save!(path, @seattle, seg)
      objects = Geodetic::WKB.load(path)
      assert_equal 2, objects.length
      assert_instance_of Geodetic::Coordinate::LLA, objects[0]
      assert_instance_of Geodetic::Segment, objects[1]
      assert_in_delta(@seattle.lat, objects[0].lat, 1e-10)
    ensure
      File.delete(path) if File.exist?(path)
    end
  end

  def test_save_binary_with_array
    path = File.join(Dir.tmpdir, "geodetic_wkb_arr_#{$$}.wkb")
    begin
      Geodetic::WKB.save!(path, [@seattle, @portland])
      objects = Geodetic::WKB.load(path)
      assert_equal 2, objects.length
    ensure
      File.delete(path) if File.exist?(path)
    end
  end

  def test_save_binary_with_srid
    path = File.join(Dir.tmpdir, "geodetic_wkb_srid_#{$$}.wkb")
    begin
      Geodetic::WKB.save!(path, @seattle, srid: 4326)
      objects = Geodetic::WKB.load(path)
      assert_equal 1, objects.length
    ensure
      File.delete(path) if File.exist?(path)
    end
  end

  # --- File I/O (hex) ---

  def test_save_and_load_hex
    path = File.join(Dir.tmpdir, "geodetic_wkb_hex_#{$$}.wkb.hex")
    seg = Geodetic::Segment.new(@seattle, @portland)
    begin
      Geodetic::WKB.save_hex!(path, @seattle, seg)
      objects = Geodetic::WKB.load_hex(path)
      assert_equal 2, objects.length
      assert_instance_of Geodetic::Coordinate::LLA, objects[0]
      assert_instance_of Geodetic::Segment, objects[1]
    ensure
      File.delete(path) if File.exist?(path)
    end
  end

  def test_load_hex_skips_comments_and_blanks
    path = File.join(Dir.tmpdir, "geodetic_wkb_comments_#{$$}.wkb.hex")
    begin
      File.write(path, "# A comment\n#{POINT_1_2_HEX}\n\n  \n# Another\n#{SEATTLE_POINT_HEX}\n")
      objects = Geodetic::WKB.load_hex(path)
      assert_equal 2, objects.length
    ensure
      File.delete(path) if File.exist?(path)
    end
  end

  def test_file_roundtrip_binary
    path = File.join(Dir.tmpdir, "geodetic_wkb_rt_#{$$}.wkb")
    poly = Geodetic::Areas::Polygon.new(boundary: [
      Geodetic::Coordinate::LLA.new(lat: 47.0, lng: -122.0, alt: 0),
      Geodetic::Coordinate::LLA.new(lat: 46.0, lng: -121.0, alt: 0),
      Geodetic::Coordinate::LLA.new(lat: 46.0, lng: -123.0, alt: 0)
    ])
    begin
      Geodetic::WKB.save!(path, @seattle, @sf, poly)
      objects = Geodetic::WKB.load(path)
      assert_equal 3, objects.length
      assert_in_delta(@seattle.lat, objects[0].lat, 1e-10)
      assert_in_delta(@sf.alt, objects[1].alt, 1e-10)
      assert_instance_of Geodetic::Areas::Polygon, objects[2]
    ensure
      File.delete(path) if File.exist?(path)
    end
  end

  # --- Load fixture files ---

  def test_load_fixture_hex_file
    path = File.join(__dir__, "..", "examples", "sample_geometries.wkb.hex")
    return skip("fixture not found") unless File.exist?(path)

    objects = Geodetic::WKB.load_hex(path)
    assert objects.length >= 10  # multiple geometries in fixture

    # First should be POINT(1 2)
    first = objects[0]
    assert_instance_of Geodetic::Coordinate::LLA, first
    assert_in_delta(1.0, first.lng, 1e-10)
    assert_in_delta(2.0, first.lat, 1e-10)
  end

  def test_load_fixture_binary_file
    path = File.join(__dir__, "..", "examples", "sample_geometries.wkb")
    return skip("fixture not found") unless File.exist?(path)

    objects = Geodetic::WKB.load(path)
    assert_equal 9, objects.length

    # 1st: POINT Seattle
    assert_instance_of Geodetic::Coordinate::LLA, objects[0]
    assert_in_delta(-122.3493, objects[0].lng, 1e-4)

    # 4th: LINESTRING (Segment)
    assert_instance_of Geodetic::Segment, objects[3]

    # 5th: LINESTRING 3 points (Path)
    assert_instance_of Geodetic::Path, objects[4]
    assert_equal 3, objects[4].size

    # 6th: POLYGON
    assert_instance_of Geodetic::Areas::Polygon, objects[5]

    # 7th: MULTIPOINT → Array
    assert_instance_of Array, objects[6]
    assert_equal 2, objects[6].length

    # 8th: GEOMETRYCOLLECTION → Array
    assert_instance_of Array, objects[7]
    assert_equal 2, objects[7].length
  end
end
