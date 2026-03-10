# frozen_string_literal: true

require_relative "polygon"

module Geodetic
  module Areas
    class Rectangle < Polygon
      attr_reader :centerline, :width

      # Construct a rectangle from a centerline Segment and a width (meters).
      #
      #   Rectangle.new(segment: a_segment, width: 200)
      #   Rectangle.new(segment: [point_a, point_b], width: 200)
      #
      # The segment defines the centerline — height = segment.length,
      # bearing = segment.bearing, center = segment.midpoint.
      # Width is the perpendicular extent on each side of the centerline.
      #
      def initialize(segment:, width:)
        @centerline = segment.is_a?(Segment) ? segment : Segment.new(*segment)
        @width = width.is_a?(Distance) ? width.meters : width.to_f

        raise ArgumentError, "width must be positive" unless @width > 0

        super(boundary: generate_vertices, validate: false)
      end

      def sides
        4
      end

      # Center is the midpoint of the centerline.
      def center
        @centerline.midpoint
      end

      # Height is the length of the centerline in meters.
      def height
        @centerline.length_meters
      end

      # Bearing is the direction of the centerline in degrees.
      def bearing
        @centerline.bearing.degrees
      end

      # Returns the 4 corner coordinates [front-left, front-right, back-right, back-left]
      # relative to the bearing direction.
      def corners
        boundary[0..3]
      end

      # True when width equals height (within tolerance).
      def square?
        (@width - height).abs < 1e-6
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
        bearing_deg = @centerline.bearing.degrees
        front = @centerline.end_point
        back  = @centerline.start_point

        # Perpendicular bearing: +90 for right, -90 for left
        [
          offset_point(front, -half_w, bearing_deg + 90),  # front-left
          offset_point(front,  half_w, bearing_deg + 90),  # front-right
          offset_point(back,   half_w, bearing_deg + 90),  # back-right
          offset_point(back,  -half_w, bearing_deg + 90)   # back-left
        ]
      end

      # Offset a point by a signed distance along a bearing using flat-earth projection.
      def offset_point(origin, distance_m, bearing_deg)
        bearing_rad = bearing_deg * Geodetic::RAD_PER_DEG
        lat_rad = origin.lat * Geodetic::RAD_PER_DEG

        m_per_deg_lat = 111_320.0
        m_per_deg_lng = 111_320.0 * Math.cos(lat_rad)

        north = distance_m * Math.cos(bearing_rad) / m_per_deg_lat
        east  = distance_m * Math.sin(bearing_rad) / m_per_deg_lng

        Coordinate::LLA.new(
          lat: origin.lat + north,
          lng: origin.lng + east,
          alt: origin.alt
        )
      end
    end
  end
end
