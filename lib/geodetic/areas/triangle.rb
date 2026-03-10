# frozen_string_literal: true

require_relative "polygon"

module Geodetic
  module Areas
    class Triangle < Polygon
      attr_reader :center, :width, :height, :bearing

      SIDE_TOLERANCE = 5.0 # meters — accounts for flat-earth projection error

      # Four construction modes:
      #
      #   Isosceles:             Triangle.new(center:, width:, height:, bearing:)
      #   Equilateral by radius: Triangle.new(center:, radius:, bearing:)
      #   Equilateral by side:   Triangle.new(center:, side:, bearing:)
      #   Arbitrary 3 vertices:  Triangle.new(vertices: [p1, p2, p3])
      #
      def initialize(center: nil, width: nil, height: nil, radius: nil, side: nil, bearing: 0, vertices: nil)
        if vertices
          raise ArgumentError, "vertices: cannot be combined with other shape arguments" if center || width || height || radius || side

          verts = validate_vertices(vertices)
          @center  = compute_center(verts)
          @bearing = 0.0
          @width   = 0.0
          @height  = 0.0
          super(boundary: verts)
        else
          raise ArgumentError, "center is required" unless center

          @center  = center.is_a?(Coordinate::LLA) ? center : center.to_lla
          @bearing = bearing.to_f
          resolve_dimensions(width, height, radius, side)

          raise ArgumentError, "width must be positive" unless @width > 0
          raise ArgumentError, "height must be positive" unless @height > 0

          super(boundary: generate_vertices, validate: false)
        end
      end

      def sides
        3
      end

      # Returns the three vertices.
      def vertices
        boundary[0..2]
      end

      # Base length (same as width). Returns nil for arbitrary vertex triangles.
      def base
        @width > 0 ? @width : nil
      end

      # True when all three side lengths are equal (within tolerance).
      def equilateral?
        a, b, c = side_lengths
        (a - b).abs < SIDE_TOLERANCE &&
          (b - c).abs < SIDE_TOLERANCE
      end

      # True when exactly two side lengths are equal (within tolerance).
      def isosceles?
        a, b, c = side_lengths
        pairs = [
          (a - b).abs < SIDE_TOLERANCE,
          (b - c).abs < SIDE_TOLERANCE,
          (a - c).abs < SIDE_TOLERANCE
        ]
        equal_count = pairs.count(true)
        equal_count == 1
      end

      # True when no two side lengths are equal (within tolerance).
      def scalene?
        !equilateral? && !isosceles?
      end

      # Returns the three side lengths in meters as [ab, bc, ca].
      def side_lengths
        v = vertices
        [
          v[0].distance_to(v[1]).meters,
          v[1].distance_to(v[2]).meters,
          v[2].distance_to(v[0]).meters
        ]
      end

      # Returns the axis-aligned bounding box that encloses this triangle.
      def to_bounding_box
        lats = vertices.map(&:lat)
        lngs = vertices.map(&:lng)

        BoundingBox.new(
          nw: Coordinate::LLA.new(lat: lats.max, lng: lngs.min, alt: 0),
          se: Coordinate::LLA.new(lat: lats.min, lng: lngs.max, alt: 0)
        )
      end

      private

      def validate_vertices(verts)
        raise ArgumentError, "exactly 3 vertices required" unless verts.size == 3

        verts.map { |v| v.is_a?(Coordinate::LLA) ? v : v.to_lla }
      end

      def compute_center(verts)
        Coordinate::LLA.new(
          lat: verts.sum(&:lat) / 3.0,
          lng: verts.sum(&:lng) / 3.0,
          alt: verts.sum(&:alt) / 3.0
        )
      end

      def resolve_dimensions(width, height, radius, side)
        given = { width: width, height: height, radius: radius, side: side }
                  .compact

        if given.key?(:radius)
          raise ArgumentError, "radius cannot be combined with width, height, or side" if given.size > 1

          r = radius.to_f
          raise ArgumentError, "radius must be positive" unless r > 0

          @width  = r * Math.sqrt(3)
          @height = r * 1.5

        elsif given.key?(:side)
          raise ArgumentError, "side cannot be combined with width or height" if given.size > 1

          s = side.to_f
          raise ArgumentError, "side must be positive" unless s > 0

          @width  = s
          @height = s * Math.sqrt(3) / 2.0

        elsif given.key?(:width) && given.key?(:height)
          raise ArgumentError, "width/height cannot be combined with radius or side" if given.size > 2

          @width  = width.to_f
          @height = height.to_f

        else
          raise ArgumentError, "provide width: + height:, radius:, side:, or vertices:"
        end
      end

      def generate_vertices
        half_w = @width / 2.0
        half_h = @height / 2.0

        [
          vertex(-half_w, -half_h),  # base-left
          vertex( half_w, -half_h),  # base-right
          vertex(    0.0,  half_h)   # apex
        ]
      end

      def vertex(x_offset, y_offset)
        bearing_rad = @bearing * Geodetic::RAD_PER_DEG
        lat_rad = @center.lat * Geodetic::RAD_PER_DEG

        m_per_deg_lat = 111_320.0
        m_per_deg_lng = 111_320.0 * Math.cos(lat_rad)

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
