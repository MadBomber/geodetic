# frozen_string_literal: true

# US National Grid (USNG) Coordinate System
# Based on MGRS but uses a slightly different format and always uses meter precision
# Used primarily within the United States for emergency services and land management

module Geodetic
  module Coordinates
    class USNG
      require_relative '../datum'
      require_relative 'mgrs'

      attr_reader :grid_zone_designator, :square_identifier, :easting, :northing, :precision

      def initialize(usng_string: nil, grid_zone: nil, square_id: nil, easting: nil, northing: nil, precision: 5)
        if usng_string
          parse_usng_string(usng_string)
        else
          @grid_zone_designator = grid_zone
          @square_identifier = square_id
          @easting = easting.to_f
          @northing = northing.to_f
          @precision = precision
        end
      end

      def to_s
        if @precision == 1
          "#{@grid_zone_designator} #{@square_identifier}"
        else
          east_str = ("%0#{@precision}d" % (@easting / (10 ** (5 - @precision)))).to_s
          north_str = ("%0#{@precision}d" % (@northing / (10 ** (5 - @precision)))).to_s
          "#{@grid_zone_designator} #{@square_identifier} #{east_str} #{north_str}"
        end
      end

      def self.from_string(string)
        new(usng_string: string)
      end

      # Convert to MGRS (the underlying format)
      def to_mgrs
        mgrs_string = "#{@grid_zone_designator}#{@square_identifier}"
        if @precision > 1
          east_str = ("%0#{@precision}d" % (@easting / (10 ** (5 - @precision)))).to_s
          north_str = ("%0#{@precision}d" % (@northing / (10 ** (5 - @precision)))).to_s
          mgrs_string += "#{east_str}#{north_str}"
        end
        MGRS.new(mgrs_string: mgrs_string)
      end

      def self.from_mgrs(mgrs_coord)
        # Extract components from MGRS
        grid_zone = mgrs_coord.grid_zone_designator
        square_id = mgrs_coord.square_identifier
        easting = mgrs_coord.easting
        northing = mgrs_coord.northing
        precision = mgrs_coord.precision

        new(grid_zone: grid_zone, square_id: square_id, easting: easting, northing: northing, precision: precision)
      end

      def to_utm
        to_mgrs.to_utm
      end

      def self.from_utm(utm_coord, precision = 5)
        mgrs_coord = MGRS.from_utm(utm_coord, precision)
        from_mgrs(mgrs_coord)
      end

      def to_lla(datum = WGS84)
        to_mgrs.to_lla(datum)
      end

      def self.from_lla(lla_coord, datum = WGS84, precision = 5)
        mgrs_coord = MGRS.from_lla(lla_coord, datum, precision)
        from_mgrs(mgrs_coord)
      end

      def to_ecef(datum = WGS84)
        to_lla(datum).to_ecef(datum)
      end

      def self.from_ecef(ecef_coord, datum = WGS84, precision = 5)
        lla_coord = ecef_coord.to_lla(datum)
        from_lla(lla_coord, datum, precision)
      end

      def to_enu(reference_lla, datum = WGS84)
        to_lla(datum).to_enu(reference_lla, datum)
      end

      def self.from_enu(enu_coord, reference_lla, datum = WGS84, precision = 5)
        lla_coord = enu_coord.to_lla(reference_lla, datum)
        from_lla(lla_coord, datum, precision)
      end

      def to_ned(reference_lla, datum = WGS84)
        to_lla(datum).to_ned(reference_lla, datum)
      end

      def self.from_ned(ned_coord, reference_lla, datum = WGS84, precision = 5)
        lla_coord = ned_coord.to_lla(reference_lla, datum)
        from_lla(lla_coord, datum, precision)
      end

      def to_ups(datum = WGS84)
        require_relative 'ups'
        UPS.from_lla(to_lla(datum), datum)
      end

      def self.from_ups(ups_coord, datum = WGS84, precision = 5)
        lla_coord = ups_coord.to_lla(datum)
        from_lla(lla_coord, datum, precision)
      end

      def to_web_mercator(datum = WGS84)
        require_relative 'web_mercator'
        WebMercator.from_lla(to_lla(datum), datum)
      end

      def self.from_web_mercator(web_mercator_coord, datum = WGS84, precision = 5)
        lla_coord = web_mercator_coord.to_lla(datum)
        from_lla(lla_coord, datum, precision)
      end

      # USNG-specific formatting methods
      def to_full_format
        "#{@grid_zone_designator} #{@square_identifier} #{@easting.round.to_s.rjust(5, '0')} #{@northing.round.to_s.rjust(5, '0')}"
      end

      def to_abbreviated_format
        # Common abbreviation drops leading zeros and trailing precision
        east_str = @easting.round.to_s.gsub(/^0+/, '')
        north_str = @northing.round.to_s.gsub(/^0+/, '')
        east_str = '0' if east_str.empty?
        north_str = '0' if north_str.empty?
        "#{@grid_zone_designator} #{@square_identifier} #{east_str} #{north_str}"
      end


      # Bearing calculation
      def bearing_to(other_coord)
        utm1 = self.to_utm
        utm2 = other_coord.to_utm

        dx = utm2.easting - utm1.easting
        dy = utm2.northing - utm1.northing

        bearing_rad = Math.atan2(dx, dy)
        bearing_deg = bearing_rad * 180.0 / Math::PI
        bearing_deg = bearing_deg + 360.0 if bearing_deg < 0
        bearing_deg
      end

      # Get adjacent grid squares
      def adjacent_squares
        squares = {}
        mgrs = to_mgrs

        # Calculate adjacent 100km squares (simplified)
        base_easting = (@easting / 100000).floor * 100000
        base_northing = (@northing / 100000).floor * 100000

        # This is a simplified version - real implementation would need
        # to handle zone boundaries and square identifier cycling
        offsets = {
          north: [0, 100000],
          northeast: [100000, 100000],
          east: [100000, 0],
          southeast: [100000, -100000],
          south: [0, -100000],
          southwest: [-100000, -100000],
          west: [-100000, 0],
          northwest: [-100000, 100000]
        }

        offsets.each do |direction, (de, dn)|
          begin
            new_east = @easting + de
            new_north = @northing + dn
            adjacent_usng = USNG.new(grid_zone: @grid_zone_designator, square_id: @square_identifier,
                                     easting: new_east, northing: new_north, precision: @precision)
            squares[direction] = adjacent_usng
          rescue => e
            # Skip invalid adjacent squares (e.g., crossing zone boundaries)
            squares[direction] = nil
          end
        end

        squares
      end

      # Validate USNG coordinate
      def valid?
        # Check if this falls within CONUS/Alaska/Hawaii UTM zones
        valid_zones = %w[10S 10T 10U 11S 11T 11U 12S 12T 12U 13S 13T 13U 14S 14T 14U 15S 15T 15U 16S 16T 16U 17S 17T 17U 18S 18T 18U 19S 19T 19U]

        return false unless valid_zones.include?(@grid_zone_designator)
        return false unless @square_identifier.length == 2
        return false unless @easting >= 0 && @easting < 100000
        return false unless @northing >= 0 && @northing < 100000

        true
      end

      private

      def parse_usng_string(usng_string)
        usng = usng_string.upcase.strip

        # USNG format: "18T WL 12345 67890" or "18TWL1234567890"
        # Handle both spaced and non-spaced formats

        if usng.include?(' ')
          parts = usng.split(/\s+/)

          if parts.length < 2
            raise "Invalid USNG format: #{usng_string}"
          end

          @grid_zone_designator = parts[0]
          @square_identifier = parts[1]

          if parts.length >= 4
            # Full coordinate format
            east_str = parts[2]
            north_str = parts[3]
            @precision = east_str.length

            coord_multiplier = 10 ** (5 - @precision)
            @easting = east_str.to_i * coord_multiplier
            @northing = north_str.to_i * coord_multiplier
          else
            # Grid square only
            @precision = 1
            @easting = 0.0
            @northing = 0.0
          end
        else
          # Non-spaced format - delegate to MGRS parser
          mgrs_coord = MGRS.new(mgrs_string: usng_string)
          @grid_zone_designator = mgrs_coord.grid_zone_designator
          @square_identifier = mgrs_coord.square_identifier
          @easting = mgrs_coord.easting
          @northing = mgrs_coord.northing
          @precision = mgrs_coord.precision
        end
      end
    end
  end
end
