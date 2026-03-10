# frozen_string_literal: true

require_relative '../coordinate/lla'

module Geodetic
  module Areas
    class Polygon
      attr_reader :boundary, :centroid

      def initialize(boundary:, validate: true)
        raise ArgumentError, "A Polygon requires more than #{boundary.length} points on its boundary" unless boundary.length > 2

        @boundary = boundary.dup
        @boundary << boundary[0] unless boundary.first == boundary.last

        validate_no_self_intersection! if validate

        compute_centroid
      end

      # Returns Segment objects for each edge of the polygon.
      # Returns Segment objects for each side of the polygon.
      def segments
        @segments ||= @boundary.each_cons(2).map { |a, b| Segment.new(a, b) }
      end

      alias edges segments
      alias border segments

      # Minimum boundary size where GEOS outperforms pure Ruby for point-in-polygon.
      GEOS_INCLUDES_THRESHOLD = 15

      def includes?(a_point)
        if Geos.available? && @boundary.length >= GEOS_INCLUDES_THRESHOLD
          geos_includes?(a_point)
        else
          ruby_includes?(a_point)
        end
      end

      def excludes?(a_point)
        !includes?(a_point)
      end

      alias_method :include?, :includes?
      alias_method :exclude?, :excludes?
      alias_method :inside?,  :includes?
      alias_method :outside?, :excludes?

      def *(other)
        raise ArgumentError, "expected a Vector, got #{other.class}" unless other.is_a?(Vector)

        # Translate all vertices except the closing point (it gets re-added by initialize)
        translated = @boundary[0...-1].map { |pt| other.destination_from(pt) }
        self.class.new(boundary: translated)
      end

      alias_method :translate, :*

      private

      def ruby_includes?(a_point)
        turn_angle = 0.0

        (@boundary.length - 2).times do |index|
          return true if @boundary[index] == a_point

          d_turn_angle  = a_point.bearing_to(@boundary[index + 1]) - a_point.bearing_to(@boundary[index])
          d_turn_angle += (d_turn_angle > 0.0 ? -360.0 : 360.0) if d_turn_angle.abs > 180.0
          turn_angle   += d_turn_angle
        end

        turn_angle.abs > 180.0
      end

      def geos_includes?(a_point)
        Geos.contains?(self, a_point)
      end

      def compute_centroid
        centroid_lat = 0.0
        centroid_lng = 0.0
        area = 0.0

        0.upto(@boundary.length - 2) do |i|
          cross = @boundary[i].lng * @boundary[i + 1].lat - @boundary[i + 1].lng * @boundary[i].lat
          area += 0.5 * cross
          centroid_lng += (@boundary[i].lng + @boundary[i + 1].lng) * cross
          centroid_lat += (@boundary[i].lat + @boundary[i + 1].lat) * cross
        end

        if area.abs < 1e-12
          # Degenerate polygon (collinear or self-intersecting) — fall back to mean
          centroid_lat = @boundary[0...-1].sum(&:lat) / (@boundary.length - 1).to_f
          centroid_lng = @boundary[0...-1].sum(&:lng) / (@boundary.length - 1).to_f
        else
          centroid_lng /= (6.0 * area)
          centroid_lat /= (6.0 * area)
        end

        @centroid = Coordinate::LLA.new(lat: centroid_lat, lng: centroid_lng, alt: 0.0)
      end

      def validate_no_self_intersection!
        if Geos.available?
          geos_validate!
        else
          ruby_validate!
        end
      end

      def geos_validate!
        return if Geos.is_valid?(self)

        reason = Geos.is_valid_reason(self)
        raise ArgumentError, "polygon boundary is invalid — #{reason}"
      end

      def ruby_validate!
        validate_distinct_vertices!
        validate_noncollinear!
        validate_no_edge_crossings!
      end

      def validate_distinct_vertices!
        unique = @boundary[0...-1].uniq { |p| [p.lat, p.lng] }
        if unique.length < 3
          raise ArgumentError, "polygon requires at least 3 distinct vertices, got #{unique.length}"
        end
      end

      def validate_noncollinear!
        # Signed area via shoelace — zero means all points are collinear.
        signed_area = 0.0
        0.upto(@boundary.length - 2) do |i|
          signed_area += @boundary[i].lng * @boundary[i + 1].lat -
                         @boundary[i + 1].lng * @boundary[i].lat
        end

        if signed_area.abs < 1e-12
          raise ArgumentError, "polygon boundary is collinear — all vertices lie on the same line"
        end
      end

      def validate_no_edge_crossings!
        segs = @boundary.each_cons(2).map { |a, b| Segment.new(a, b) }

        segs.each_with_index do |seg_i, i|
          segs.each_with_index do |seg_j, j|
            # Skip same edge and adjacent edges (they share a vertex)
            next if j <= i + 1
            # Skip first-last pair (they share the closing vertex)
            next if i == 0 && j == segs.length - 1

            if seg_i.intersects?(seg_j)
              raise ArgumentError, "edge #{i} intersects edge #{j} — polygon boundary must not self-intersect"
            end
          end
        end
      end
    end
  end
end
