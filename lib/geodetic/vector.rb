# frozen_string_literal: true

module Geodetic
  class Vector
    include Comparable

    attr_reader :distance, :bearing

    def initialize(distance:, bearing:)
      @distance = distance.is_a?(Distance) ? distance : Distance.new(distance.to_f)
      @bearing  = bearing.is_a?(Bearing)   ? bearing  : Bearing.new(bearing.to_f)
    end

    # --- Components (meters) ---

    def north
      @distance.meters * Math.cos(@bearing.to_radians)
    end

    def east
      @distance.meters * Math.sin(@bearing.to_radians)
    end

    # --- Factory ---

    ZERO_TOLERANCE = 1e-9

    def self.from_components(north:, east:)
      meters = Math.sqrt(north**2 + east**2)

      if meters < ZERO_TOLERANCE
        new(distance: Distance.new(0.0), bearing: Bearing.new(0.0))
      else
        new(distance: Distance.new(meters), bearing: Bearing.new(Math.atan2(east, north) * DEG_PER_RAD))
      end
    end

    def self.from_segment(segment)
      new(distance: segment.length, bearing: segment.bearing)
    end

    # --- Arithmetic ---

    def +(other)
      case other
      when Vector
        self.class.from_components(north: north + other.north, east: east + other.east)
      when Segment
        new_start = reverse.destination_from(other.start_point)
        Path.new(coordinates: [new_start, other.start_point, other.end_point])
      when ->(o) { Coordinate.systems.any? { |k| o.is_a?(k) } }
        Segment.new(reverse.destination_from(other), other)
      else
        raise ArgumentError, "Cannot add #{other.class} to Vector"
      end
    end

    def -(other)
      case other
      when Vector
        self.class.from_components(north: north - other.north, east: east - other.east)
      else
        raise ArgumentError, "Cannot subtract #{other.class} from Vector"
      end
    end

    def *(scalar)
      raise ArgumentError, "Cannot multiply Vector by #{scalar.class}" unless scalar.is_a?(Numeric)

      if scalar < 0
        self.class.new(distance: Distance.new(@distance.meters * scalar.abs), bearing: @bearing.reverse)
      else
        self.class.new(distance: Distance.new(@distance.meters * scalar), bearing: @bearing)
      end
    end

    def /(scalar)
      raise ArgumentError, "Cannot divide Vector by #{scalar.class}" unless scalar.is_a?(Numeric)
      raise ZeroDivisionError, "Cannot divide Vector by zero" if scalar == 0

      self * (1.0 / scalar)
    end

    def -@
      self.class.new(distance: @distance, bearing: @bearing.reverse)
    end

    def coerce(other)
      case other
      when Numeric then [ScalarCoerce.new(other), self]
      else raise TypeError, "#{other.class} can't be coerced into Vector"
      end
    end

    # @private
    ScalarCoerce = Struct.new(:value) do
      def *(vector)
        vector * value
      end
    end

    # --- Properties ---

    def magnitude
      @distance.meters
    end

    def zero?
      @distance.zero?
    end

    def reverse
      -self
    end

    alias inverse reverse

    def normalize
      return self if zero?

      self.class.new(distance: Distance.new(1.0), bearing: @bearing)
    end

    def dot(other)
      raise ArgumentError, "Cannot dot Vector with #{other.class}" unless other.is_a?(Vector)

      north * other.north + east * other.east
    end

    def cross(other)
      raise ArgumentError, "Cannot cross Vector with #{other.class}" unless other.is_a?(Vector)

      north * other.east - east * other.north
    end

    def angle_between(other)
      raise ArgumentError, "expected a Vector" unless other.is_a?(Vector)

      Bearing.new(other.bearing.degrees - @bearing.degrees)
    end

    # --- Vincenty direct ---

    def destination_from(origin)
      lla = origin.is_a?(Coordinate::LLA) ? origin : origin.to_lla

      a = WGS84.a
      f = WGS84.f
      b = WGS84.b
      s = @distance.meters

      return lla if s == 0.0

      alpha1 = @bearing.degrees * RAD_PER_DEG
      sin_alpha1 = Math.sin(alpha1)
      cos_alpha1 = Math.cos(alpha1)

      tan_u1 = (1 - f) * Math.tan(lla.lat * RAD_PER_DEG)
      cos_u1 = 1.0 / Math.sqrt(1 + tan_u1**2)
      sin_u1 = tan_u1 * cos_u1

      sigma1 = Math.atan2(tan_u1, cos_alpha1)
      sin_alpha = cos_u1 * sin_alpha1
      cos2_alpha = 1 - sin_alpha**2

      u_sq = cos2_alpha * (a**2 - b**2) / b**2
      aa = 1 + u_sq / 16384 * (4096 + u_sq * (-768 + u_sq * (320 - 175 * u_sq)))
      bb = u_sq / 1024 * (256 + u_sq * (-128 + u_sq * (74 - 47 * u_sq)))

      sigma = s / (b * aa)

      sin_sigma   = 0.0
      cos_sigma   = 0.0
      cos_2sigma_m = 0.0

      100.times do
        cos_2sigma_m = Math.cos(2 * sigma1 + sigma)
        sin_sigma = Math.sin(sigma)
        cos_sigma = Math.cos(sigma)

        delta_sigma = bb * sin_sigma * (cos_2sigma_m + bb / 4 *
          (cos_sigma * (-1 + 2 * cos_2sigma_m**2) -
           bb / 6 * cos_2sigma_m * (-3 + 4 * sin_sigma**2) * (-3 + 4 * cos_2sigma_m**2)))

        sigma_prev = sigma
        sigma = s / (b * aa) + delta_sigma

        break if (sigma - sigma_prev).abs < 1e-12
      end

      sin_sigma = Math.sin(sigma)
      cos_sigma = Math.cos(sigma)
      cos_2sigma_m = Math.cos(2 * sigma1 + sigma)

      lat2 = Math.atan2(
        sin_u1 * cos_sigma + cos_u1 * sin_sigma * cos_alpha1,
        (1 - f) * Math.sqrt(sin_alpha**2 +
          (sin_u1 * sin_sigma - cos_u1 * cos_sigma * cos_alpha1)**2)
      )

      lambda_val = Math.atan2(
        sin_sigma * sin_alpha1,
        cos_u1 * cos_sigma - sin_u1 * sin_sigma * cos_alpha1
      )

      c = f / 16 * cos2_alpha * (4 + f * (4 - 3 * cos2_alpha))

      l = lambda_val - (1 - c) * f * sin_alpha *
        (sigma + c * sin_sigma * (cos_2sigma_m + c * cos_sigma * (-1 + 2 * cos_2sigma_m**2)))

      Coordinate::LLA.new(
        lat: lat2 * DEG_PER_RAD,
        lng: lla.lng + l * DEG_PER_RAD,
        alt: lla.alt
      )
    end

    # --- Comparison ---

    def <=>(other)
      case other
      when Vector then @distance <=> other.distance
      end
    end

    def ==(other)
      other.is_a?(Vector) &&
        @distance == other.distance &&
        @bearing == other.bearing
    end

    # --- Display ---

    def to_s
      "Vector(#{@distance}, #{@bearing})"
    end

    def inspect
      "#<Geodetic::Vector distance=#{@distance.inspect} bearing=#{@bearing.inspect}>"
    end
  end
end
