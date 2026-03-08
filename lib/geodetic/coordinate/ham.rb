# frozen_string_literal: true

# Maidenhead Locator System (Grid Square) Coordinate
# The geographic encoding used worldwide in amateur radio. Encodes lat/lng
# into a hierarchical alphanumeric string (e.g., "FN31pr") using alternating
# letter/digit pairs at progressively finer resolution.
#
# Uses a false coordinate system: longitude is measured eastward from the
# antimeridian (adding 180°), latitude is measured from the South Pole
# (adding 90°), so all values are positive.
#
# This is a 2D coordinate system (no altitude). Conversions to/from other
# systems go through LLA as the intermediary.
#
# Valid locator lengths: 2, 4, 6, or 8 characters (1-4 pairs).
#
# Usage:
#   HAM.new("FN31pr")                    # from a locator string
#   HAM.new(lla_coord)                   # from any coordinate (converts via LLA)
#   HAM.new(utm_coord, precision: 8)     # with extended precision

module Geodetic
  module Coordinate
    class HAM
      require_relative '../datum'

      # Encoding levels (each level is a pair of characters)
      # Level 1 (Field):    A-R  (18 letters), lng step = 20°, lat step = 10°
      # Level 2 (Square):   0-9  (10 digits),  lng step = 2°,  lat step = 1°
      # Level 3 (Subsquare): a-x (24 letters), lng step = 5',  lat step = 2.5'
      # Level 4 (Extended):  0-9 (10 digits),  lng step = 30", lat step = 15"

      FIELD_CHARS    = ('A'..'R').to_a.freeze   # 18 letters
      SQUARE_CHARS   = ('0'..'9').to_a.freeze   # 10 digits
      SUBSQUARE_CHARS = ('a'..'x').to_a.freeze  # 24 letters
      EXTENDED_CHARS = ('0'..'9').to_a.freeze   # 10 digits

      FIELD_COUNT     = 18
      SQUARE_COUNT    = 10
      SUBSQUARE_COUNT = 24
      EXTENDED_COUNT  = 10

      # Longitude step sizes in degrees for each level
      LNG_STEPS = [20.0, 2.0, 5.0 / 60.0, 0.5 / 60.0].freeze
      # Latitude step sizes in degrees for each level
      LAT_STEPS = [10.0, 1.0, 2.5 / 60.0, 0.25 / 60.0].freeze

      # Divisor counts per level (how many subdivisions)
      DIVISORS = [FIELD_COUNT, SQUARE_COUNT, SUBSQUARE_COUNT, EXTENDED_COUNT].freeze

      # Default precision: 6 characters (3 pairs = subsquare level)
      # This is the standard used in amateur radio
      DEFAULT_PRECISION = 6

      # Direction offsets for neighbor calculation: [lat_direction, lng_direction]
      DIRECTIONS = {
        N:  [ 1,  0],
        S:  [-1,  0],
        E:  [ 0,  1],
        W:  [ 0, -1],
        NE: [ 1,  1],
        NW: [ 1, -1],
        SE: [-1,  1],
        SW: [-1, -1]
      }.freeze

      attr_reader :locator

      # Create a HAM from a Maidenhead locator string or any coordinate object.
      #
      #   HAM.new("FN31pr")                    # from locator string
      #   HAM.new(lla)                         # from LLA coordinate
      #   HAM.new(utm, precision: 8)           # from any coordinate with extended precision
      def initialize(source, precision: DEFAULT_PRECISION)
        case source
        when String
          validate_locator!(source)
          @locator = normalize(source)
        when LLA
          @locator = encode(source.lat, source.lng, precision)
        else
          if source.respond_to?(:to_lla)
            lla = source.to_lla
            @locator = encode(lla.lat, lla.lng, precision)
          else
            raise ArgumentError,
              "Expected a Maidenhead locator String or a coordinate object, got #{source.class}"
          end
        end
      end

      def precision
        @locator.length
      end

      def to_s(truncate_to = nil)
        if truncate_to
          len = truncate_to.to_i
          # Maidenhead locators must have even length
          len = [len, 2].max
          len -= 1 if len.odd?
          @locator[0, len]
        else
          @locator
        end
      end

      def to_a
        coords = decode(@locator)
        [coords[:lat], coords[:lng]]
      end

      def self.from_array(array)
        new(LLA.new(lat: array[0].to_f, lng: array[1].to_f))
      end

      def self.from_string(string)
        new(string.strip)
      end

      # Decode to LLA (altitude is always 0.0 since HAM is 2D)
      def to_lla(datum = WGS84)
        coords = decode(@locator)
        LLA.new(lat: coords[:lat], lng: coords[:lng], alt: 0.0)
      end

      def self.from_lla(lla_coord, datum = WGS84, precision = DEFAULT_PRECISION)
        new(lla_coord, precision: precision)
      end

      # All other conversions chain through LLA

      def to_ecef(datum = WGS84)
        to_lla(datum).to_ecef(datum)
      end

      def self.from_ecef(ecef_coord, datum = WGS84, precision = DEFAULT_PRECISION)
        new(ecef_coord, precision: precision)
      end

      def to_utm(datum = WGS84)
        to_lla(datum).to_utm(datum)
      end

      def self.from_utm(utm_coord, datum = WGS84, precision = DEFAULT_PRECISION)
        new(utm_coord, precision: precision)
      end

      def to_enu(reference_lla, datum = WGS84)
        to_lla(datum).to_enu(reference_lla)
      end

      def self.from_enu(enu_coord, reference_lla, datum = WGS84, precision = DEFAULT_PRECISION)
        lla_coord = enu_coord.to_lla(reference_lla)
        new(lla_coord, precision: precision)
      end

      def to_ned(reference_lla, datum = WGS84)
        to_lla(datum).to_ned(reference_lla)
      end

      def self.from_ned(ned_coord, reference_lla, datum = WGS84, precision = DEFAULT_PRECISION)
        lla_coord = ned_coord.to_lla(reference_lla)
        new(lla_coord, precision: precision)
      end

      def to_mgrs(datum = WGS84, mgrs_precision = 5)
        MGRS.from_lla(to_lla(datum), datum, mgrs_precision)
      end

      def self.from_mgrs(mgrs_coord, datum = WGS84, precision = DEFAULT_PRECISION)
        new(mgrs_coord, precision: precision)
      end

      def to_usng(datum = WGS84, usng_precision = 5)
        USNG.from_lla(to_lla(datum), datum, usng_precision)
      end

      def self.from_usng(usng_coord, datum = WGS84, precision = DEFAULT_PRECISION)
        new(usng_coord, precision: precision)
      end

      def to_web_mercator(datum = WGS84)
        WebMercator.from_lla(to_lla(datum), datum)
      end

      def self.from_web_mercator(wm_coord, datum = WGS84, precision = DEFAULT_PRECISION)
        new(wm_coord, precision: precision)
      end

      def to_ups(datum = WGS84)
        UPS.from_lla(to_lla(datum), datum)
      end

      def self.from_ups(ups_coord, datum = WGS84, precision = DEFAULT_PRECISION)
        new(ups_coord, precision: precision)
      end

      def to_state_plane(zone_code, datum = WGS84)
        StatePlane.from_lla(to_lla(datum), zone_code, datum)
      end

      def self.from_state_plane(sp_coord, datum = WGS84, precision = DEFAULT_PRECISION)
        new(sp_coord, precision: precision)
      end

      def to_bng(datum = WGS84)
        BNG.from_lla(to_lla(datum), datum)
      end

      def self.from_bng(bng_coord, datum = WGS84, precision = DEFAULT_PRECISION)
        new(bng_coord, precision: precision)
      end

      def to_gh36(datum = WGS84, gh36_precision: 10)
        GH36.new(to_lla(datum), precision: gh36_precision)
      end

      def self.from_gh36(gh36_coord, datum = WGS84, precision = DEFAULT_PRECISION)
        new(gh36_coord, precision: precision)
      end

      def to_gh(datum = WGS84, gh_precision: 12)
        GH.new(to_lla(datum), precision: gh_precision)
      end

      def self.from_gh(gh_coord, datum = WGS84, precision = DEFAULT_PRECISION)
        new(gh_coord, precision: precision)
      end

      def to_olc(datum = WGS84, olc_precision: 10)
        OLC.new(to_lla(datum), precision: olc_precision)
      end

      def self.from_olc(olc_coord, datum = WGS84, precision = DEFAULT_PRECISION)
        new(olc_coord, precision: precision)
      end

      def ==(other)
        return false unless other.is_a?(HAM)
        @locator == other.locator
      end

      def valid?
        @locator.length >= 2 &&
          @locator.length.even? &&
          @locator.length <= 8 &&
          valid_characters?(@locator)
      end

      # Returns all 8 neighboring grid cells as HAM instances
      # Keys: :N, :S, :E, :W, :NE, :NW, :SE, :SW
      def neighbors
        bb = decode_bounds(@locator)
        lat_step = bb[:max_lat] - bb[:min_lat]
        lng_step = bb[:max_lng] - bb[:min_lng]
        center_lat = (bb[:min_lat] + bb[:max_lat]) / 2.0
        center_lng = (bb[:min_lng] + bb[:max_lng]) / 2.0
        len = @locator.length

        DIRECTIONS.each_with_object({}) do |(dir, delta), result|
          nlat = center_lat + delta[0] * lat_step
          nlng = center_lng + delta[1] * lng_step

          # Clamp latitude to valid range
          nlat = nlat.clamp(-89.99999999, 89.99999999)

          # Wrap longitude
          nlng += 360.0 if nlng < -180.0
          nlng -= 360.0 if nlng > 180.0

          result[dir] = self.class.new(LLA.new(lat: nlat, lng: nlng), precision: len)
        end
      end

      # Returns the grid cell as an Areas::Rectangle
      def to_area
        bb = decode_bounds(@locator)
        nw = LLA.new(lat: bb[:max_lat], lng: bb[:min_lng], alt: 0.0)
        se = LLA.new(lat: bb[:min_lat], lng: bb[:max_lng], alt: 0.0)
        Areas::Rectangle.new(nw: nw, se: se)
      end

      # Returns precision in meters as {lat:, lng:}
      def precision_in_meters
        bb = decode_bounds(@locator)
        lat_center = (bb[:min_lat] + bb[:max_lat]) / 2.0

        lat_meters_per_deg = 111_320.0
        lng_meters_per_deg = 111_320.0 * Math.cos(lat_center * Math::PI / 180.0)

        lat_range = bb[:max_lat] - bb[:min_lat]
        lng_range = bb[:max_lng] - bb[:min_lng]

        { lat: lat_range * lat_meters_per_deg, lng: lng_range * lng_meters_per_deg }
      end

      # URL-friendly slug
      alias_method :to_slug, :to_s

      private

      # Encode lat/lng to a Maidenhead locator string
      def encode(lat, lng, length = DEFAULT_PRECISION)
        # Ensure even length, 2-8
        length = length.to_i
        length = [length, 2].max
        length -= 1 if length.odd?
        length = [length, 8].min

        # Apply false coordinate offsets
        adj_lng = lng + 180.0
        adj_lat = lat + 90.0

        result = String.new(capacity: length)
        pairs = length / 2

        pairs.times do |level|
          divisor = DIVISORS[level]

          lng_idx = (adj_lng / LNG_STEPS[level]).to_i
          lat_idx = (adj_lat / LAT_STEPS[level]).to_i

          # Clamp to valid range
          lng_idx = [lng_idx, divisor - 1].min
          lat_idx = [lat_idx, divisor - 1].min

          case level
          when 0
            result << FIELD_CHARS[lng_idx] << FIELD_CHARS[lat_idx]
          when 1
            result << SQUARE_CHARS[lng_idx] << SQUARE_CHARS[lat_idx]
          when 2
            result << SUBSQUARE_CHARS[lng_idx] << SUBSQUARE_CHARS[lat_idx]
          when 3
            result << EXTENDED_CHARS[lng_idx] << EXTENDED_CHARS[lat_idx]
          end

          adj_lng -= lng_idx * LNG_STEPS[level]
          adj_lat -= lat_idx * LAT_STEPS[level]
        end

        result
      end

      # Decode a Maidenhead locator to lat/lng (returns midpoint of bounding box)
      def decode(locator)
        bounds = decode_bounds(locator)
        {
          lat: (bounds[:min_lat] + bounds[:max_lat]) / 2.0,
          lng: (bounds[:min_lng] + bounds[:max_lng]) / 2.0
        }
      end

      # Decode a Maidenhead locator to its bounding box
      def decode_bounds(locator)
        lng_min = 0.0
        lat_min = 0.0

        pairs = locator.length / 2

        pairs.times do |level|
          c_lng = locator[level * 2]
          c_lat = locator[level * 2 + 1]

          case level
          when 0
            lng_min += (c_lng.ord - 'A'.ord) * LNG_STEPS[level]
            lat_min += (c_lat.ord - 'A'.ord) * LAT_STEPS[level]
          when 1
            lng_min += (c_lng.ord - '0'.ord) * LNG_STEPS[level]
            lat_min += (c_lat.ord - '0'.ord) * LAT_STEPS[level]
          when 2
            lng_min += (c_lng.ord - 'a'.ord) * LNG_STEPS[level]
            lat_min += (c_lat.ord - 'a'.ord) * LAT_STEPS[level]
          when 3
            lng_min += (c_lng.ord - '0'.ord) * LNG_STEPS[level]
            lat_min += (c_lat.ord - '0'.ord) * LAT_STEPS[level]
          end
        end

        # Remove false coordinate offsets
        lng_min -= 180.0
        lat_min -= 90.0

        last_level = pairs - 1
        {
          min_lat: lat_min,
          max_lat: lat_min + LAT_STEPS[last_level],
          min_lng: lng_min,
          max_lng: lng_min + LNG_STEPS[last_level]
        }
      end

      # Normalize locator: field uppercase, subsquare lowercase
      def normalize(locator)
        result = String.new(capacity: locator.length)
        locator.each_char.with_index do |ch, i|
          pair = i / 2
          case pair
          when 0 then result << ch.upcase
          when 1 then result << ch # digits, no case
          when 2 then result << ch.downcase
          when 3 then result << ch # digits, no case
          end
        end
        result
      end

      def validate_locator!(locator)
        raise ArgumentError, "Maidenhead locator cannot be empty" if locator.empty?
        raise ArgumentError, "Maidenhead locator must have even length (got #{locator.length})" if locator.length.odd?
        raise ArgumentError, "Maidenhead locator must be 2, 4, 6, or 8 characters (got #{locator.length})" if locator.length > 8

        normalized = normalize(locator)
        unless valid_characters?(normalized)
          raise ArgumentError, "Invalid Maidenhead locator: #{locator}"
        end
      end

      def valid_characters?(locator)
        locator.each_char.with_index.all? do |ch, i|
          pair = i / 2
          case pair
          when 0 then ('A'..'R').include?(ch)
          when 1 then ('0'..'9').include?(ch)
          when 2 then ('a'..'x').include?(ch)
          when 3 then ('0'..'9').include?(ch)
          else false
          end
        end
      end
    end
  end
end
