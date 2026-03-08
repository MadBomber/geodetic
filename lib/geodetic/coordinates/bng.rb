# frozen_string_literal: true

# British National Grid (BNG) Coordinate System
# Official coordinate system for Great Britain using OSGB36 datum
# Uses Transverse Mercator projection with specific parameters

module Geodetic
  module Coordinates
    class BNG
      require_relative '../datum'

      attr_reader :easting, :northing, :grid_ref

      # BNG Constants (OSGB36 datum)
      ORIGIN_LATITUDE = 49.0        # degrees
      ORIGIN_LONGITUDE = -2.0       # degrees
      SCALE_FACTOR = 0.9996012717   # Central meridian scale factor
      FALSE_EASTING = 400000.0      # meters
      FALSE_NORTHING = -100000.0    # meters

      # Grid square letters for BNG references
      GRID_SQUARES = [
        ['SV', 'SW', 'SX', 'SY', 'SZ', 'TV', 'TW'],
        ['SQ', 'SR', 'SS', 'ST', 'SU', 'TQ', 'TR'],
        ['SL', 'SM', 'SN', 'SO', 'SP', 'TL', 'TM'],
        ['SF', 'SG', 'SH', 'SJ', 'SK', 'TF', 'TG'],
        ['SA', 'SB', 'SC', 'SD', 'SE', 'TA', 'TB'],
        ['NV', 'NW', 'NX', 'NY', 'NZ', 'OV', 'OW'],
        ['NQ', 'NR', 'NS', 'NT', 'NU', 'OQ', 'OR'],
        ['NL', 'NM', 'NN', 'NO', 'NP', 'OL', 'OM'],
        ['NF', 'NG', 'NH', 'NJ', 'NK', 'OF', 'OG'],
        ['NA', 'NB', 'NC', 'ND', 'NE', 'OA', 'OB'],
        ['HV', 'HW', 'HX', 'HY', 'HZ', 'JV', 'JW'],
        ['HQ', 'HR', 'HS', 'HT', 'HU', 'JQ', 'JR'],
        ['HL', 'HM', 'HN', 'HO', 'HP', 'JL', 'JM']
      ]

      # OSGB36 datum (approximation - use Airy 1830 ellipsoid)
      OSGB36 = Struct.new(:name, :a, :b, :f, :e, :e2).new(
        'OSGB36',
        6377563.396,              # semi-major axis
        6356256.909,              # semi-minor axis
        1.0 / 299.3249646,        # flattening
        0.0816733743,             # first eccentricity (approx)
        0.006670540000096         # first eccentricity squared (approx)
      )

      def initialize(easting: 0.0, northing: 0.0, grid_ref: nil)
        if grid_ref
          parse_grid_reference(grid_ref)
        else
          @easting = easting.to_f
          @northing = northing.to_f
          @grid_ref = to_grid_reference
        end
      end

      def easting=(value)
        @easting = value.to_f
        @grid_ref = to_grid_reference
      end

      def northing=(value)
        @northing = value.to_f
        @grid_ref = to_grid_reference
      end

      def to_s(precision = 2)
        precision = precision.to_i
        if precision == 0
          "#{@easting.round}, #{@northing.round}"
        else
          format("%.#{precision}f, %.#{precision}f", @easting, @northing)
        end
      end

      def to_a
        [@easting, @northing]
      end

      def self.from_array(array)
        new(easting: array[0].to_f, northing: array[1].to_f)
      end

      def self.from_string(string)
        parts = string.split(',').map(&:strip)
        new(easting: parts[0].to_f, northing: parts[1].to_f)
      end

      def to_grid_reference(precision = 6)
        # Convert easting/northing to grid reference
        # Find 100km square
        grid_x = (@easting / 100000).floor
        grid_y = (@northing / 100000).floor

        # Clamp to valid grid bounds
        grid_x = [[0, grid_x].max, 6].min
        grid_y = [[0, grid_y].max, 12].min

        letters = GRID_SQUARES[12 - grid_y][grid_x]

        # Calculate position within square
        local_easting = @easting % 100000
        local_northing = @northing % 100000

        if precision == 0
          return letters
        end

        # Format coordinates to specified precision
        coord_format = "%0#{precision}d"
        east_str = coord_format % (local_easting * (10 ** precision) / 100000)
        north_str = coord_format % (local_northing * (10 ** precision) / 100000)

        "#{letters} #{east_str} #{north_str}"
      end

      def to_lla(datum = WGS84)
        # Convert from BNG to OSGB36 lat/lng using inverse Transverse Mercator
        osgb36_lla = transverse_mercator_inverse(OSGB36)

        # Convert from OSGB36 to requested datum (simplified - assumes WGS84)
        if datum == WGS84
          # Approximate OSGB36 to WGS84 transformation
          # This is a simplified transformation - real implementation would use Helmert parameters
          lat = osgb36_lla.lat - 0.00015  # rough approximation
          lng = osgb36_lla.lng + 0.00045  # rough approximation
          LLA.new(lat: lat, lng: lng, alt: osgb36_lla.alt)
        else
          osgb36_lla
        end
      end

      def self.from_lla(lla_coord, datum = WGS84)
        # Convert to OSGB36 if needed
        if datum == WGS84
          # Simplified WGS84 to OSGB36 transformation
          lat = lla_coord.lat + 0.00015
          lng = lla_coord.lng - 0.00045
          osgb36_lla = LLA.new(lat: lat, lng: lng, alt: lla_coord.alt)
        else
          osgb36_lla = lla_coord
        end

        # Convert to BNG using Transverse Mercator
        bng = transverse_mercator_forward(osgb36_lla, OSGB36)
        bng
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
        to_lla(datum).to_enu(reference_lla, datum)
      end

      def self.from_enu(enu_coord, reference_lla, datum = WGS84)
        lla_coord = enu_coord.to_lla(reference_lla, datum)
        from_lla(lla_coord, datum)
      end

      def to_ned(reference_lla, datum = WGS84)
        to_lla(datum).to_ned(reference_lla, datum)
      end

      def self.from_ned(ned_coord, reference_lla, datum = WGS84)
        lla_coord = ned_coord.to_lla(reference_lla, datum)
        from_lla(lla_coord, datum)
      end

      def to_mgrs(datum = WGS84, precision = 5)
        MGRS.from_lla(to_lla(datum), datum, precision)
      end

      def self.from_mgrs(mgrs_coord, datum = WGS84)
        lla_coord = mgrs_coord.to_lla(datum)
        from_lla(lla_coord, datum)
      end

      def to_usng(datum = WGS84, precision = 5)
        USNG.from_lla(to_lla(datum), datum, precision)
      end

      def self.from_usng(usng_coord, datum = WGS84)
        lla_coord = usng_coord.to_lla(datum)
        from_lla(lla_coord, datum)
      end

      def to_web_mercator(datum = WGS84)
        WebMercator.from_lla(to_lla(datum), datum)
      end

      def self.from_web_mercator(web_mercator_coord, datum = WGS84)
        lla_coord = web_mercator_coord.to_lla(datum)
        from_lla(lla_coord, datum)
      end

      def to_ups(datum = WGS84)
        UPS.from_lla(to_lla(datum), datum)
      end

      def self.from_ups(ups_coord, datum = WGS84)
        lla_coord = ups_coord.to_lla(datum)
        from_lla(lla_coord, datum)
      end

      def to_state_plane(zone_code, datum = WGS84)
        StatePlane.from_lla(to_lla(datum), zone_code, datum)
      end

      def self.from_state_plane(state_plane_coord, datum = WGS84)
        lla_coord = state_plane_coord.to_lla(datum)
        from_lla(lla_coord, datum)
      end

      def to_gh36(datum = WGS84, precision: 10)
        GH36.new(to_lla(datum), precision: precision)
      end

      def self.from_gh36(gh36_coord, datum = WGS84)
        lla_coord = gh36_coord.to_lla(datum)
        from_lla(lla_coord, datum)
      end

      def ==(other)
        return false unless other.is_a?(BNG)

        (@easting - other.easting).abs <= 1e-6 &&
        (@northing - other.northing).abs <= 1e-6
      end


      # Validate BNG coordinates
      def valid?
        # Check if coordinates fall within Great Britain bounds
        @easting >= 0 && @easting <= 700000 && @northing >= 0 && @northing <= 1300000
      end

      private

      def parse_grid_reference(grid_ref)
        grid_ref = grid_ref.upcase.gsub(/\s+/, ' ').strip

        if grid_ref.match(/^([A-Z]{2})\s?(\d+)\s?(\d+)$/)
          letters = $1
          east_digits = $2
          north_digits = $3

          # Find grid square
          grid_x = nil
          grid_y = nil

          GRID_SQUARES.each_with_index do |row, y|
            row.each_with_index do |square, x|
              if square == letters
                grid_x = x
                grid_y = 12 - y
                break
              end
            end
            break if grid_x
          end

          raise ArgumentError, "Invalid grid square: #{letters}" unless grid_x

          # Calculate coordinates
          precision = east_digits.length
          multiplier = 100000.0 / (10 ** precision)

          @easting = grid_x * 100000 + east_digits.to_i * multiplier
          @northing = grid_y * 100000 + north_digits.to_i * multiplier
          @grid_ref = grid_ref
        elsif grid_ref.match(/^([A-Z]{2})$/)
          letters = $1

          # Grid square only - use center point
          grid_x = nil
          grid_y = nil

          GRID_SQUARES.each_with_index do |row, y|
            row.each_with_index do |square, x|
              if square == letters
                grid_x = x
                grid_y = 12 - y
                break
              end
            end
            break if grid_x
          end

          raise ArgumentError, "Invalid grid square: #{letters}" unless grid_x

          @easting = grid_x * 100000 + 50000  # Center of square
          @northing = grid_y * 100000 + 50000  # Center of square
          @grid_ref = grid_ref
        else
          raise ArgumentError, "Invalid BNG grid reference format: #{grid_ref}"
        end
      end

      def transverse_mercator_inverse(datum)
        # Inverse Transverse Mercator projection from BNG to OSGB36 lat/lng
        a = datum.a
        e2 = datum.e2

        lat0_rad = ORIGIN_LATITUDE * RAD_PER_DEG
        lng0_rad = ORIGIN_LONGITUDE * RAD_PER_DEG
        k0 = SCALE_FACTOR

        # Adjust for false origin
        x = @easting - FALSE_EASTING
        y = @northing - FALSE_NORTHING

        # Simplified inverse calculation (full implementation is very complex)
        lat = lat0_rad + y / (a * k0)
        lng = lng0_rad + x / (a * k0 * Math.cos(lat0_rad))

        lat_deg = lat * DEG_PER_RAD
        lng_deg = lng * DEG_PER_RAD

        # Clamp to reasonable bounds
        lat_deg = [[-90.0, lat_deg].max, 90.0].min
        lng_deg = [[-180.0, lng_deg].max, 180.0].min

        LLA.new(lat: lat_deg, lng: lng_deg, alt: 0.0)
      end

      def self.transverse_mercator_forward(lla_coord, datum)
        # Forward Transverse Mercator projection from OSGB36 lat/lng to BNG
        a = datum.a
        e2 = datum.e2

        lat = lla_coord.lat * RAD_PER_DEG
        lng = lla_coord.lng * RAD_PER_DEG
        lat0_rad = ORIGIN_LATITUDE * RAD_PER_DEG
        lng0_rad = ORIGIN_LONGITUDE * RAD_PER_DEG
        k0 = SCALE_FACTOR

        # Simplified forward calculation
        x = a * k0 * (lng - lng0_rad) * Math.cos(lat0_rad)
        y = a * k0 * (lat - lat0_rad)

        # Apply false origin
        easting = x + FALSE_EASTING
        northing = y + FALSE_NORTHING

        new(easting: easting, northing: northing)
      end
    end
  end
end
