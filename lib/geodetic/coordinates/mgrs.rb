# frozen_string_literal: true

# Military Grid Reference System (MGRS) Coordinate
# Converts between MGRS grid references and other coordinate systems
# MGRS is based on UTM but uses a more compact alphanumeric format

module Geodetic
  module Coordinates
    class MGRS
      require_relative '../datum'

      attr_reader :grid_zone_designator, :square_identifier, :easting, :northing, :precision

      # MGRS 100km square identification letters
      SET1_E = 'ABCDEFGHJKLMNPQRSTUVWXYZ'  # Columns (exclude I and O)
      SET2_E = 'ABCDEFGHJKLMNPQRSTUVWXYZ'  # Columns for odd UTM zones
      SET1_N = 'ABCDEFGHJKLMNPQRSTUV'      # Rows (exclude I and O, stop at V)
      SET2_N = 'FGHJKLMNPQRSTUVABCDE'      # Rows for even-numbered 100km squares

      def initialize(mgrs_string: nil, grid_zone: nil, square_id: nil, easting: nil, northing: nil, precision: 5)
        if mgrs_string
          parse_mgrs_string(mgrs_string)
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
          "#{@grid_zone_designator}#{@square_identifier}"
        else
          east_str = ("%0#{@precision}d" % (@easting / (10 ** (5 - @precision)))).to_s
          north_str = ("%0#{@precision}d" % (@northing / (10 ** (5 - @precision)))).to_s
          "#{@grid_zone_designator}#{@square_identifier}#{east_str}#{north_str}"
        end
      end

      def self.from_string(string)
        new(mgrs_string: string)
      end

      def to_utm
        # Extract zone number and hemisphere from grid zone designator
        zone_number = @grid_zone_designator[0..-2].to_i
        zone_letter = @grid_zone_designator[-1]
        hemisphere = (zone_letter >= 'N') ? 'N' : 'S'

        # Convert 100km square to UTM coordinates
        utm_easting, utm_northing = square_to_utm(zone_number, @square_identifier, @easting, @northing)

        UTM.new(easting: utm_easting, northing: utm_northing, zone: zone_number, hemisphere: hemisphere)
      end

      def self.from_utm(utm_coord, precision = 5)
        # Create instance to access instance methods
        temp_instance = new()

        # Get 100km square identifier
        square_id = temp_instance.utm_to_square(utm_coord.zone, utm_coord.easting, utm_coord.northing)

        # Calculate position within the 100km square
        square_easting = utm_coord.easting % 100000
        square_northing = utm_coord.northing % 100000

        # Create grid zone designator using hemisphere-aware band letter
        if utm_coord.hemisphere == 'N'
          zone_letter = get_zone_letter(utm_coord.northing)
        else
          zone_letter = get_zone_letter_south(utm_coord.northing)
        end
        grid_zone = "#{utm_coord.zone}#{zone_letter}"

        new(grid_zone: grid_zone, square_id: square_id, easting: square_easting, northing: square_northing, precision: precision)
      end

      def to_lla(datum = WGS84)
        utm_coord = to_utm
        utm_coord.to_lla(datum)
      end

      def self.from_lla(lla_coord, datum = WGS84, precision = 5)
        utm_coord = UTM.from_lla(lla_coord, datum)
        from_utm(utm_coord, precision)
      end

      def to_ecef(datum = WGS84)
        to_lla(datum).to_ecef(datum)
      end

      def self.from_ecef(ecef_coord, datum = WGS84, precision = 5)
        lla_coord = ecef_coord.to_lla(datum)
        from_lla(lla_coord, datum, precision)
      end

      def to_enu(reference_lla, datum = WGS84)
        to_lla(datum).to_enu(reference_lla)
      end

      def self.from_enu(enu_coord, reference_lla, datum = WGS84, precision = 5)
        lla_coord = enu_coord.to_lla(reference_lla)
        from_lla(lla_coord, datum, precision)
      end

      def to_ned(reference_lla, datum = WGS84)
        to_lla(datum).to_ned(reference_lla)
      end

      def self.from_ned(ned_coord, reference_lla, datum = WGS84, precision = 5)
        lla_coord = ned_coord.to_lla(reference_lla)
        from_lla(lla_coord, datum, precision)
      end

      def to_web_mercator(datum = WGS84)
        WebMercator.from_lla(to_lla(datum), datum)
      end

      def self.from_web_mercator(wm_coord, datum = WGS84, precision = 5)
        from_lla(wm_coord.to_lla(datum), datum, precision)
      end

      def to_ups(datum = WGS84)
        UPS.from_lla(to_lla(datum), datum)
      end

      def self.from_ups(ups_coord, datum = WGS84, precision = 5)
        from_lla(ups_coord.to_lla(datum), datum, precision)
      end

      def to_usng
        USNG.from_mgrs(self)
      end

      def self.from_usng(usng_coord)
        usng_coord.to_mgrs
      end

      def to_state_plane(zone_code, datum = WGS84)
        StatePlane.from_lla(to_lla(datum), zone_code, datum)
      end

      def self.from_state_plane(sp_coord, datum = WGS84, precision = 5)
        from_lla(sp_coord.to_lla(datum), datum, precision)
      end

      def to_bng(datum = WGS84)
        BNG.from_lla(to_lla(datum), datum)
      end

      def self.from_bng(bng_coord, datum = WGS84, precision = 5)
        from_lla(bng_coord.to_lla(datum), datum, precision)
      end

      def to_gh36(datum = WGS84, precision: 10)
        GH36.new(to_lla(datum), precision: precision)
      end

      def self.from_gh36(gh36_coord, datum = WGS84, precision = 5)
        from_lla(gh36_coord.to_lla(datum), datum, precision)
      end

      def to_gh(datum = WGS84, precision: 12)
        GH.new(to_lla(datum), precision: precision)
      end

      def self.from_gh(gh_coord, datum = WGS84, precision = 5)
        from_lla(gh_coord.to_lla(datum), datum, precision)
      end

      def ==(other)
        return false unless other.is_a?(MGRS)

        @grid_zone_designator == other.grid_zone_designator &&
        @square_identifier == other.square_identifier &&
        (@easting - other.easting).abs <= 1e-6 &&
        (@northing - other.northing).abs <= 1e-6 &&
        @precision == other.precision
      end

      def to_a
        [@grid_zone_designator, @square_identifier, @easting, @northing, @precision]
      end

      def self.from_array(array)
        new(grid_zone: array[0], square_id: array[1], easting: array[2].to_f, northing: array[3].to_f, precision: (array[4] || 5).to_i)
      end

      def utm_to_square(zone_number, easting, northing)
        # Calculate 100km square column
        col_index = ((easting - 100000) / 100000).floor
        col_index = (col_index + (zone_number - 1) * 8) % 24

        if zone_number % 2 == 1  # Odd zones
          col_letter = SET1_E[col_index]
        else  # Even zones
          col_letter = SET2_E[col_index]
        end

        # Calculate 100km square row
        row_index = (northing / 100000).floor % 20
        if ((zone_number - 1) / 6).floor % 2 == 1
          row_letter = SET2_N[row_index]
        else
          row_letter = SET1_N[row_index]
        end

        "#{col_letter}#{row_letter}"
      end

      private

      def parse_mgrs_string(mgrs_string)
        mgrs = mgrs_string.upcase.gsub(/\s/, '')

        # Extract grid zone designator (first 2-3 characters: zone number + letter)
        if mgrs.match(/^(\d{1,2}[A-Z])/)
          @grid_zone_designator = $1
          remainder = mgrs[($1.length)..-1]
        else
          raise ArgumentError, "Invalid MGRS format: #{mgrs_string}"
        end

        # Extract 100km square identifier (next 2 characters)
        if remainder.length >= 2
          @square_identifier = remainder[0..1]
          coords = remainder[2..-1]
        else
          raise ArgumentError, "Invalid MGRS format: missing square identifier"
        end

        # Extract coordinates (remaining characters, split evenly)
        if coords.length == 0
          @precision = 1  # Grid square only
          @easting = 0.0
          @northing = 0.0
        elsif coords.length % 2 == 0
          @precision = coords.length / 2
          coord_multiplier = 10 ** (5 - @precision)
          @easting = coords[0...@precision].to_i * coord_multiplier
          @northing = coords[@precision..-1].to_i * coord_multiplier
        else
          raise ArgumentError, "Invalid MGRS format: uneven coordinate length"
        end
      end

      def square_to_utm(zone_number, square_id, easting, northing)
        col_letter = square_id[0]
        row_letter = square_id[1]

        # Calculate easting from column letter
        # For odd zones, columns start at A=1 (100km), for even zones offset by 8
        set = (zone_number % 2 == 1) ? SET1_E : SET2_E
        col_index = set.index(col_letter) || 0

        # Column letters cycle with zone: each zone spans 8 columns (A-H for zone 1, J-R for zone 2, etc.)
        # The easting within the zone is: (col_index - zone_offset) * 100000 + 100000
        zone_set = (zone_number - 1) % 3  # 0, 1, or 2
        col_in_zone = col_index - (zone_set * 8)
        col_in_zone += 24 if col_in_zone < 0
        utm_easting = (col_in_zone + 1) * 100000 + easting

        # Calculate northing from row letter
        # Row letters cycle every 2,000,000m (20 letters × 100km)
        if ((zone_number - 1) / 6).floor % 2 == 1
          row_index = SET2_N.index(row_letter) || 0
        else
          row_index = SET1_N.index(row_letter) || 0
        end
        base_northing = row_index * 100000 + northing

        # Use the grid zone letter (latitude band) to find the correct 2,000,000m cycle
        zone_letter = @grid_zone_designator[-1]
        min_northing = min_northing_for_band(zone_letter)

        # Find the cycle that puts northing closest to the band's expected range
        utm_northing = base_northing
        while utm_northing < min_northing
          utm_northing += 2000000
        end

        [utm_easting, utm_northing]
      end

      # Approximate minimum northing (in meters) for each UTM latitude band letter
      def min_northing_for_band(letter)
        band_min = {
          'C' => 1100000, 'D' => 2000000, 'E' => 2800000, 'F' => 3700000,
          'G' => 4600000, 'H' => 5500000, 'J' => 6400000, 'K' => 7300000,
          'L' => 8200000, 'M' => 9100000, 'N' => 0, 'P' => 800000,
          'Q' => 1700000, 'R' => 2600000, 'S' => 3500000, 'T' => 4400000,
          'U' => 5300000, 'V' => 6200000, 'W' => 7000000, 'X' => 7900000
        }
        band_min[letter.upcase] || 0
      end

      def self.get_zone_letter(northing)
        # For northern hemisphere, estimate latitude from northing
        # then map to the correct band letter
        # Approximate: latitude ≈ northing / 111320 (meters per degree)
        approx_lat = northing / 111320.0
        latitude_to_band_letter(approx_lat)
      end

      def self.get_zone_letter_south(northing)
        # For southern hemisphere, northing uses false northing of 10,000,000
        approx_lat = (northing - 10000000.0) / 111320.0
        latitude_to_band_letter(approx_lat)
      end

      def self.latitude_to_band_letter(lat)
        # MGRS latitude band letters: C through X (excluding I and O)
        # Each band covers 8° except X which covers 12° (72-84°N)
        bands = 'CDEFGHJKLMNPQRSTUVWX'
        return 'C' if lat < -80
        return 'X' if lat >= 72
        index = ((lat + 80) / 8).floor
        index = [0, [index, bands.length - 1].min].max
        bands[index]
      end
    end
  end
end
