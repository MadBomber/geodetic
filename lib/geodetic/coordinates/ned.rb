# frozen_string_literal: true

require_relative '../datum'

module Geodetic
  module Coordinates
    class NED
      attr_reader :n, :e, :d
      alias_method :north, :n
      alias_method :east, :e
      alias_method :down, :d

      def initialize(n: 0.0, e: 0.0, d: 0.0)
        @n = n.to_f
        @e = e.to_f
        @d = d.to_f
      end

      def to_enu
        require_relative 'enu'

        ENU.new(e: @e, n: @n, u: -@d)
      end

      def self.from_enu(enu)
        require_relative 'enu'
        raise ArgumentError, "Expected ENU" unless enu.is_a?(ENU)

        enu.to_ned
      end

      def to_ecef(reference_ecef, reference_lla = nil)
        require_relative 'ecef'
        raise ArgumentError, "Expected ECEF" unless reference_ecef.is_a?(ECEF)

        enu = self.to_enu
        enu.to_ecef(reference_ecef, reference_lla)
      end

      def self.from_ecef(ecef, reference_ecef, reference_lla = nil)
        require_relative 'ecef'
        raise ArgumentError, "Expected ECEF" unless ecef.is_a?(ECEF)
        raise ArgumentError, "Expected ECEF" unless reference_ecef.is_a?(ECEF)

        enu = ecef.to_enu(reference_ecef, reference_lla)
        enu.to_ned
      end

      def to_lla(reference_lla)
        require_relative 'lla'
        raise ArgumentError, "Expected LLA" unless reference_lla.is_a?(LLA)

        enu = self.to_enu
        enu.to_lla(reference_lla)
      end

      def self.from_lla(lla, reference_lla)
        require_relative 'lla'
        raise ArgumentError, "Expected LLA" unless lla.is_a?(LLA)
        raise ArgumentError, "Expected LLA" unless reference_lla.is_a?(LLA)

        lla.to_ned(reference_lla)
      end

      def to_utm(reference_lla, datum = WGS84)
        require_relative 'utm'
        require_relative 'lla'
        raise ArgumentError, "Expected LLA" unless reference_lla.is_a?(LLA)

        lla = self.to_lla(reference_lla)
        lla.to_utm(datum)
      end

      def self.from_utm(utm, reference_lla, datum = WGS84)
        require_relative 'utm'
        require_relative 'lla'
        raise ArgumentError, "Expected UTM" unless utm.is_a?(UTM)
        raise ArgumentError, "Expected LLA" unless reference_lla.is_a?(LLA)

        lla = utm.to_lla(datum)
        lla.to_ned(reference_lla)
      end

      def to_s(precision = 2)
        precision = precision.to_i
        if precision == 0
          "#{@n.round}, #{@e.round}, #{@d.round}"
        else
          format("%.#{precision}f, %.#{precision}f, %.#{precision}f", @n, @e, @d)
        end
      end

      def to_a
        [@n, @e, @d]
      end

      def self.from_array(array)
        new(n: array[0].to_f, e: array[1].to_f, d: array[2].to_f)
      end

      def self.from_string(string)
        parts = string.split(',').map(&:strip)
        new(n: parts[0].to_f, e: parts[1].to_f, d: parts[2].to_f)
      end

      def ==(other)
        return false unless other.is_a?(NED)

        delta_n = (@n - other.n).abs
        delta_e = (@e - other.e).abs
        delta_d = (@d - other.d).abs

        delta_n <= 1e-6 && delta_e <= 1e-6 && delta_d <= 1e-6
      end


      def horizontal_distance_to(other)
        raise ArgumentError, "Expected NED" unless other.is_a?(NED)

        dn = @n - other.n
        de = @e - other.e

        Math.sqrt(dn**2 + de**2)
      end

      # Local tangent-plane bearing to another NED point (degrees, 0-360).
      # For great-circle bearing across coordinate systems, use the universal bearing_to.
      def local_bearing_to(other)
        raise ArgumentError, "Expected NED" unless other.is_a?(NED)

        dn = other.n - @n
        de = other.e - @e

        bearing_rad = Math.atan2(de, dn)
        bearing_deg = bearing_rad * DEG_PER_RAD

        bearing_deg += 360 if bearing_deg < 0
        bearing_deg
      end

      # Local tangent-plane elevation angle to another NED point (degrees).
      # For elevation angle across coordinate systems, use the universal elevation_to.
      def local_elevation_angle_to(other)
        raise ArgumentError, "Expected NED" unless other.is_a?(NED)

        horizontal_dist = horizontal_distance_to(other)
        return 0.0 if horizontal_dist == 0.0

        vertical_diff = @d - other.d
        elevation_rad = Math.atan2(vertical_diff, horizontal_dist)
        elevation_rad * DEG_PER_RAD
      end

      def distance_to_origin
        Math.sqrt(@n**2 + @e**2 + @d**2)
      end

      def elevation_angle
        horizontal_dist = Math.sqrt(@n**2 + @e**2)
        return 0.0 if horizontal_dist == 0.0

        elevation_rad = Math.atan2(-@d, horizontal_dist)
        elevation_rad * DEG_PER_RAD
      end

      def bearing_from_origin
        bearing_rad = Math.atan2(@e, @n)
        bearing_deg = bearing_rad * DEG_PER_RAD

        bearing_deg += 360 if bearing_deg < 0
        bearing_deg
      end

      def horizontal_distance_to_origin
        Math.sqrt(@n**2 + @e**2)
      end
    end
  end
end
