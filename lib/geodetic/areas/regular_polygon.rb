# frozen_string_literal: true

require_relative "polygon"

module Geodetic
  module Areas
    # Base class for regular polygons (equal sides, equal angles).
    # Subclasses set SIDES and inherit vertex generation.
    class RegularPolygon < Polygon
      attr_reader :center, :radius, :bearing

      def initialize(center:, radius:, bearing: 0)
        @center  = center.is_a?(Coordinate::LLA) ? center : center.to_lla
        @radius  = radius.to_f
        @bearing = bearing.to_f

        raise ArgumentError, "radius must be positive" unless @radius > 0

        super(boundary: generate_vertices, validate: false)
      end

      def sides
        self.class::SIDES
      end

      private

      def generate_vertices
        n = self.class::SIDES
        step = 360.0 / n

        n.times.map do |i|
          angle = @bearing + step * i
          Vector.new(distance: @radius, bearing: angle).destination_from(@center)
        end
      end
    end
  end
end
