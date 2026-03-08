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

require_relative 'spatial_hash'

module Geodetic
  module Coordinate
    class HAM < SpatialHash
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

      attr_reader :locator

      def self.default_precision = 6
      def self.hash_system_name = :ham

      # --- Subclass contract implementations ---

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

      def valid?
        @locator.length >= 2 &&
          @locator.length.even? &&
          @locator.length <= 8 &&
          valid_characters?(@locator)
      end

      def code_value
        @locator
      end

      protected

      def normalize(string)
        result = String.new(capacity: string.length)
        string.each_char.with_index do |ch, i|
          pair = i / 2
          case pair
          when 0 then result << ch.upcase
          when 1 then result << ch # digits, no case
          when 2 then result << ch.downcase
          when 3 then result << ch # digits, no case
          else result << ch # preserve extra chars for validation to catch
          end
        end
        result
      end

      def set_code(value)
        @locator = value
      end

      private

      # Encode lat/lng to a Maidenhead locator string
      def encode(lat, lng, length = self.class.default_precision)
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

      def validate_locator!(locator)
        raise ArgumentError, "Maidenhead locator cannot be empty" if locator.empty?
        raise ArgumentError, "Maidenhead locator must have even length (got #{locator.length})" if locator.length.odd?
        raise ArgumentError, "Maidenhead locator must be 2, 4, 6, or 8 characters (got #{locator.length})" if locator.length > 8

        normalized = normalize(locator)
        unless valid_characters?(normalized)
          raise ArgumentError, "Invalid Maidenhead locator: #{locator}"
        end
      end

      alias_method :validate_code!, :validate_locator!

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

      register_hash_system(:ham, self, default_precision: 6)
      Coordinate.register_class(self)
    end
  end
end
