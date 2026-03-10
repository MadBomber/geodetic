# frozen_string_literal: true

module Geodetic
  module WKT
    # --- Export helpers ---

    class << self
      def position(lla, precision:, use_z:)
        if use_z
          "#{lla.lng.round(precision)} #{lla.lat.round(precision)} #{lla.alt.round(precision)}"
        else
          "#{lla.lng.round(precision)} #{lla.lat.round(precision)}"
        end
      end

      def has_altitude?(points)
        points.any? { |p| p.alt != 0.0 }
      end

      def srid_prefix(srid)
        srid ? "SRID=#{srid};" : ""
      end

      def point_wkt(lla, precision: 6, srid: nil)
        z = lla.alt != 0.0
        type = z ? "POINT Z" : "POINT"
        "#{srid_prefix(srid)}#{type}(#{position(lla, precision: precision, use_z: z)})"
      end

      def line_string_wkt(points, precision: 6, srid: nil)
        z = has_altitude?(points)
        type = z ? "LINESTRING Z" : "LINESTRING"
        coords = points.map { |p| position(p, precision: precision, use_z: z) }.join(", ")
        "#{srid_prefix(srid)}#{type}(#{coords})"
      end

      def polygon_wkt(rings, precision: 6, srid: nil)
        z = rings.any? { |ring| has_altitude?(ring) }
        type = z ? "POLYGON Z" : "POLYGON"
        ring_strs = rings.map do |ring|
          coords = ring.map { |p| position(p, precision: precision, use_z: z) }.join(", ")
          "(#{coords})"
        end
        "#{srid_prefix(srid)}#{type}(#{ring_strs.join(', ')})"
      end

      # --- File I/O ---

      def save!(path, *objects, srid: nil, precision: 6)
        list = objects.length == 1 && objects[0].is_a?(Array) ? objects[0] : objects
        File.open(path, "w") do |f|
          list.each { |obj| f.puts obj.to_wkt(precision: precision, srid: srid) }
        end
      end

      def load(path)
        File.readlines(path, chomp: true)
            .reject { |line| line.strip.empty? }
            .map { |line| parse(line) }
      end

      # --- Import ---

      def parse(wkt_string)
        str = wkt_string.strip
        # Strip SRID prefix if present
        str = str.sub(/\ASRID=\d+;/i, "")
        parse_geometry(str)
      end

      def parse_with_srid(wkt_string)
        str = wkt_string.strip
        srid = nil
        if str =~ /\ASRID=(\d+);/i
          srid = $1.to_i
          str = $'
        end
        [parse_geometry(str), srid]
      end

      private

      def parse_geometry(str)
        str = str.strip
        case str
        when /\APOINT\s*Z\s*\((.+)\)\z/im
          parse_point($1, has_z: true)
        when /\APOINT\s*\((.+)\)\z/im
          parse_point($1, has_z: false)
        when /\ALINESTRING\s*Z\s*\((.+)\)\z/im
          parse_line_string($1, has_z: true)
        when /\ALINESTRING\s*\((.+)\)\z/im
          parse_line_string($1, has_z: false)
        when /\APOLYGON\s*Z\s*\((.+)\)\z/im
          parse_polygon($1, has_z: true)
        when /\APOLYGON\s*\((.+)\)\z/im
          parse_polygon($1, has_z: false)
        when /\AMULTIPOINT\s*(Z?)\s*\((.+)\)\z/im
          parse_multi_point($2, has_z: !$1.empty?)
        when /\AMULTILINESTRING\s*(Z?)\s*\((.+)\)\z/im
          parse_multi_line_string($2, has_z: !$1.empty?)
        when /\AMULTIPOLYGON\s*(Z?)\s*\((.+)\)\z/im
          parse_multi_polygon($2, has_z: !$1.empty?)
        when /\AGEOMETRYCOLLECTION\s*Z?\s*\((.+)\)\z/im
          parse_geometry_collection($1)

        else
          raise ArgumentError, "unknown WKT type: #{str[0..30]}"
        end
      end

      def parse_point(coords_str, has_z:)
        parts = coords_str.strip.split(/\s+/)
        lng = parts[0].to_f
        lat = parts[1].to_f
        alt = has_z && parts[2] ? parts[2].to_f : 0.0
        Coordinate::LLA.new(lat: lat, lng: lng, alt: alt)
      end

      def parse_line_string(coords_str, has_z:)
        points = coords_str.split(",").map { |c| parse_point(c, has_z: has_z) }
        if points.length == 2
          Segment.new(points[0], points[1])
        else
          Path.new(coordinates: points)
        end
      end

      def parse_polygon(rings_str, has_z:)
        rings = split_rings(rings_str)
        outer = rings[0].split(",").map { |c| parse_point(c, has_z: has_z) }
        # Remove closing point if it duplicates the first
        outer.pop if outer.length > 1 && outer.first == outer.last
        Areas::Polygon.new(boundary: outer)
      end

      def parse_multi_point(coords_str, has_z:)
        # MULTIPOINT can be ((x y), (x y)) or (x y, x y)
        if coords_str.include?("(")
          coords_str.scan(/\(([^)]+)\)/).map { |m| parse_point(m[0], has_z: has_z) }
        else
          coords_str.split(",").map { |c| parse_point(c, has_z: has_z) }
        end
      end

      def parse_multi_line_string(coords_str, has_z:)
        split_rings(coords_str).map { |ring| parse_line_string(ring, has_z: has_z) }
      end

      def parse_multi_polygon(coords_str, has_z:)
        polygons = split_top_level(coords_str)
        polygons.map { |poly_str| parse_polygon(poly_str, has_z: has_z) }
      end

      def parse_geometry_collection(inner)
        geometries = split_geometries(inner)
        geometries.map { |g| parse_geometry(g) }
      end

      # Split "(a, b), (c, d)" into ["a, b", "c, d"]
      def split_rings(str)
        str.scan(/\(([^()]+)\)/).map(&:first)
      end

      # Split top-level parenthesized groups: "((a),(b)), ((c),(d))" → ["(a),(b)", "(c),(d)"]
      def split_top_level(str)
        results = []
        depth = 0
        current = +""
        str.each_char do |ch|
          case ch
          when "("
            depth += 1
            if depth == 1
              current = +""
            else
              current << ch
            end
          when ")"
            depth -= 1
            if depth == 0
              results << current
            else
              current << ch
            end
          when ","
            current << ch if depth > 0
          when " "
            current << ch if depth > 0
          else
            current << ch
          end
        end
        results
      end

      # Split geometry collection: "POINT(1 2), LINESTRING(1 2, 3 4)"
      # Must handle nested parens in each geometry
      def split_geometries(str)
        results = []
        depth = 0
        current = +""
        str.each_char do |ch|
          case ch
          when "("
            depth += 1
            current << ch
          when ")"
            depth -= 1
            current << ch
          when ","
            if depth == 0
              results << current.strip
              current = +""
            else
              current << ch
            end
          else
            current << ch
          end
        end
        results << current.strip unless current.strip.empty?
        results
      end
    end

    # ---------------------------------------------------------------
    # Mixin for coordinate classes
    # ---------------------------------------------------------------

    module CoordinateMethods
      def to_wkt(precision: 6, srid: nil)
        if is_a?(Coordinate::ENU) || is_a?(Coordinate::NED)
          raise ArgumentError,
            "#{self.class.name.split('::').last} is a relative coordinate system " \
            "and cannot be exported to WKT without a reference point. " \
            "Convert to an absolute system (e.g., LLA) first."
        end

        lla = is_a?(Coordinate::LLA) ? self : to_lla
        WKT.point_wkt(lla, precision: precision, srid: srid)
      end
    end
  end
end

# ---------------------------------------------------------------
# Add to_wkt to non-coordinate geometry types
# ---------------------------------------------------------------

module Geodetic
  class Segment
    def to_wkt(precision: 6, srid: nil)
      WKT.line_string_wkt([@start_point, @end_point], precision: precision, srid: srid)
    end
  end

  class Path
    def to_wkt(as: :line_string, precision: 6, srid: nil)
      raise ArgumentError, "path is empty" if empty?

      if as == :polygon
        raise ArgumentError, "need at least 3 coordinates for a polygon" if size < 3
        ring = @coordinates.dup
        ring << ring.first unless ring.first == ring.last
        WKT.polygon_wkt([ring], precision: precision, srid: srid)
      else
        raise ArgumentError, "need at least 2 coordinates for a line string" if size < 2
        WKT.line_string_wkt(@coordinates, precision: precision, srid: srid)
      end
    end
  end

  class Feature
    def to_wkt(precision: 6, srid: nil)
      @geometry.to_wkt(precision: precision, srid: srid)
    end
  end

  module Areas
    class Polygon
      def to_wkt(precision: 6, srid: nil)
        WKT.polygon_wkt([@boundary], precision: precision, srid: srid)
      end
    end

    class Circle
      def to_wkt(segments: 32, precision: 6, srid: nil)
        step = 360.0 / segments
        ring = segments.times.map do |i|
          Vector.new(distance: @radius, bearing: step * i).destination_from(@centroid)
        end
        ring << ring.first
        WKT.polygon_wkt([ring], precision: precision, srid: srid)
      end
    end

    class BoundingBox
      def to_wkt(precision: 6, srid: nil)
        ring = [nw, ne, @se, sw, nw]
        WKT.polygon_wkt([ring], precision: precision, srid: srid)
      end
    end
  end
end

# ---------------------------------------------------------------
# Apply coordinate mixin to all registered coordinate classes
# ---------------------------------------------------------------

Geodetic::Coordinate.systems.each do |klass|
  klass.include(Geodetic::WKT::CoordinateMethods)
end
