# frozen_string_literal: true

require_relative "polygon"

module Geodetic
  module Areas
    class Rectangle < Polygon
      attr_reader :center, :width, :height, :bearing

      def initialize(center:, width:, height:, bearing: 0)
        @center  = center.is_a?(Coordinate::LLA) ? center : center.to_lla
        @width   = width.to_f
        @height  = height.to_f
        @bearing = bearing.to_f

        raise ArgumentError, "width must be positive" unless @width > 0
        raise ArgumentError, "height must be positive" unless @height > 0

        super(boundary: generate_vertices, validate: false)
      end

      def sides
        4
      end

      # Returns [nw, ne, se, sw] relative to the rectangle's own orientation.
      # "nw" is the corner in the bearing direction and to the left.
      def corners
        boundary[0..3]
      end

      # Returns the axis-aligned bounding box that encloses this rectangle.
      def to_bounding_box
        lats = corners.map(&:lat)
        lngs = corners.map(&:lng)

        BoundingBox.new(
          nw: Coordinate::LLA.new(lat: lats.max, lng: lngs.min, alt: 0),
          se: Coordinate::LLA.new(lat: lats.min, lng: lngs.max, alt: 0)
        )
      end

      private

      def generate_vertices
        half_w = @width / 2.0
        half_h = @height / 2.0

        # Four corners: offset from center along rotated axes
        # bearing points "forward" (like north on a compass)
        # width is perpendicular to bearing
        [
          corner(-half_w,  half_h),  # front-left
          corner( half_w,  half_h),  # front-right
          corner( half_w, -half_h),  # back-right
          corner(-half_w, -half_h)   # back-left
        ]
      end

      # Compute a corner given offsets along the perpendicular (x) and
      # parallel (y) axes relative to the bearing direction.
      def corner(x_offset, y_offset)
        bearing_rad = @bearing * Geodetic::RAD_PER_DEG
        lat_rad = @center.lat * Geodetic::RAD_PER_DEG

        m_per_deg_lat = 111_320.0
        m_per_deg_lng = 111_320.0 * Math.cos(lat_rad)

        # Rotate offsets by bearing
        north = y_offset * Math.cos(bearing_rad) - x_offset * Math.sin(bearing_rad)
        east  = y_offset * Math.sin(bearing_rad) + x_offset * Math.cos(bearing_rad)

        Coordinate::LLA.new(
          lat: @center.lat + north / m_per_deg_lat,
          lng: @center.lng + east / m_per_deg_lng,
          alt: @center.alt
        )
      end
    end
  end
end
