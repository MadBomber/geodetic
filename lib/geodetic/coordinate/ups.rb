# frozen_string_literal: true

# Universal Polar Stereographic (UPS) Coordinate System
# Used for polar regions not covered by UTM (north of 84°N and south of 80°S)

module Geodetic
  module Coordinate
    class UPS
      require_relative '../datum'

      attr_reader :easting, :northing, :hemisphere, :zone

      # UPS Constants
      FALSE_EASTING = 2000000.0   # meters
      FALSE_NORTHING = 2000000.0  # meters
      SCALE_FACTOR = 0.994        # Central scale factor

      # UPS covers two zones: North (Y,Z) and South (A,B)
      NORTH_ZONES = ['Y', 'Z']
      SOUTH_ZONES = ['A', 'B']

      def initialize(easting: 0.0, northing: 0.0, hemisphere: 'N', zone: 'Y')
        @easting = easting.to_f
        @northing = northing.to_f
        @hemisphere = hemisphere.upcase
        @zone = zone.upcase

        validate_zone
      end

      def easting=(value)
        @easting = value.to_f
      end

      def northing=(value)
        @northing = value.to_f
      end

      def hemisphere=(value)
        value = value.to_s.upcase
        old_hemisphere = @hemisphere
        @hemisphere = value
        unless valid?
          @hemisphere = old_hemisphere
          raise ArgumentError, "Invalid UPS hemisphere '#{value}' for zone '#{@zone}'"
        end
      end

      def zone=(value)
        value = value.to_s.upcase
        old_zone = @zone
        @zone = value
        unless valid?
          @zone = old_zone
          raise ArgumentError, "Invalid UPS zone '#{value}' for hemisphere '#{@hemisphere}'"
        end
      end

      def to_s(precision = 2)
        precision = precision.to_i
        if precision == 0
          "#{@easting.round}, #{@northing.round}, #{@hemisphere}, #{@zone}"
        else
          format("%.#{precision}f, %.#{precision}f, %s, %s", @easting, @northing, @hemisphere, @zone)
        end
      end

      def to_a
        [@easting, @northing, @hemisphere, @zone]
      end

      def self.from_array(array)
        new(easting: array[0].to_f, northing: array[1].to_f, hemisphere: array[2].to_s, zone: array[3].to_s)
      end

      def self.from_string(string)
        parts = string.split(',').map(&:strip)
        new(easting: parts[0].to_f, northing: parts[1].to_f, hemisphere: parts[2].to_s, zone: parts[3].to_s)
      end

      def to_lla(datum = WGS84)
        a = datum.a
        e = datum.e
        e2 = datum.e2

        # Adjust for false origin
        x = @easting - FALSE_EASTING
        y = @northing - FALSE_NORTHING

        # Calculate polar stereographic parameters
        rho = Math.sqrt(x * x + y * y)

        if rho < 1e-10  # At pole
          lat = @hemisphere == 'N' ? 90.0 : -90.0
          lng = 0.0
        else
          # Iterative calculation for latitude
          if @hemisphere == 'N'
            c = 2.0 * Math.atan(rho / (2.0 * a * SCALE_FACTOR * ((1.0 - e) / (1.0 + e)) ** (e / 2.0)))
            lat = (Math::PI / 2.0) - c
          else
            c = 2.0 * Math.atan(rho / (2.0 * a * SCALE_FACTOR * ((1.0 + e) / (1.0 - e)) ** (e / 2.0)))
            lat = c - (Math::PI / 2.0)
          end

          # Iterative refinement for latitude
          5.times do
            sin_lat = Math.sin(lat)
            if @hemisphere == 'N'
              t = Math.tan((Math::PI / 4.0) - (lat / 2.0)) / ((1.0 - e * sin_lat) / (1.0 + e * sin_lat)) ** (e / 2.0)
              lat = (Math::PI / 2.0) - 2.0 * Math.atan(t * rho / (2.0 * a * SCALE_FACTOR))
            else
              t = Math.tan((Math::PI / 4.0) + (lat / 2.0)) / ((1.0 + e * sin_lat) / (1.0 - e * sin_lat)) ** (e / 2.0)
              lat = 2.0 * Math.atan(t * rho / (2.0 * a * SCALE_FACTOR)) - (Math::PI / 2.0)
            end
          end

          lat *= DEG_PER_RAD

          # Calculate longitude
          if @hemisphere == 'N'
            lng = Math.atan2(x, -y) * DEG_PER_RAD
          else
            lng = Math.atan2(x, y) * DEG_PER_RAD
          end

          # Normalize longitude
          lng = lng - 360.0 while lng > 180.0
          lng = lng + 360.0 while lng < -180.0
        end

        LLA.new(lat: lat, lng: lng, alt: 0.0)
      end

      def self.from_lla(lla_coord, datum = WGS84)
        lat = lla_coord.lat
        lng = lla_coord.lng

        # Determine hemisphere and zone
        hemisphere = lat >= 0 ? 'N' : 'S'

        # Determine zone based on longitude
        if hemisphere == 'N'
          zone = (lng >= 0) ? 'Z' : 'Y'
        else
          zone = (lng >= 0) ? 'B' : 'A'
        end

        a = datum.a
        e = datum.e

        lat_rad = lat * RAD_PER_DEG
        lng_rad = lng * RAD_PER_DEG

        sin_lat = Math.sin(lat_rad)

        # Calculate polar stereographic projection
        if lat.abs == 90.0  # At pole
          x = 0.0
          y = 0.0
        else
          if hemisphere == 'N'
            t = Math.tan((Math::PI / 4.0) - (lat_rad / 2.0)) * ((1.0 + e * sin_lat) / (1.0 - e * sin_lat)) ** (e / 2.0)
            rho = 2.0 * a * SCALE_FACTOR * t
            x = rho * Math.sin(lng_rad)
            y = -rho * Math.cos(lng_rad)
          else
            t = Math.tan((Math::PI / 4.0) + (lat_rad / 2.0)) * ((1.0 - e * sin_lat) / (1.0 + e * sin_lat)) ** (e / 2.0)
            rho = 2.0 * a * SCALE_FACTOR * t
            x = rho * Math.sin(lng_rad)
            y = rho * Math.cos(lng_rad)
          end
        end

        # Apply false origin
        easting = x + FALSE_EASTING
        northing = y + FALSE_NORTHING

        new(easting: easting, northing: northing, hemisphere: hemisphere, zone: zone)
      end

      def to_ecef(datum = WGS84)
        to_lla(datum).to_ecef(datum)
      end

      def self.from_ecef(ecef_coord, datum = WGS84)
        lla_coord = ecef_coord.to_lla(datum)
        from_lla(lla_coord, datum)
      end

      def to_utm(datum = WGS84)
        to_lla(datum).to_utm(datum)
      end

      def self.from_utm(utm_coord, datum = WGS84)
        lla_coord = utm_coord.to_lla(datum)
        from_lla(lla_coord, datum)
      end

      def to_enu(reference_lla, datum = WGS84)
        to_lla(datum).to_enu(reference_lla)
      end

      def self.from_enu(enu_coord, reference_lla, datum = WGS84)
        lla_coord = enu_coord.to_lla(reference_lla)
        from_lla(lla_coord, datum)
      end

      def to_ned(reference_lla, datum = WGS84)
        to_lla(datum).to_ned(reference_lla)
      end

      def self.from_ned(ned_coord, reference_lla, datum = WGS84)
        lla_coord = ned_coord.to_lla(reference_lla)
        from_lla(lla_coord, datum)
      end

      def to_mgrs(datum = WGS84, precision = 5)
        MGRS.from_lla(to_lla(datum), datum, precision)
      end

      def self.from_mgrs(mgrs_coord, datum = WGS84)
        lla_coord = mgrs_coord.to_lla(datum)
        from_lla(lla_coord, datum)
      end

      def to_web_mercator(datum = WGS84)
        WebMercator.from_lla(to_lla(datum), datum)
      end

      def self.from_web_mercator(web_mercator_coord, datum = WGS84)
        lla_coord = web_mercator_coord.to_lla(datum)
        from_lla(lla_coord, datum)
      end

      def to_usng(datum = WGS84, precision = 5)
        USNG.from_lla(to_lla(datum), datum, precision)
      end

      def self.from_usng(usng_coord, datum = WGS84)
        lla_coord = usng_coord.to_lla(datum)
        from_lla(lla_coord, datum)
      end

      def to_bng(datum = WGS84)
        BNG.from_lla(to_lla(datum), datum)
      end

      def self.from_bng(bng_coord, datum = WGS84)
        lla_coord = bng_coord.to_lla(datum)
        from_lla(lla_coord, datum)
      end

      def to_state_plane(zone_code, datum = WGS84)
        StatePlane.from_lla(to_lla(datum), zone_code, datum)
      end

      def self.from_state_plane(sp_coord, datum = WGS84)
        lla_coord = sp_coord.to_lla(datum)
        from_lla(lla_coord, datum)
      end

      def ==(other)
        return false unless other.is_a?(UPS)

        (@easting - other.easting).abs <= 1e-6 &&
        (@northing - other.northing).abs <= 1e-6 &&
        @hemisphere == other.hemisphere && @zone == other.zone
      end


      # Grid convergence calculation
      def grid_convergence(datum = WGS84)
        lla = to_lla(datum)
        lng_rad = lla.lng * RAD_PER_DEG

        if @hemisphere == 'N'
          convergence = lng_rad * DEG_PER_RAD
        else
          convergence = -lng_rad * DEG_PER_RAD
        end

        convergence
      end

      # Scale factor at point
      def point_scale_factor(datum = WGS84)
        lla = to_lla(datum)
        lat_rad = lla.lat.abs * RAD_PER_DEG

        e = datum.e
        sin_lat = Math.sin(lat_rad)

        # Simplified scale factor calculation
        m = Math.cos(lat_rad) / Math.sqrt(1.0 - e * e * sin_lat * sin_lat)
        t = Math.tan((Math::PI / 4.0) - (lat_rad / 2.0)) * ((1.0 + e * sin_lat) / (1.0 - e * sin_lat)) ** (e / 2.0)

        scale = SCALE_FACTOR * (1.0 + t * t) / (2.0 * m)
        scale
      end

      def valid?
        (@hemisphere == 'N' && NORTH_ZONES.include?(@zone)) ||
        (@hemisphere == 'S' && SOUTH_ZONES.include?(@zone))
      end

      private

      def validate_zone
        unless valid?
          raise ArgumentError, "Invalid UPS zone '#{@zone}' for hemisphere '#{@hemisphere}'"
        end
      end

      Coordinate.register_class(self, hash_conversion_style: :with_datum)
    end
  end
end
