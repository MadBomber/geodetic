# frozen_string_literal: true

module Geodetic
  class Segment
    attr_reader :start_point, :end_point

    def initialize(start_point, end_point)
      @start_point = start_point.is_a?(Coordinate::LLA) ? start_point : start_point.to_lla
      @end_point   = end_point.is_a?(Coordinate::LLA)   ? end_point   : end_point.to_lla
    end

    # --- Properties ---

    def length
      @length ||= @start_point.distance_to(@end_point)
    end

    alias distance length

    def length_meters
      length.meters
    end

    def bearing
      @bearing ||= @start_point.bearing_to(@end_point)
    end

    def midpoint
      @midpoint ||= interpolate(0.5)
    end

    alias centroid midpoint

    # --- Geometry ---

    def reverse
      self.class.new(@end_point, @start_point)
    end

    def interpolate(fraction)
      Coordinate::LLA.new(
        lat: @start_point.lat + (@end_point.lat - @start_point.lat) * fraction,
        lng: @start_point.lng + (@end_point.lng - @start_point.lng) * fraction,
        alt: @start_point.alt + (@end_point.alt - @start_point.alt) * fraction
      )
    end

    # Projects a point onto this segment.
    # Returns [closest_point_on_segment, distance_in_meters].
    def project(point)
      target = point.is_a?(Coordinate::LLA) ? point : point.to_lla
      seg_len = length_meters
      dist_a_t = @start_point.distance_to(target).meters

      return [@start_point, dist_a_t] if seg_len < 1e-6
      return [@start_point, 0.0] if dist_a_t < 1e-6

      bearing_ab = bearing.degrees
      bearing_at = @start_point.bearing_to(target).degrees

      angle = (bearing_at - bearing_ab).abs
      angle = 360.0 - angle if angle > 180.0
      angle_rad = angle * Geodetic::RAD_PER_DEG

      along = dist_a_t * Math.cos(angle_rad)

      if along <= 0.0
        return [@start_point, dist_a_t]
      elsif along >= seg_len
        dist_b_t = @end_point.distance_to(target).meters
        return [@end_point, dist_b_t]
      end

      foot = interpolate(along / seg_len)
      [foot, foot.distance_to(target).meters]
    end

    # Tests if a point lies on this segment within a tolerance (meters).
    def contains?(point, tolerance: 10.0)
      target = point.is_a?(Coordinate::LLA) ? point : point.to_lla
      seg_len = length_meters

      return @start_point == target || @end_point == target if seg_len < 1e-6

      dist_a_p = @start_point.distance_to(target).meters
      dist_p_b = target.distance_to(@end_point).meters

      # Exact endpoint match
      return true if dist_a_p < 1e-6 || dist_p_b < 1e-6

      return false if dist_a_p > seg_len || dist_p_b > seg_len

      delta = Math.atan(tolerance / seg_len) * Geodetic::DEG_PER_RAD
      bearing_ap = @start_point.bearing_to(target).degrees
      bearing_pb = target.bearing_to(@end_point).degrees

      (bearing_ap - bearing_pb).abs <= delta
    end

    # True if the point is a vertex (start or end point).
    def includes?(point)
      target = point.is_a?(Coordinate::LLA) ? point : point.to_lla
      @start_point == target || @end_point == target
    end

    def excludes?(point, tolerance: 10.0)
      !contains?(point, tolerance: tolerance)
    end

    # Tests if this segment intersects another segment.
    def intersects?(other)
      p1 = flat(@start_point); q1 = flat(@end_point)
      p2 = flat(other.start_point); q2 = flat(other.end_point)

      d1 = cross_sign(p2, q2, p1)
      d2 = cross_sign(p2, q2, q1)
      d3 = cross_sign(p1, q1, p2)
      d4 = cross_sign(p1, q1, q2)

      return true if d1 != d2 && d3 != d4

      return true if d1 == 0 && on_collinear?(p2, q2, p1)
      return true if d2 == 0 && on_collinear?(p2, q2, q1)
      return true if d3 == 0 && on_collinear?(p1, q1, p2)
      return true if d4 == 0 && on_collinear?(p1, q1, q2)

      false
    end

    # --- Conversion ---

    def to_path
      Path.new(coordinates: [@start_point, @end_point])
    end

    def to_a
      [@start_point, @end_point]
    end

    # --- Equality / Display ---

    def ==(other)
      other.is_a?(Segment) &&
        @start_point == other.start_point &&
        @end_point == other.end_point
    end

    def to_s
      "Segment(#{@start_point} -> #{@end_point})"
    end

    def inspect
      "#<Geodetic::Segment start=#{@start_point.inspect} end=#{@end_point.inspect} length=#{length}>"
    end

    private

    def flat(coord)
      [coord.lat, coord.lng]
    end

    def cross_sign(a, b, c)
      val = (b[0] - a[0]) * (c[1] - a[1]) - (b[1] - a[1]) * (c[0] - a[0])
      val > 1e-12 ? 1 : (val < -1e-12 ? -1 : 0)
    end

    def on_collinear?(a, b, p)
      p[0] >= [a[0], b[0]].min && p[0] <= [a[0], b[0]].max &&
        p[1] >= [a[1], b[1]].min && p[1] <= [a[1], b[1]].max
    end
  end
end
