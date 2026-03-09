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

        super(boundary: generate_vertices)
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
          destination(@center, @radius, angle)
        end
      end

      # Compute a destination point given start, distance (meters), and bearing (degrees).
      # Uses a simplified flat-earth projection adequate for polygon-scale distances.
      def destination(origin, distance_m, bearing_deg)
        bearing_rad = bearing_deg * Geodetic::RAD_PER_DEG
        lat_rad = origin.lat * Geodetic::RAD_PER_DEG

        # Approximate meters per degree at this latitude
        m_per_deg_lat = 111_320.0
        m_per_deg_lng = 111_320.0 * Math.cos(lat_rad)

        dlat = distance_m * Math.cos(bearing_rad) / m_per_deg_lat
        dlng = distance_m * Math.sin(bearing_rad) / m_per_deg_lng

        Coordinate::LLA.new(
          lat: origin.lat + dlat,
          lng: origin.lng + dlng,
          alt: origin.alt
        )
      end
    end
  end
end
