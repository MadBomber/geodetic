# frozen_string_literal: true

require_relative '../datum'

module Geodetic
  module Coordinates
    class ECEF
      attr_reader :x, :y, :z

      def initialize(x: 0.0, y: 0.0, z: 0.0)
        @x = x.to_f
        @y = y.to_f
        @z = z.to_f
      end

      def x=(value)
        @x = value.to_f
      end

      def y=(value)
        @y = value.to_f
      end

      def z=(value)
        @z = value.to_f
      end

      def to_lla(datum = WGS84)
        a  = datum.a
        e2 = datum.e2

        small_delta = 1e-12

        longitude = Math.atan2(@y, @x)
        longitude_deg = longitude * DEG_PER_RAD

        p = Math.sqrt(@x**2 + @y**2)

        latitude = Math.atan2(@z, p * (1 - e2))
        altitude = 0.0

        max_iterations = 100
        iteration = 0

        # Special case: at or near poles, cos(lat) ≈ 0 causes division instability
        if p < 1e-10
          latitude_deg = @z >= 0 ? 90.0 : -90.0
          n = a / Math.sqrt(1 - e2)
          altitude = @z.abs - n * (1 - e2)
          return LLA.new(lat: latitude_deg, lng: longitude_deg, alt: altitude)
        end

        loop do
          iteration += 1
          prev_latitude = latitude
          prev_altitude = altitude

          sin_lat = Math.sin(latitude)
          cos_lat = Math.cos(latitude)

          n = a / Math.sqrt(1 - e2 * sin_lat**2)
          altitude = (p / cos_lat) - n
          latitude = Math.atan2(@z, p * (1 - e2 * n / (n + altitude)))

          lat_diff = (latitude - prev_latitude).abs
          alt_diff = (altitude - prev_altitude).abs

          break if lat_diff < small_delta && alt_diff < small_delta
          break if iteration >= max_iterations
        end

        latitude_deg = latitude * DEG_PER_RAD
        LLA.new(lat: latitude_deg, lng: longitude_deg, alt: altitude)
      end

      def self.from_lla(lla, datum = WGS84)
        raise ArgumentError, "Expected LLA" unless lla.is_a?(LLA)

        lla.to_ecef(datum)
      end

      def to_enu(reference_ecef, reference_lla = nil)
        raise ArgumentError, "Expected ECEF" unless reference_ecef.is_a?(ECEF)

        if reference_lla.nil?
          reference_lla = reference_ecef.to_lla
        end

        delta_x = @x - reference_ecef.x
        delta_y = @y - reference_ecef.y
        delta_z = @z - reference_ecef.z

        lat_rad = reference_lla.lat * RAD_PER_DEG
        lon_rad = reference_lla.lng * RAD_PER_DEG

        sin_lat = Math.sin(lat_rad)
        cos_lat = Math.cos(lat_rad)
        sin_lon = Math.sin(lon_rad)
        cos_lon = Math.cos(lon_rad)

        e = -sin_lon * delta_x + cos_lon * delta_y
        n = -sin_lat * cos_lon * delta_x - sin_lat * sin_lon * delta_y + cos_lat * delta_z
        u = cos_lat * cos_lon * delta_x + cos_lat * sin_lon * delta_y + sin_lat * delta_z

        ENU.new(e: e, n: n, u: u)
      end

      def self.from_enu(enu, reference_ecef, reference_lla = nil)
        raise ArgumentError, "Expected ENU" unless enu.is_a?(ENU)
        raise ArgumentError, "Expected ECEF" unless reference_ecef.is_a?(ECEF)

        enu.to_ecef(reference_ecef, reference_lla)
      end

      def to_ned(reference_ecef, reference_lla = nil)
        enu = self.to_enu(reference_ecef, reference_lla)
        enu.to_ned
      end

      def self.from_ned(ned, reference_ecef, reference_lla = nil)
        raise ArgumentError, "Expected NED" unless ned.is_a?(NED)
        raise ArgumentError, "Expected ECEF" unless reference_ecef.is_a?(ECEF)

        ned.to_ecef(reference_ecef, reference_lla)
      end

      def to_utm(datum = WGS84)
        lla = self.to_lla(datum)
        lla.to_utm(datum)
      end

      def self.from_utm(utm, datum = WGS84)
        raise ArgumentError, "Expected UTM" unless utm.is_a?(UTM)

        lla = utm.to_lla(datum)
        lla.to_ecef(datum)
      end

      def to_mgrs(datum = WGS84, precision = 5)
        MGRS.from_lla(to_lla(datum), datum, precision)
      end

      def self.from_mgrs(mgrs_coord, datum = WGS84)
        mgrs_coord.to_ecef(datum)
      end

      def to_usng(datum = WGS84, precision = 5)
        USNG.from_lla(to_lla(datum), datum, precision)
      end

      def self.from_usng(usng_coord, datum = WGS84)
        usng_coord.to_ecef(datum)
      end

      def to_web_mercator(datum = WGS84)
        WebMercator.from_lla(to_lla(datum), datum)
      end

      def self.from_web_mercator(wm_coord, datum = WGS84)
        wm_coord.to_ecef(datum)
      end

      def to_ups(datum = WGS84)
        UPS.from_lla(to_lla(datum), datum)
      end

      def self.from_ups(ups_coord, datum = WGS84)
        ups_coord.to_ecef(datum)
      end

      def to_state_plane(zone_code, datum = WGS84)
        StatePlane.from_lla(to_lla(datum), zone_code, datum)
      end

      def self.from_state_plane(sp_coord, datum = WGS84)
        sp_coord.to_ecef(datum)
      end

      def to_bng(datum = WGS84)
        BNG.from_lla(to_lla(datum))
      end

      def self.from_bng(bng_coord, datum = WGS84)
        bng_coord.to_ecef(datum)
      end

      def to_gh36(precision: 10)
        GH36.new(to_lla, precision: precision)
      end

      def self.from_gh36(gh36_coord, datum = WGS84)
        gh36_coord.to_ecef(datum)
      end

      def to_gh(precision: 12)
        GH.new(to_lla, precision: precision)
      end

      def self.from_gh(gh_coord, datum = WGS84)
        gh_coord.to_ecef(datum)
      end

      def to_s(precision = 2)
        precision = precision.to_i
        if precision == 0
          "#{@x.round}, #{@y.round}, #{@z.round}"
        else
          format("%.#{precision}f, %.#{precision}f, %.#{precision}f", @x, @y, @z)
        end
      end

      def to_a
        [@x, @y, @z]
      end

      def self.from_array(array)
        new(x: array[0].to_f, y: array[1].to_f, z: array[2].to_f)
      end

      def self.from_string(string)
        parts = string.split(',').map(&:strip)
        new(x: parts[0].to_f, y: parts[1].to_f, z: parts[2].to_f)
      end

      def ==(other)
        return false unless other.is_a?(ECEF)

        delta_x = (@x - other.x).abs
        delta_y = (@y - other.y).abs
        delta_z = (@z - other.z).abs

        delta_x <= 1e-6 && delta_y <= 1e-6 && delta_z <= 1e-6
      end

    end
  end
end
