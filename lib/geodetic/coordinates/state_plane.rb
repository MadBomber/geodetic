# State Plane Coordinate System (SPC)
# US state-based coordinate systems using various projections
# Each state has one or more zones with specific parameters

module Geodetic
  module Coordinates
    class StatePlane
      require_relative '../datum'

      attr_accessor :easting, :northing, :zone_code, :state, :datum

      # State Plane zone definitions (simplified subset - real implementation would have all zones)
      ZONES = {
        # California zones (Lambert Conformal Conic)
        'CA_I' => {
          state: 'California',
          zone: 'I',
          fips: '0401',
          epsg: '2225',
          projection: 'lambert_conformal_conic',
          central_meridian: -122.0,
          standard_parallel_1: 40.0,
          standard_parallel_2: 41.666667,
          latitude_of_origin: 39.333333,
          false_easting: 2000000.0,
          false_northing: 500000.0,
          units: 'US Survey Feet'
        },
        'CA_II' => {
          state: 'California',
          zone: 'II',
          fips: '0402',
          epsg: '2226',
          projection: 'lambert_conformal_conic',
          central_meridian: -122.0,
          standard_parallel_1: 38.333333,
          standard_parallel_2: 39.833333,
          latitude_of_origin: 37.666667,
          false_easting: 2000000.0,
          false_northing: 500000.0,
          units: 'US Survey Feet'
        },
        # Texas zones (Lambert Conformal Conic)
        'TX_NORTH' => {
          state: 'Texas',
          zone: 'North',
          fips: '4201',
          epsg: '2275',
          projection: 'lambert_conformal_conic',
          central_meridian: -101.5,
          standard_parallel_1: 34.65,
          standard_parallel_2: 36.183333,
          latitude_of_origin: 34.0,
          false_easting: 200000.0,
          false_northing: 1000000.0,
          units: 'US Survey Feet'
        },
        # Florida zones (Transverse Mercator)
        'FL_EAST' => {
          state: 'Florida',
          zone: 'East',
          fips: '0901',
          epsg: '2236',
          projection: 'transverse_mercator',
          central_meridian: -81.0,
          scale_factor: 0.9999411764705882,
          latitude_of_origin: 24.333333,
          false_easting: 200000.0,
          false_northing: 0.0,
          units: 'US Survey Feet'
        },
        # New York zones (Transverse Mercator)
        'NY_LONG_ISLAND' => {
          state: 'New York',
          zone: 'Long Island',
          fips: '3104',
          epsg: '2263',
          projection: 'transverse_mercator',
          central_meridian: -74.0,
          scale_factor: 0.9999,
          latitude_of_origin: 40.166667,
          false_easting: 300000.0,
          false_northing: 0.0,
          units: 'US Survey Feet'
        }
      }

      # Unit conversion factors
      METERS_PER_US_SURVEY_FOOT = 1200.0 / 3937.0
      US_SURVEY_FEET_PER_METER = 3937.0 / 1200.0
      METERS_PER_INTERNATIONAL_FOOT = 0.3048
      INTERNATIONAL_FEET_PER_METER = 1.0 / 0.3048

      def initialize(easting: 0.0, northing: 0.0, zone_code: 'CA_I', datum: WGS84)
        @easting = easting.to_f
        @northing = northing.to_f
        @zone_code = zone_code.to_s.upcase
        @datum = datum

        validate_zone
      end

      def to_s
        "#{@easting}, #{@northing}, #{@zone_code}"
      end

      def to_a
        [@easting, @northing, @zone_code]
      end

      def self.from_array(array)
        new(easting: array[0].to_f, northing: array[1].to_f, zone_code: array[2].to_s)
      end

      def self.from_string(string)
        parts = string.split(',').map(&:strip)
        new(easting: parts[0].to_f, northing: parts[1].to_f, zone_code: parts[2].to_s)
      end

      def zone_info
        ZONES[@zone_code]
      end

      def to_lla(datum = nil)
        require_relative 'lla'

        datum ||= @datum
        zone_info = ZONES[@zone_code]

        case zone_info[:projection]
        when 'lambert_conformal_conic'
          lambert_conformal_conic_to_lla(zone_info, datum)
        when 'transverse_mercator'
          transverse_mercator_to_lla(zone_info, datum)
        else
          raise "Unsupported projection: #{zone_info[:projection]}"
        end
      end

      def self.from_lla(lla_coord, zone_code, datum = WGS84)
        zone_info = ZONES[zone_code.to_s.upcase]
        raise "Unknown zone: #{zone_code}" unless zone_info

        case zone_info[:projection]
        when 'lambert_conformal_conic'
          from_lla_lambert_conformal_conic(lla_coord, zone_code, zone_info, datum)
        when 'transverse_mercator'
          from_lla_transverse_mercator(lla_coord, zone_code, zone_info, datum)
        else
          raise "Unsupported projection: #{zone_info[:projection]}"
        end
      end

      def to_ecef(datum = nil)
        to_lla(datum).to_ecef(datum || @datum)
      end

      def self.from_ecef(ecef_coord, zone_code, datum = WGS84)
        lla_coord = ecef_coord.to_lla(datum)
        from_lla(lla_coord, zone_code, datum)
      end

      def to_utm(datum = nil)
        to_lla(datum).to_utm(datum || @datum)
      end

      def self.from_utm(utm_coord, zone_code, datum = WGS84)
        lla_coord = utm_coord.to_lla(datum)
        from_lla(lla_coord, zone_code, datum)
      end

      def to_enu(reference_lla, datum = nil)
        to_lla(datum).to_enu(reference_lla, datum || @datum)
      end

      def self.from_enu(enu_coord, reference_lla, zone_code, datum = WGS84)
        lla_coord = enu_coord.to_lla(reference_lla, datum)
        from_lla(lla_coord, zone_code, datum)
      end

      def to_ned(reference_lla, datum = nil)
        to_lla(datum).to_ned(reference_lla, datum || @datum)
      end

      def self.from_ned(ned_coord, reference_lla, zone_code, datum = WGS84)
        lla_coord = ned_coord.to_lla(reference_lla, datum)
        from_lla(lla_coord, zone_code, datum)
      end

      def to_mgrs(datum = nil, precision = 5)
        require_relative 'mgrs'
        MGRS.from_lla(to_lla(datum), datum || @datum, precision)
      end

      def self.from_mgrs(mgrs_coord, zone_code, datum = WGS84)
        lla_coord = mgrs_coord.to_lla(datum)
        from_lla(lla_coord, zone_code, datum)
      end

      def to_usng(datum = nil, precision = 5)
        require_relative 'usng'
        USNG.from_lla(to_lla(datum), datum || @datum, precision)
      end

      def self.from_usng(usng_coord, zone_code, datum = WGS84)
        lla_coord = usng_coord.to_lla(datum)
        from_lla(lla_coord, zone_code, datum)
      end

      def to_web_mercator(datum = nil)
        require_relative 'web_mercator'
        WebMercator.from_lla(to_lla(datum), datum || @datum)
      end

      def self.from_web_mercator(web_mercator_coord, zone_code, datum = WGS84)
        lla_coord = web_mercator_coord.to_lla(datum)
        from_lla(lla_coord, zone_code, datum)
      end

      def to_ups(datum = nil)
        require_relative 'ups'
        UPS.from_lla(to_lla(datum), datum || @datum)
      end

      def self.from_ups(ups_coord, zone_code, datum = WGS84)
        lla_coord = ups_coord.to_lla(datum)
        from_lla(lla_coord, zone_code, datum)
      end

      # Unit conversion methods
      def to_meters
        zone_info = ZONES[@zone_code]
        if zone_info[:units] == 'US Survey Feet'
          easting_m = @easting * METERS_PER_US_SURVEY_FOOT
          northing_m = @northing * METERS_PER_US_SURVEY_FOOT
        else
          easting_m = @easting
          northing_m = @northing
        end

        StatePlane.new(easting: easting_m, northing: northing_m, zone_code: @zone_code, datum: @datum)
      end

      def to_us_survey_feet
        zone_info = ZONES[@zone_code]
        if zone_info[:units] == 'US Survey Feet'
          return self
        else
          easting_ft = @easting * US_SURVEY_FEET_PER_METER
          northing_ft = @northing * US_SURVEY_FEET_PER_METER
          StatePlane.new(easting: easting_ft, northing: northing_ft, zone_code: @zone_code, datum: @datum)
        end
      end

      # Distance calculation
      def ==(other)
        return false unless other.is_a?(StatePlane)

        (@easting - other.easting).abs <= 1e-6 &&
        (@northing - other.northing).abs <= 1e-6 &&
        @zone_code == other.zone_code
      end

      def distance_to(other_coord)
        # Ensure both coordinates are in the same units
        if @zone_code != other_coord.zone_code
          # Convert to common coordinate system (LLA) for distance calculation
          lla1 = self.to_lla
          lla2 = other_coord.to_lla
          return lla1.distance_to(lla2)
        end

        dx = @easting - other_coord.easting
        dy = @northing - other_coord.northing
        Math.sqrt(dx * dx + dy * dy)
      end

      def valid?
        ZONES.key?(@zone_code)
      end

      # Get all available zones for a state
      def self.zones_for_state(state_name)
        ZONES.select { |code, info| info[:state].downcase == state_name.downcase }
      end

      # Find appropriate zone for a given LLA coordinate
      def self.find_zone_for_lla(lla_coord, state_name = nil)
        # This is a simplified version - real implementation would use precise zone boundaries
        candidate_zones = state_name ? zones_for_state(state_name) : ZONES

        # For now, return the first zone in the state (in practice, would check boundaries)
        candidate_zones.keys.first
      end

      private

      def validate_zone
        unless ZONES.key?(@zone_code)
          raise "Unknown State Plane zone: #{@zone_code}"
        end
      end

      def lambert_conformal_conic_to_lla(zone_info, datum)
        # Lambert Conformal Conic inverse projection
        a = datum.a
        e = datum.e
        e2 = datum.e2

        # Zone parameters
        lat0_rad = zone_info[:latitude_of_origin] * RAD_PER_DEG
        lon0_rad = zone_info[:central_meridian] * RAD_PER_DEG
        phi1_rad = zone_info[:standard_parallel_1] * RAD_PER_DEG
        phi2_rad = zone_info[:standard_parallel_2] * RAD_PER_DEG
        false_easting = zone_info[:false_easting]
        false_northing = zone_info[:false_northing]

        # Convert to meters if necessary
        x = @easting
        y = @northing
        if zone_info[:units] == 'US Survey Feet'
          x = x * METERS_PER_US_SURVEY_FOOT - false_easting * METERS_PER_US_SURVEY_FOOT
          y = y * METERS_PER_US_SURVEY_FOOT - false_northing * METERS_PER_US_SURVEY_FOOT
        else
          x = x - false_easting
          y = y - false_northing
        end

        # Lambert Conformal Conic calculations (simplified)
        # This is a complex calculation - using simplified approximation
        lat = lat0_rad + (y / a) * DEG_PER_RAD
        lng = lon0_rad + (x / (a * Math.cos(lat0_rad))) * DEG_PER_RAD

        lat = [[-90.0, lat * DEG_PER_RAD].max, 90.0].min
        lng = [[-180.0, lng * DEG_PER_RAD].max, 180.0].min

        LLA.new(lat: lat, lng: lng, alt: 0.0)
      end

      def transverse_mercator_to_lla(zone_info, datum)
        # Transverse Mercator inverse projection
        a = datum.a
        e = datum.e
        e2 = datum.e2

        # Zone parameters
        lat0_rad = zone_info[:latitude_of_origin] * RAD_PER_DEG
        lon0_rad = zone_info[:central_meridian] * RAD_PER_DEG
        k0 = zone_info[:scale_factor] || 0.9996
        false_easting = zone_info[:false_easting]
        false_northing = zone_info[:false_northing]

        # Convert to meters if necessary
        x = @easting
        y = @northing
        if zone_info[:units] == 'US Survey Feet'
          x = (x - false_easting) * METERS_PER_US_SURVEY_FOOT
          y = (y - false_northing) * METERS_PER_US_SURVEY_FOOT
        else
          x = x - false_easting
          y = y - false_northing
        end

        # Simplified Transverse Mercator inverse (approximation)
        lat = lat0_rad + (y / (a * k0))
        lng = lon0_rad + (x / (a * k0 * Math.cos(lat0_rad)))

        lat = lat * DEG_PER_RAD
        lng = lng * DEG_PER_RAD

        lat = [[-90.0, lat].max, 90.0].min
        lng = [[-180.0, lng].max, 180.0].min

        LLA.new(lat: lat, lng: lng, alt: 0.0)
      end

      def self.from_lla_lambert_conformal_conic(lla_coord, zone_code, zone_info, datum)
        # Lambert Conformal Conic forward projection (simplified)
        lat = lla_coord.lat * RAD_PER_DEG
        lng = lla_coord.lng * RAD_PER_DEG

        lat0_rad = zone_info[:latitude_of_origin] * RAD_PER_DEG
        lon0_rad = zone_info[:central_meridian] * RAD_PER_DEG

        a = datum.a

        # Simplified calculation
        x = a * (lng - lon0_rad) * Math.cos(lat0_rad)
        y = a * (lat - lat0_rad)

        # Apply false easting/northing
        if zone_info[:units] == 'US Survey Feet'
          x = x * US_SURVEY_FEET_PER_METER + zone_info[:false_easting]
          y = y * US_SURVEY_FEET_PER_METER + zone_info[:false_northing]
        else
          x = x + zone_info[:false_easting]
          y = y + zone_info[:false_northing]
        end

        new(easting: x, northing: y, zone_code: zone_code, datum: datum)
      end

      def self.from_lla_transverse_mercator(lla_coord, zone_code, zone_info, datum)
        # Transverse Mercator forward projection (simplified)
        lat = lla_coord.lat * RAD_PER_DEG
        lng = lla_coord.lng * RAD_PER_DEG

        lat0_rad = zone_info[:latitude_of_origin] * RAD_PER_DEG
        lon0_rad = zone_info[:central_meridian] * RAD_PER_DEG
        k0 = zone_info[:scale_factor] || 0.9996

        a = datum.a

        # Simplified calculation
        x = a * k0 * (lng - lon0_rad) * Math.cos(lat0_rad)
        y = a * k0 * (lat - lat0_rad)

        # Apply false easting/northing
        if zone_info[:units] == 'US Survey Feet'
          x = x * US_SURVEY_FEET_PER_METER + zone_info[:false_easting]
          y = y * US_SURVEY_FEET_PER_METER + zone_info[:false_northing]
        else
          x = x + zone_info[:false_easting]
          y = y + zone_info[:false_northing]
        end

        new(easting: x, northing: y, zone_code: zone_code, datum: datum)
      end
    end
  end
end
