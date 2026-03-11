# frozen_string_literal: true

module Geodetic
  module Map
    class Base
      attr_reader :layers

      def initialize(**options)
        @layers  = []
        @options = options
      end

      # --- Adding geometry ---

      def add(object, **style)
        case object
        when Feature
          add_feature(object, **style)
        when Path
          add_path(object, **style)
        when Segment
          add_segment(object, **style)
        when Areas::Circle
          add_circle(object, **style)
        when Areas::BoundingBox
          add_bounding_box(object, **style)
        when Areas::Polygon
          add_polygon(object, **style)
        else
          if coordinate?(object)
            add_coordinate(object, **style)
          else
            raise ArgumentError, "unsupported object type: #{object.class}"
          end
        end

        self
      end

      def add_coordinate(coordinate, **style)
        lla = to_lla(coordinate)
        @layers << { type: :point, lla: lla, style: style }
        self
      end

      def add_path(path, **style)
        llas = path.map { |c| to_lla(c) }
        @layers << { type: :line, llas: llas, style: style }
        self
      end

      def add_segment(segment, **style)
        llas = [segment.start_point, segment.end_point]
        @layers << { type: :line, llas: llas, style: style }
        self
      end

      def add_polygon(polygon, **style)
        llas = polygon.boundary.map { |c| to_lla(c) }
        @layers << { type: :polygon, llas: llas, style: style }
        self
      end

      def add_circle(circle, **style)
        segments = style.delete(:segments) || 32
        step = 360.0 / segments
        llas = segments.times.map do |i|
          Vector.new(distance: circle.radius, bearing: step * i).destination_from(circle.centroid)
        end
        llas << llas.first
        @layers << { type: :polygon, llas: llas, style: style }
        self
      end

      def add_bounding_box(bbox, **style)
        llas = [bbox.nw, bbox.ne, bbox.se, bbox.sw, bbox.nw]
        @layers << { type: :polygon, llas: llas, style: style }
        self
      end

      def add_feature(feature, **style)
        merged_style = feature_style(feature, style)
        add(feature.geometry, **merged_style)
      end

      # --- Output ---

      def render(output_path)
        raise NotImplementedError, "#{self.class}#render must be implemented by subclass"
      end

      # --- Query ---

      def size
        @layers.size
      end

      def empty?
        @layers.empty?
      end

      def clear
        @layers.clear
        self
      end

      private

      def coordinate?(object)
        Coordinate.systems.any? { |klass| object.is_a?(klass) }
      end

      def to_lla(coord)
        return coord if coord.is_a?(Coordinate::LLA)

        if coord.is_a?(Coordinate::ENU) || coord.is_a?(Coordinate::NED)
          raise ArgumentError,
            "#{coord.class.name.split('::').last} is a relative coordinate system. " \
            "Convert to an absolute system before adding to a map."
        end

        coord.to_lla
      end

      def feature_style(feature, explicit_style)
        style = {}
        style[:label] = feature.label if feature.label
        style.merge(explicit_style)
      end
    end
  end
end
