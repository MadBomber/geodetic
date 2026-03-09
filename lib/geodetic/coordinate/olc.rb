# frozen_string_literal: true

# Open Location Code (Plus Codes) Coordinate System
# Google's open system for encoding locations into short, URL-friendly codes
# like "849VCWC8+R9". Uses a 20-character alphabet to encode latitude/longitude
# into a hierarchical grid with a '+' separator after the 8th character.
#
# The first 10 significant characters use 5 pairs of base-20 digits encoding
# latitude and longitude separately. Characters beyond 10 use a 5x4 grid
# refinement for higher precision.
#
# Character set: 23456789CFGHJMPQRVWX
# (excludes vowels and ambiguous characters to avoid spelling words)
#
# This is a 2D coordinate system (no altitude). Conversions to/from other
# systems go through LLA as the intermediary.
#
# Valid code lengths (significant chars): 2, 4, 6, 8, 10, 11, 12, 13, 14, 15
#
# Usage:
#   OLC.new("849VCWC8+R9")              # from a plus code string
#   OLC.new(lla_coord)                  # from any coordinate (converts via LLA)
#   OLC.new(utm_coord, precision: 11)   # with custom precision

require_relative 'spatial_hash'

module Geodetic
  module Coordinate
    class OLC < SpatialHash
      # The 20-character alphabet used by Open Location Code
      ALPHABET = '23456789CFGHJMPQRVWX'

      # Reverse lookup: character -> index (0..19)
      CHAR_INDEX = {}.tap do |h|
        ALPHABET.each_char.with_index { |ch, i| h[ch] = i }
      end.freeze

      # The separator character and its position
      SEPARATOR = '+'
      SEPARATOR_POSITION = 8

      # Padding character for codes shorter than 8 significant chars
      PADDING = '0'

      # Encoding base for paired characters
      ENCODING_BASE = 20

      # Grid refinement dimensions (rows x columns) for chars beyond 10
      GRID_ROWS = 5
      GRID_COLS = 4

      # Maximum supported code length
      MAX_LENGTH = 15

      # Pre-computed pair resolutions (place values) for each of the 5 pair levels
      PAIR_RESOLUTIONS = [20.0, 1.0, 0.05, 0.0025, 0.000125].freeze

      # Initial resolution steps (degrees)
      LAT_INITIAL = 20.0
      LNG_INITIAL = 20.0

      attr_reader :code

      def self.default_precision = 10
      def self.hash_system_name = :olc

      # --- Subclass contract implementations ---

      def precision
        # Number of significant characters (excluding '+' and padding)
        @code.delete(SEPARATOR).delete(PADDING).length
      end

      def to_s(truncate_to = nil)
        if truncate_to
          target = truncate_to.to_i.clamp(2, MAX_LENGTH)
          # Re-encode at target precision from decoded coordinates
          coords = decode(@code)
          encode(coords[:lat], coords[:lng], target)
        else
          @code
        end
      end

      def valid?
        return false unless @code.include?(SEPARATOR)
        significant = @code.delete(SEPARATOR).delete(PADDING)
        return false if significant.empty?
        significant.each_char.all? { |c| CHAR_INDEX.key?(c) }
      end

      protected

      def normalize(string)
        string.upcase
      end

      def set_code(value)
        @code = value
      end

      def code_value
        @code
      end

      private

      # Encode lat/lng to a plus code of given length.
      # Uses pre-computed place values to avoid floating-point accumulation errors.
      def encode(lat, lng, code_length = self.class.default_precision)
        code_length = code_length.clamp(2, MAX_LENGTH)

        # Clamp latitude, normalize longitude
        lat = lat.clamp(-90.0, 90.0)
        lng = normalize_lng(lng)

        # Shift to positive values
        adj_lat = lat + 90.0
        adj_lng = lng + 180.0

        result = String.new(capacity: code_length + 1)

        # Encode pairs using pre-computed resolutions (up to 5 pairs = 10 chars)
        pairs = [code_length, 10].min / 2

        pairs.times do |i|
          place_value = PAIR_RESOLUTIONS[i]

          # Use rounding to avoid floating-point truncation errors
          # (e.g., 15.9999999 should be 16, not 15)
          lat_digit = [((adj_lat / place_value) + 1e-10).to_i, ENCODING_BASE - 1].min
          lng_digit = [((adj_lng / place_value) + 1e-10).to_i, ENCODING_BASE - 1].min

          result << ALPHABET[lat_digit]
          result << ALPHABET[lng_digit]

          adj_lat -= lat_digit * place_value
          adj_lng -= lng_digit * place_value
        end

        # Pad to 8 characters if needed
        result << PADDING while result.length < SEPARATOR_POSITION

        # Insert separator
        result.insert(SEPARATOR_POSITION, SEPARATOR)

        # Grid refinement characters (beyond 10 significant chars)
        if code_length > 10
          lat_step = PAIR_RESOLUTIONS[4]
          lng_step = PAIR_RESOLUTIONS[4]

          (code_length - 10).times do
            lat_step /= GRID_ROWS
            lng_step /= GRID_COLS

            row = [(adj_lat / lat_step).to_i, GRID_ROWS - 1].min
            col = [(adj_lng / lng_step).to_i, GRID_COLS - 1].min

            result << ALPHABET[row * GRID_COLS + col]

            adj_lat -= row * lat_step
            adj_lng -= col * lng_step
          end
        end

        result
      end

      # Decode a plus code to lat/lng (returns midpoint of bounding box)
      def decode(code)
        bounds = decode_bounds(code)
        {
          lat: (bounds[:min_lat] + bounds[:max_lat]) / 2.0,
          lng: (bounds[:min_lng] + bounds[:max_lng]) / 2.0
        }
      end

      # Decode a plus code to its bounding box
      def decode_bounds(code)
        # Strip separator and padding
        clean = code.delete(SEPARATOR).delete(PADDING)

        lat_min = -90.0
        lng_min = -180.0

        # Process pairs (up to 5) using pre-computed resolutions
        pair_count = [clean.length, 10].min / 2
        idx = 0

        pair_count.times do |i|
          place_value = PAIR_RESOLUTIONS[i]

          lat_idx = CHAR_INDEX[clean[idx]]
          lng_idx = CHAR_INDEX[clean[idx + 1]]

          lat_min += lat_idx * place_value
          lng_min += lng_idx * place_value

          idx += 2
        end

        # Determine final step size
        last_pair = pair_count - 1
        lat_step = PAIR_RESOLUTIONS[last_pair]
        lng_step = PAIR_RESOLUTIONS[last_pair]

        # Process grid refinement characters
        while idx < clean.length
          lat_step /= GRID_ROWS
          lng_step /= GRID_COLS

          char_idx = CHAR_INDEX[clean[idx]]
          row = char_idx / GRID_COLS
          col = char_idx % GRID_COLS

          lat_min += row * lat_step
          lng_min += col * lng_step

          idx += 1
        end

        {
          min_lat: lat_min,
          max_lat: lat_min + lat_step,
          min_lng: lng_min,
          max_lng: lng_min + lng_step
        }
      end

      def normalize_lng(lng)
        lng += 360.0 while lng < -180.0
        lng -= 360.0 while lng >= 180.0
        lng
      end

      def validate_code!(code)
        raise ArgumentError, "Plus code string cannot be empty" if code.empty?

        # Must contain separator
        sep_pos = code.index(SEPARATOR)
        raise ArgumentError, "Plus code must contain '+' separator" unless sep_pos
        raise ArgumentError, "'+' separator must be at position #{SEPARATOR_POSITION}" unless sep_pos == SEPARATOR_POSITION

        before = code[0...sep_pos]
        after = code[(sep_pos + 1)..]

        raise ArgumentError, "Must have #{SEPARATOR_POSITION} characters before '+'" unless before.length == SEPARATOR_POSITION

        # Check for valid padding pattern
        padding_start = before.index(PADDING)
        if padding_start
          raise ArgumentError, "Padding must start at an even position" unless padding_start.even?
          padded = before[padding_start..]
          raise ArgumentError, "Padding characters must be trailing" unless padded.chars.all? { |c| c == PADDING }
          raise ArgumentError, "No characters allowed after '+' when code is padded" unless after.empty?
        end

        # Validate non-padding characters
        significant_before = padding_start ? before[0...padding_start] : before
        significant_before.each_char do |c|
          raise ArgumentError, "Invalid plus code character: #{c}" unless CHAR_INDEX.key?(c)
        end

        after.each_char do |c|
          raise ArgumentError, "Invalid plus code character: #{c}" unless CHAR_INDEX.key?(c)
        end
      end

      register_hash_system(:olc, self, default_precision: 10)
    end
  end
end
