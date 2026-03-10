# frozen_string_literal: true

module Geodetic
  module WKB
    # Type codes
    TYPE_POINT               = 1
    TYPE_LINE_STRING         = 2
    TYPE_POLYGON             = 3
    TYPE_MULTI_POINT         = 4
    TYPE_MULTI_LINE_STRING   = 5
    TYPE_MULTI_POLYGON       = 6
    TYPE_GEOMETRY_COLLECTION = 7

    # Z offset (ISO WKB)
    ISO_Z_OFFSET = 1000

    # EWKB flags
    EWKB_SRID_FLAG = 0x20000000
    EWKB_Z_FLAG    = 0x80000000

    # Output is always little-endian (NDR). This matches PostGIS, GEOS, RGeo,
    # Shapely, and virtually all modern GIS tools. Big-endian (XDR) input is
    # fully supported by the parser.
    BYTE_ORDER_LE = 0x01

    class << self
      # --- Export helpers (private, used by to_wkb on each type) ---

      def encode_point(lla, srid: nil)
        has_z = lla.alt != 0.0
        pack_header(TYPE_POINT, srid: srid, has_z: has_z) +
          pack_coords(lla, has_z: has_z)
      end

      def encode_line_string(points, srid: nil)
        has_z = has_altitude?(points)
        pack_header(TYPE_LINE_STRING, srid: srid, has_z: has_z) +
          [points.length].pack("V") +
          points.map { |p| pack_coords(p, has_z: has_z) }.join
      end

      def encode_polygon(rings, srid: nil)
        has_z = rings.any? { |ring| has_altitude?(ring) }
        pack_header(TYPE_POLYGON, srid: srid, has_z: has_z) +
          [rings.length].pack("V") +
          rings.map { |ring|
            [ring.length].pack("V") +
              ring.map { |p| pack_coords(p, has_z: has_z) }.join
          }.join
      end

      # --- File I/O ---

      def save!(path, *objects, srid: nil)
        list = objects.length == 1 && objects[0].is_a?(Array) ? objects[0] : objects
        File.open(path, "wb") do |f|
          f.write([list.length].pack("V"))
          list.each do |obj|
            bytes = obj.to_wkb(srid: srid)
            f.write([bytes.bytesize].pack("V"))
            f.write(bytes)
          end
        end
      end

      def load(path)
        data = File.binread(path)
        count = data[0, 4].unpack1("V")
        pos = 4
        count.times.map do
          size = data[pos, 4].unpack1("V")
          pos += 4
          geom_bytes = data[pos, size]
          pos += size
          parse(geom_bytes)
        end
      end

      def save_hex!(path, *objects, srid: nil)
        list = objects.length == 1 && objects[0].is_a?(Array) ? objects[0] : objects
        File.open(path, "w") do |f|
          list.each { |obj| f.puts obj.to_wkb_hex(srid: srid) }
        end
      end

      def load_hex(path)
        File.readlines(path, chomp: true)
            .reject { |line| line.strip.empty? || line.strip.start_with?("#") }
            .map { |line| parse(line.strip) }
      end

      # --- Import ---

      def parse(input)
        reader = Reader.new(to_binary(input))
        reader.read_geometry
      end

      def parse_with_srid(input)
        reader = Reader.new(to_binary(input))
        geom = reader.read_geometry
        [geom, reader.srid]
      end

      private

      def has_altitude?(points)
        points.any? { |p| p.alt != 0.0 }
      end

      def pack_header(type, srid: nil, has_z: false)
        type_int = has_z ? type + ISO_Z_OFFSET : type
        type_int |= EWKB_SRID_FLAG if srid
        result = [BYTE_ORDER_LE].pack("C") + [type_int].pack("V")
        result += [srid].pack("V") if srid
        result
      end

      def pack_coords(lla, has_z:)
        if has_z
          [lla.lng, lla.lat, lla.alt].pack("E3")
        else
          [lla.lng, lla.lat].pack("E2")
        end
      end

      def to_binary(input)
        if input.encoding == Encoding::ASCII_8BIT
          # Could be binary or hex that happens to be ASCII-8BIT
          if input.bytes.any? { |b| b > 127 } || input.bytesize < 5
            return input
          end
          # Check if it looks like hex
          if input.match?(/\A[0-9a-fA-F]+\z/)
            return [input].pack("H*")
          end
          input
        else
          # String encoding — treat as hex
          stripped = input.strip
          if stripped.match?(/\A[0-9a-fA-F]+\z/) && stripped.length.even?
            [stripped].pack("H*")
          else
            stripped.b
          end
        end
      end
    end

    # ---------------------------------------------------------------
    # Reader for parsing WKB binary data
    # ---------------------------------------------------------------

    class Reader
      attr_reader :srid

      def initialize(data)
        @data = data.b
        @pos = 0
        @srid = nil
      end

      def read_geometry
        byte_order = read_bytes(1).ord
        @le = byte_order == 0x01

        type_int = read_uint32
        has_srid = (type_int & EWKB_SRID_FLAG) != 0
        has_z_ewkb = (type_int & EWKB_Z_FLAG) != 0

        type_int &= ~EWKB_SRID_FLAG & ~EWKB_Z_FLAG

        @srid = read_uint32 if has_srid

        has_z = has_z_ewkb
        if type_int >= ISO_Z_OFFSET && type_int < 2000
          has_z = true
          type_int -= ISO_Z_OFFSET
        end

        case type_int
        when TYPE_POINT              then read_point(has_z)
        when TYPE_LINE_STRING        then read_line_string(has_z)
        when TYPE_POLYGON            then read_polygon(has_z)
        when TYPE_MULTI_POINT        then read_multi
        when TYPE_MULTI_LINE_STRING  then read_multi
        when TYPE_MULTI_POLYGON      then read_multi
        when TYPE_GEOMETRY_COLLECTION then read_multi
        else
          raise ArgumentError, "unknown WKB type code: #{type_int}"
        end
      end

      private

      def read_bytes(n)
        result = @data[@pos, n]
        @pos += n
        result
      end

      def read_uint32
        bytes = read_bytes(4)
        bytes.unpack1(@le ? "V" : "N")
      end

      def read_double
        bytes = read_bytes(8)
        bytes.unpack1(@le ? "E" : "G")
      end

      def read_point(has_z)
        lng = read_double
        lat = read_double
        alt = has_z ? read_double : 0.0
        Coordinate::LLA.new(lat: lat, lng: lng, alt: alt)
      end

      def read_line_string(has_z)
        count = read_uint32
        points = count.times.map { read_point(has_z) }
        if points.length == 2
          Segment.new(points[0], points[1])
        else
          Path.new(coordinates: points)
        end
      end

      def read_polygon(has_z)
        ring_count = read_uint32
        rings = ring_count.times.map do
          point_count = read_uint32
          point_count.times.map { read_point(has_z) }
        end
        outer = rings[0]
        outer.pop if outer.length > 1 && outer.first == outer.last
        Areas::Polygon.new(boundary: outer)
      end

      def read_multi
        count = read_uint32
        count.times.map { read_geometry }
      end
    end

    # ---------------------------------------------------------------
    # Mixin for coordinate classes
    # ---------------------------------------------------------------

    module CoordinateMethods
      def to_wkb(srid: nil)
        if is_a?(Coordinate::ENU) || is_a?(Coordinate::NED)
          raise ArgumentError,
            "#{self.class.name.split('::').last} is a relative coordinate system " \
            "and cannot be exported to WKB without a reference point. " \
            "Convert to an absolute system (e.g., LLA) first."
        end

        lla = is_a?(Coordinate::LLA) ? self : to_lla
        WKB.encode_point(lla, srid: srid)
      end

      def to_wkb_hex(srid: nil)
        to_wkb(srid: srid).unpack1("H*")
      end
    end
  end
end

# ---------------------------------------------------------------
# Add to_wkb / to_wkb_hex to non-coordinate geometry types
# ---------------------------------------------------------------

module Geodetic
  class Segment
    def to_wkb(srid: nil)
      WKB.encode_line_string([@start_point, @end_point], srid: srid)
    end

    def to_wkb_hex(srid: nil)
      to_wkb(srid: srid).unpack1("H*")
    end
  end

  class Path
    def to_wkb(as: :line_string, srid: nil)
      raise ArgumentError, "path is empty" if empty?

      if as == :polygon
        raise ArgumentError, "need at least 3 coordinates for a polygon" if size < 3
        ring = @coordinates.dup
        ring << ring.first unless ring.first == ring.last
        WKB.encode_polygon([ring], srid: srid)
      else
        raise ArgumentError, "need at least 2 coordinates for a line string" if size < 2
        WKB.encode_line_string(@coordinates, srid: srid)
      end
    end

    def to_wkb_hex(as: :line_string, srid: nil)
      to_wkb(as: as, srid: srid).unpack1("H*")
    end
  end

  class Feature
    def to_wkb(srid: nil)
      @geometry.to_wkb(srid: srid)
    end

    def to_wkb_hex(srid: nil)
      to_wkb(srid: srid).unpack1("H*")
    end
  end

  module Areas
    class Polygon
      def to_wkb(srid: nil)
        WKB.encode_polygon([@boundary], srid: srid)
      end

      def to_wkb_hex(srid: nil)
        to_wkb(srid: srid).unpack1("H*")
      end
    end

    class Circle
      def to_wkb(segments: 32, srid: nil)
        step = 360.0 / segments
        ring = segments.times.map do |i|
          Vector.new(distance: @radius, bearing: step * i).destination_from(@centroid)
        end
        ring << ring.first
        WKB.encode_polygon([ring], srid: srid)
      end

      def to_wkb_hex(segments: 32, srid: nil)
        to_wkb(segments: segments, srid: srid).unpack1("H*")
      end
    end

    class BoundingBox
      def to_wkb(srid: nil)
        ring = [nw, ne, @se, sw, nw]
        WKB.encode_polygon([ring], srid: srid)
      end

      def to_wkb_hex(srid: nil)
        to_wkb(srid: srid).unpack1("H*")
      end
    end
  end
end

# ---------------------------------------------------------------
# Apply coordinate mixin to all registered coordinate classes
# ---------------------------------------------------------------

Geodetic::Coordinate.systems.each do |klass|
  klass.include(Geodetic::WKB::CoordinateMethods)
end
