# frozen_string_literal: true

require_relative '../datum'

module Geodetic
  module Coordinates
    class ENU
      attr_reader :e, :n, :u
      alias_method :east, :e
      alias_method :north, :n
      alias_method :up, :u

      def initialize(e: 0.0, n: 0.0, u: 0.0)
        @e = e.to_f
        @n = n.to_f
        @u = u.to_f
      end

      def e=(value)
        @e = value.to_f
      end
      alias_method :east=, :e=

      def n=(value)
        @n = value.to_f
      end
      alias_method :north=, :n=

      def u=(value)
        @u = value.to_f
      end
      alias_method :up=, :u=

      def to_ecef(reference_ecef, reference_lla = nil)
        raise ArgumentError, "Expected ECEF" unless reference_ecef.is_a?(ECEF)

        if reference_lla.nil?
          reference_lla = reference_ecef.to_lla
        end

        lat_rad = reference_lla.lat * RAD_PER_DEG
        lon_rad = reference_lla.lng * RAD_PER_DEG

        sin_lat = Math.sin(lat_rad)
        cos_lat = Math.cos(lat_rad)
        sin_lon = Math.sin(lon_rad)
        cos_lon = Math.cos(lon_rad)

        delta_x = -sin_lon * @e - sin_lat * cos_lon * @n + cos_lat * cos_lon * @u
        delta_y = cos_lon * @e - sin_lat * sin_lon * @n + cos_lat * sin_lon * @u
        delta_z = cos_lat * @n + sin_lat * @u

        x = reference_ecef.x + delta_x
        y = reference_ecef.y + delta_y
        z = reference_ecef.z + delta_z

        ECEF.new(x: x, y: y, z: z)
      end

      def self.from_ecef(ecef, reference_ecef, reference_lla = nil)
        raise ArgumentError, "Expected ECEF" unless ecef.is_a?(ECEF)
        raise ArgumentError, "Expected ECEF" unless reference_ecef.is_a?(ECEF)

        ecef.to_enu(reference_ecef, reference_lla)
      end

      def to_ned
        NED.new(n: @n, e: @e, d: -@u)
      end

      def self.from_ned(ned)
        raise ArgumentError, "Expected NED" unless ned.is_a?(NED)

        ned.to_enu
      end

      def to_lla(reference_lla)
        raise ArgumentError, "Expected LLA" unless reference_lla.is_a?(LLA)

        reference_ecef = reference_lla.to_ecef
        ecef = self.to_ecef(reference_ecef, reference_lla)
        ecef.to_lla
      end

      def self.from_lla(lla, reference_lla)
        raise ArgumentError, "Expected LLA" unless lla.is_a?(LLA)
        raise ArgumentError, "Expected LLA" unless reference_lla.is_a?(LLA)

        lla.to_enu(reference_lla)
      end

      def to_utm(reference_lla, datum = WGS84)
        raise ArgumentError, "Expected LLA" unless reference_lla.is_a?(LLA)

        lla = self.to_lla(reference_lla)
        lla.to_utm(datum)
      end

      def self.from_utm(utm, reference_lla, datum = WGS84)
        raise ArgumentError, "Expected UTM" unless utm.is_a?(UTM)
        raise ArgumentError, "Expected LLA" unless reference_lla.is_a?(LLA)

        lla = utm.to_lla(datum)
        lla.to_enu(reference_lla)
      end

      def to_mgrs(reference_lla, datum = WGS84, precision = 5)
        MGRS.from_lla(to_lla(reference_lla), datum, precision)
      end

      def self.from_mgrs(mgrs_coord, reference_lla, datum = WGS84)
        lla = mgrs_coord.to_lla(datum)
        from_lla(lla, reference_lla)
      end

      def to_usng(reference_lla, datum = WGS84, precision = 5)
        USNG.from_lla(to_lla(reference_lla), datum, precision)
      end

      def self.from_usng(usng_coord, reference_lla, datum = WGS84)
        lla = usng_coord.to_lla(datum)
        from_lla(lla, reference_lla)
      end

      def to_web_mercator(reference_lla, datum = WGS84)
        WebMercator.from_lla(to_lla(reference_lla), datum)
      end

      def self.from_web_mercator(wm_coord, reference_lla, datum = WGS84)
        lla = wm_coord.to_lla(datum)
        from_lla(lla, reference_lla)
      end

      def to_ups(reference_lla, datum = WGS84)
        UPS.from_lla(to_lla(reference_lla), datum)
      end

      def self.from_ups(ups_coord, reference_lla, datum = WGS84)
        lla = ups_coord.to_lla(datum)
        from_lla(lla, reference_lla)
      end

      def to_state_plane(reference_lla, zone_code, datum = WGS84)
        StatePlane.from_lla(to_lla(reference_lla), zone_code, datum)
      end

      def self.from_state_plane(sp_coord, reference_lla, datum = WGS84)
        lla = sp_coord.to_lla(datum)
        from_lla(lla, reference_lla)
      end

      def to_bng(reference_lla)
        BNG.from_lla(to_lla(reference_lla))
      end

      def self.from_bng(bng_coord, reference_lla)
        lla = bng_coord.to_lla
        from_lla(lla, reference_lla)
      end

      def to_gh36(reference_lla, precision: 10)
        GH36.new(to_lla(reference_lla), precision: precision)
      end

      def self.from_gh36(gh36_coord, reference_lla)
        lla = gh36_coord.to_lla
        from_lla(lla, reference_lla)
      end

      def to_gh(reference_lla, precision: 12)
        GH.new(to_lla(reference_lla), precision: precision)
      end

      def self.from_gh(gh_coord, reference_lla)
        lla = gh_coord.to_lla
        from_lla(lla, reference_lla)
      end

      def to_s(precision = 2)
        precision = precision.to_i
        if precision == 0
          "#{@e.round}, #{@n.round}, #{@u.round}"
        else
          format("%.#{precision}f, %.#{precision}f, %.#{precision}f", @e, @n, @u)
        end
      end

      def to_a
        [@e, @n, @u]
      end

      def self.from_array(array)
        new(e: array[0].to_f, n: array[1].to_f, u: array[2].to_f)
      end

      def self.from_string(string)
        parts = string.split(',').map(&:strip)
        new(e: parts[0].to_f, n: parts[1].to_f, u: parts[2].to_f)
      end

      def ==(other)
        return false unless other.is_a?(ENU)

        delta_e = (@e - other.e).abs
        delta_n = (@n - other.n).abs
        delta_u = (@u - other.u).abs

        delta_e <= 1e-6 && delta_n <= 1e-6 && delta_u <= 1e-6
      end


      def horizontal_distance_to(other)
        raise ArgumentError, "Expected ENU" unless other.is_a?(ENU)

        de = @e - other.e
        dn = @n - other.n

        Math.sqrt(de**2 + dn**2)
      end

      # Local tangent-plane bearing to another ENU point (degrees, 0-360).
      # For great-circle bearing across coordinate systems, use the universal bearing_to.
      def local_bearing_to(other)
        raise ArgumentError, "Expected ENU" unless other.is_a?(ENU)

        de = other.e - @e
        dn = other.n - @n

        bearing_rad = Math.atan2(de, dn)
        bearing_deg = bearing_rad * DEG_PER_RAD

        bearing_deg += 360 if bearing_deg < 0
        bearing_deg
      end

      def distance_to_origin
        Math.sqrt(@e**2 + @n**2 + @u**2)
      end

      def bearing_from_origin
        bearing_rad = Math.atan2(@e, @n)
        bearing_deg = bearing_rad * DEG_PER_RAD

        bearing_deg += 360 if bearing_deg < 0
        bearing_deg
      end

      def horizontal_distance_to_origin
        Math.sqrt(@e**2 + @n**2)
      end
    end
  end
end
