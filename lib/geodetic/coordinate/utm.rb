# frozen_string_literal: true

require_relative '../datum'

module Geodetic
  module Coordinate
    class UTM
      attr_reader :easting, :northing, :altitude, :zone, :hemisphere
      alias_method :x, :easting
      alias_method :y, :northing
      alias_method :z, :altitude

      def initialize(easting: 0.0, northing: 0.0, altitude: 0.0, zone: 1, hemisphere: 'N')
        @easting = easting.to_f
        @northing = northing.to_f
        @altitude = altitude.to_f
        @zone = zone.to_i
        @hemisphere = hemisphere.to_s.upcase

        validate_parameters!
      end

      def easting=(value)
        value = value.to_f
        raise ArgumentError, "Easting must be positive" if value < 0
        @easting = value
      end

      def northing=(value)
        value = value.to_f
        raise ArgumentError, "Northing must be positive" if value < 0
        @northing = value
      end

      def altitude=(value)
        @altitude = value.to_f
      end

      def zone=(value)
        value = value.to_i
        raise ArgumentError, "UTM zone must be between 1 and 60" if value < 1 || value > 60
        @zone = value
      end

      def hemisphere=(value)
        value = value.to_s.upcase
        raise ArgumentError, "Hemisphere must be 'N' or 'S'" unless ['N', 'S'].include?(value)
        @hemisphere = value
      end

      def to_lla(datum = WGS84)
        k0 = 0.9996
        false_easting = 500000.0
        false_northing = @hemisphere == 'S' ? 10000000.0 : 0.0

        x = @easting - false_easting
        y = @northing - false_northing

        lon0_deg = (@zone - 1) * 6 - 180 + 3
        lon0_rad = lon0_deg * RAD_PER_DEG

        a = datum.a
        e2 = datum.e2
        e4 = e2 * e2
        e6 = e4 * e2

        # e1 for footpoint latitude series (NOT the same as first eccentricity e)
        e1 = (1 - Math.sqrt(1 - e2)) / (1 + Math.sqrt(1 - e2))

        m = y / k0
        mu = m / (a * (1 - e2 / 4 - 3 * e4 / 64 - 5 * e6 / 256))

        # Footpoint latitude using e1 series
        lat_rad = mu +
                  (3 * e1 / 2 - 27 * e1**3 / 32) * Math.sin(2 * mu) +
                  (21 * e1**2 / 16 - 55 * e1**4 / 32) * Math.sin(4 * mu) +
                  (151 * e1**3 / 96) * Math.sin(6 * mu) +
                  (1097 * e1**4 / 512) * Math.sin(8 * mu)

        cos_lat = Math.cos(lat_rad)
        sin_lat = Math.sin(lat_rad)
        tan_lat = Math.tan(lat_rad)

        n = a / Math.sqrt(1 - e2 * sin_lat**2)
        t = tan_lat**2
        c = e2 * cos_lat**2 / (1 - e2)
        r = a * (1 - e2) / (1 - e2 * sin_lat**2)**(3.0 / 2.0)
        d = x / (n * k0)

        lat_rad = lat_rad - (n * tan_lat / r) *
                  (d**2 / 2 - (5 + 3 * t + 10 * c - 4 * c**2 - 9 * e2 / (1 - e2)) * d**4 / 24 +
                   (61 + 90 * t + 298 * c + 45 * t**2 - 252 * e2 / (1 - e2) - 3 * c**2) * d**6 / 720)

        lon_rad = lon0_rad + (d - (1 + 2 * t + c) * d**3 / 6 +
                             (5 - 2 * c + 28 * t - 3 * c**2 + 8 * e2 / (1 - e2) + 24 * t**2) * d**5 / 120) / cos_lat

        lat_deg = lat_rad * DEG_PER_RAD
        lon_deg = lon_rad * DEG_PER_RAD

        lon_deg += 360 while lon_deg < -180
        lon_deg -= 360 while lon_deg > 180

        LLA.new(lat: lat_deg, lng: lon_deg, alt: @altitude)
      end

      def self.from_lla(lla, datum = WGS84)
        raise ArgumentError, "Expected LLA" unless lla.is_a?(LLA)

        lla.to_utm(datum)
      end

      def to_ecef(datum = WGS84)
        lla = self.to_lla(datum)
        lla.to_ecef(datum)
      end

      def self.from_ecef(ecef, datum = WGS84)
        raise ArgumentError, "Expected ECEF" unless ecef.is_a?(ECEF)

        ecef.to_utm(datum)
      end

      def to_enu(reference_lla, datum = WGS84)
        raise ArgumentError, "Expected LLA" unless reference_lla.is_a?(LLA)

        lla = self.to_lla(datum)
        lla.to_enu(reference_lla)
      end

      def self.from_enu(enu, reference_lla, datum = WGS84)
        raise ArgumentError, "Expected ENU" unless enu.is_a?(ENU)
        raise ArgumentError, "Expected LLA" unless reference_lla.is_a?(LLA)

        enu.to_utm(reference_lla, datum)
      end

      def to_ned(reference_lla, datum = WGS84)
        raise ArgumentError, "Expected LLA" unless reference_lla.is_a?(LLA)

        lla = self.to_lla(datum)
        lla.to_ned(reference_lla)
      end

      def self.from_ned(ned, reference_lla, datum = WGS84)
        raise ArgumentError, "Expected NED" unless ned.is_a?(NED)
        raise ArgumentError, "Expected LLA" unless reference_lla.is_a?(LLA)

        ned.to_utm(reference_lla, datum)
      end

      def to_mgrs(datum = WGS84, precision = 5)
        MGRS.from_utm(self, precision)
      end

      def self.from_mgrs(mgrs_coord, datum = WGS84)
        mgrs_coord.to_utm
      end

      def to_usng(datum = WGS84, precision = 5)
        USNG.from_utm(self, precision)
      end

      def self.from_usng(usng_coord, datum = WGS84)
        usng_coord.to_utm
      end

      def to_web_mercator(datum = WGS84)
        WebMercator.from_lla(to_lla(datum), datum)
      end

      def self.from_web_mercator(wm_coord, datum = WGS84)
        from_lla(wm_coord.to_lla(datum), datum)
      end

      def to_ups(datum = WGS84)
        UPS.from_lla(to_lla(datum), datum)
      end

      def self.from_ups(ups_coord, datum = WGS84)
        from_lla(ups_coord.to_lla(datum), datum)
      end

      def to_state_plane(zone_code, datum = WGS84)
        StatePlane.from_lla(to_lla(datum), zone_code, datum)
      end

      def self.from_state_plane(sp_coord, datum = WGS84)
        from_lla(sp_coord.to_lla(datum), datum)
      end

      def to_bng(datum = WGS84)
        BNG.from_lla(to_lla(datum))
      end

      def self.from_bng(bng_coord, datum = WGS84)
        from_lla(bng_coord.to_lla, datum)
      end

      def to_s(precision = 2)
        precision = precision.to_i
        if precision == 0
          "#{@easting.round}, #{@northing.round}, #{@altitude.round}, #{@zone}, #{@hemisphere}"
        else
          format("%.#{precision}f, %.#{precision}f, %.#{precision}f, %d, %s", @easting, @northing, @altitude, @zone, @hemisphere)
        end
      end

      def to_a
        [@easting, @northing, @altitude, @zone, @hemisphere]
      end

      def self.from_array(array)
        new(easting: array[0].to_f, northing: array[1].to_f, altitude: array[2].to_f, zone: array[3].to_i, hemisphere: array[4].to_s)
      end

      def self.from_string(string)
        parts = string.split(',').map(&:strip)
        new(easting: parts[0].to_f, northing: parts[1].to_f, altitude: parts[2].to_f, zone: parts[3].to_i, hemisphere: parts[4].to_s)
      end

      def ==(other)
        return false unless other.is_a?(UTM)

        delta_easting = (@easting - other.easting).abs
        delta_northing = (@northing - other.northing).abs
        delta_altitude = (@altitude - other.altitude).abs

        delta_easting <= 1e-6 && delta_northing <= 1e-6 && delta_altitude <= 1e-6 &&
        @zone == other.zone && @hemisphere == other.hemisphere
      end


      def same_zone?(other)
        raise ArgumentError, "Expected UTM" unless other.is_a?(UTM)

        @zone == other.zone && @hemisphere == other.hemisphere
      end

      def central_meridian
        (@zone - 1) * 6 - 180 + 3
      end

      private

      def validate_parameters!
        raise ArgumentError, "UTM zone must be between 1 and 60" if @zone < 1 || @zone > 60
        raise ArgumentError, "Hemisphere must be 'N' or 'S'" unless ['N', 'S'].include?(@hemisphere)
        raise ArgumentError, "Easting must be positive" if @easting < 0
        raise ArgumentError, "Northing must be positive" if @northing < 0
      end

      Coordinate.register_class(self)
    end
  end
end
