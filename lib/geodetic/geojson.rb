# frozen_string_literal: true

require "json"

module Geodetic
  class GeoJSON
    include Enumerable

    def initialize(*objects)
      @objects = []
      list = objects.length == 1 && objects[0].is_a?(Array) ? objects[0] : objects
      list.each { |obj| add(obj) }
    end

    # --- Accumulate ---

    def <<(object)
      if object.is_a?(Array)
        object.each { |obj| add(obj) }
      else
        add(object)
      end
      self
    end

    # --- Query ---

    def size
      @objects.size
    end

    alias length size

    def empty?
      @objects.empty?
    end

    def each(&block)
      @objects.each(&block)
    end

    # --- Remove ---

    def delete(object)
      @objects.delete(object)
      self
    end

    def clear
      @objects.clear
      self
    end

    # --- Export ---

    def to_h
      {
        "type" => "FeatureCollection",
        "features" => @objects.map { |obj| wrap_as_feature(obj) }
      }
    end

    def to_json(pretty: false)
      if pretty
        JSON.pretty_generate(to_h)
      else
        JSON.generate(to_h)
      end
    end

    def save(path, pretty: false)
      File.write(path, to_json(pretty: pretty))
    end

    # --- Display ---

    def to_s
      "GeoJSON::FeatureCollection(#{size} features)"
    end

    def inspect
      "#<Geodetic::GeoJSON size=#{size}>"
    end

    private

    def add(object)
      @objects << object
    end

    def wrap_as_feature(obj)
      if obj.is_a?(Feature)
        obj.to_geojson
      else
        { "type" => "Feature", "geometry" => obj.to_geojson, "properties" => {} }
      end
    end

    # ---------------------------------------------------------------
    # Geometry helpers (module-level, used by to_geojson on each type)
    # ---------------------------------------------------------------

    class << self
      # --- Export helpers ---

      def position(lla)
        if lla.alt != 0.0
          [lla.lng, lla.lat, lla.alt]
        else
          [lla.lng, lla.lat]
        end
      end

      def point_hash(lla)
        { "type" => "Point", "coordinates" => position(lla) }
      end

      def line_string_hash(lla_array)
        { "type" => "LineString", "coordinates" => lla_array.map { |p| position(p) } }
      end

      def polygon_hash(rings)
        { "type" => "Polygon", "coordinates" => rings.map { |ring| ring.map { |p| position(p) } } }
      end

      # --- Import ---

      def load(path)
        data = JSON.parse(File.read(path))
        parse(data)
      end

      def parse(data)
        case data["type"]
        when "FeatureCollection"
          data["features"].flat_map { |f| parse(f) }
        when "Feature"
          parse_feature(data)
        when "GeometryCollection"
          data["geometries"].flat_map { |g| parse_geometry(g) }
        else
          [parse_geometry(data)]
        end
      end

      private

      def parse_feature(data)
        geometry = parse_geometry(data["geometry"])
        properties = data["properties"] || {}

        results = geometry.is_a?(Array) ? geometry : [geometry]

        results.map do |geom|
          name = properties["name"]
          metadata = properties.reject { |k, _| k == "name" }

          if name || !metadata.empty?
            Feature.new(
              label: name,
              geometry: geom,
              metadata: metadata.transform_keys(&:to_sym)
            )
          else
            geom
          end
        end
      end

      def parse_geometry(data)
        case data["type"]
        when "Point"
          parse_point(data["coordinates"])
        when "LineString"
          parse_line_string(data["coordinates"])
        when "Polygon"
          parse_polygon(data["coordinates"])
        when "MultiPoint"
          data["coordinates"].map { |pos| parse_point(pos) }
        when "MultiLineString"
          data["coordinates"].map { |coords| parse_line_string(coords) }
        when "MultiPolygon"
          data["coordinates"].map { |rings| parse_polygon(rings) }
        when "GeometryCollection"
          data["geometries"].flat_map { |g| parse_geometry(g) }
        else
          raise ArgumentError, "unknown GeoJSON geometry type: #{data["type"]}"
        end
      end

      def parse_point(coords)
        lng, lat = coords[0], coords[1]
        alt = coords[2] || 0.0
        Coordinate::LLA.new(lat: lat, lng: lng, alt: alt)
      end

      def parse_line_string(coords)
        points = coords.map { |pos| parse_point(pos) }
        if points.length == 2
          Segment.new(points[0], points[1])
        else
          Path.new(coordinates: points)
        end
      end

      def parse_polygon(rings)
        outer = rings[0].map { |pos| parse_point(pos) }
        # Remove closing point if it duplicates the first (Polygon#initialize adds it)
        outer.pop if outer.length > 1 && outer.first == outer.last
        Areas::Polygon.new(boundary: outer)
      end
    end

    # ---------------------------------------------------------------
    # Mixin for coordinate classes (applied at bottom of this file)
    # ---------------------------------------------------------------

    module CoordinateMethods
      def to_geojson
        if is_a?(Coordinate::ENU) || is_a?(Coordinate::NED)
          raise ArgumentError,
            "#{self.class.name.split('::').last} is a relative coordinate system " \
            "and cannot be exported to GeoJSON without a reference point. " \
            "Convert to an absolute system (e.g., LLA) first."
        end

        lla = is_a?(Coordinate::LLA) ? self : to_lla
        GeoJSON.point_hash(lla)
      end
    end
  end
end

# ---------------------------------------------------------------
# Add to_geojson to non-coordinate geometry types
# ---------------------------------------------------------------

module Geodetic
  class Segment
    def to_geojson
      GeoJSON.line_string_hash([@start_point, @end_point])
    end
  end

  class Path
    def to_geojson(as: :line_string)
      raise ArgumentError, "path is empty" if empty?

      if as == :polygon
        raise ArgumentError, "need at least 3 coordinates for a polygon" if size < 3
        ring = @coordinates.dup
        ring << ring.first unless ring.first == ring.last
        GeoJSON.polygon_hash([ring])
      else
        raise ArgumentError, "need at least 2 coordinates for a line string" if size < 2
        GeoJSON.line_string_hash(@coordinates)
      end
    end
  end

  class Feature
    def to_geojson
      properties = {}
      properties["name"] = @label if @label
      properties.merge!(@metadata.transform_keys(&:to_s)) if @metadata && !@metadata.empty?
      { "type" => "Feature", "geometry" => @geometry.to_geojson, "properties" => properties }
    end
  end

  module Areas
    class Polygon
      def to_geojson
        GeoJSON.polygon_hash([@boundary])
      end
    end

    class Circle
      def to_geojson(segments: 32)
        step = 360.0 / segments
        ring = segments.times.map do |i|
          Vector.new(distance: @radius, bearing: step * i).destination_from(@centroid)
        end
        ring << ring.first
        GeoJSON.polygon_hash([ring])
      end
    end

    class BoundingBox
      def to_geojson
        ring = [nw, ne, @se, sw, nw]
        GeoJSON.polygon_hash([ring])
      end
    end
  end
end

# ---------------------------------------------------------------
# Apply coordinate mixin to all registered coordinate classes
# ---------------------------------------------------------------

Geodetic::Coordinate.systems.each do |klass|
  klass.include(Geodetic::GeoJSON::CoordinateMethods)
end
