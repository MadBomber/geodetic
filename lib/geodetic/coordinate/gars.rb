# frozen_string_literal: true

# GARS (Global Area Reference System) Coordinate
# A standardized geospatial reference system developed by the National
# Geospatial-Intelligence Agency (NGA). Divides Earth into hierarchical
# grid cells at three precision levels.
#
# Format: NNNLLqk where:
#   NNN = 3-digit longitude band (001-720, each 0.5°)
#   LL  = 2-letter latitude band (AA-QZ, each 0.5°)
#   q   = quadrant digit 1-4 (optional, subdivides to 0.25°)
#   k   = keypad digit 1-9 (optional, subdivides to ~0.0833°)
#
# Quadrant layout (within 30' cell):
#   +---+---+
#   | 1 | 2 |  (north)
#   +---+---+
#   | 3 | 4 |  (south)
#   +---+---+
#
# Keypad layout (within quadrant, telephone-style):
#   +---+---+---+
#   | 1 | 2 | 3 |
#   +---+---+---+
#   | 4 | 5 | 6 |
#   +---+---+---+
#   | 7 | 8 | 9 |
#   +---+---+---+
#
# Valid code lengths: 5 (30'), 6 (15'), 7 (5')
#
# This is a 2D coordinate system (no altitude). Conversions to/from other
# systems go through LLA as the intermediary.
#
# Usage:
#   GARS.new("006AG39")                # from a GARS string
#   GARS.new(lla_coord)                # from any coordinate (converts via LLA)
#   GARS.new(utm_coord, precision: 6)  # 15-minute quadrant precision

require_relative 'spatial_hash'

module Geodetic
  module Coordinate
    class GARS < SpatialHash
      # 24 letters (A-Z, omitting I and O)
      LETTERS = 'ABCDEFGHJKLMNPQRSTUVWXYZ'.freeze
      LETTERS_SET = LETTERS.chars.to_set.freeze

      BANDS_PER_LETTER = 24

      # Quadrant digit → [col, row] (col 0=west, row 0=south)
      QUADRANT_DECODE = {
        1 => [0, 1],  # NW
        2 => [1, 1],  # NE
        3 => [0, 0],  # SW
        4 => [1, 0],  # SE
      }.freeze

      # Keypad digit → [col, row] (col 0=west, row 0=south)
      KEYPAD_DECODE = {
        1 => [0, 2], 2 => [1, 2], 3 => [2, 2],
        4 => [0, 1], 5 => [1, 1], 6 => [2, 1],
        7 => [0, 0], 8 => [1, 0], 9 => [2, 0],
      }.freeze

      VALID_LENGTHS = [5, 6, 7].freeze

      attr_reader :code

      def self.default_precision = 7
      def self.hash_system_name = :gars

      # --- Subclass contract implementations ---

      def valid?
        VALID_LENGTHS.include?(@code.length) && valid_characters?(@code)
      end

      protected

      def code_value
        @code
      end

      def normalize(string)
        result = String.new(capacity: string.length)
        string.each_char.with_index do |ch, i|
          result << (i >= 3 && i <= 4 ? ch.upcase : ch)
        end
        result
      end

      def set_code(value)
        @code = value
      end

      private

      def encode(lat, lng, length = self.class.default_precision)
        length = length.clamp(5, 7)

        adj_lng = (lng + 180.0).clamp(0.0, 360.0 - 1e-10)
        adj_lat = (lat + 90.0).clamp(0.0, 180.0 - 1e-10)

        # Longitude band (1-720, each 0.5°)
        lon_band = (adj_lng / 0.5).to_i + 1
        lon_band = lon_band.clamp(1, 720)

        # Latitude band (1-360, each 0.5°)
        lat_band = (adj_lat / 0.5).to_i + 1
        lat_band = lat_band.clamp(1, 360)

        result = format("%03d", lon_band)
        first_idx  = (lat_band - 1) / BANDS_PER_LETTER
        second_idx = (lat_band - 1) % BANDS_PER_LETTER
        result << LETTERS[first_idx] << LETTERS[second_idx]

        return result if length <= 5

        # Fractional position within 30' cell (0.0 to 1.0)
        lon_frac = adj_lng / 0.5 - (lon_band - 1)
        lat_frac = adj_lat / 0.5 - (lat_band - 1)

        # Quadrant (1-4)
        q_col = (lon_frac * 2).to_i.clamp(0, 1)
        q_row = (lat_frac * 2).to_i.clamp(0, 1)
        quadrant = (1 - q_row) * 2 + q_col + 1
        result << quadrant.to_s

        return result if length <= 6

        # Keypad (1-9)
        lon_within_q = lon_frac * 2 - q_col
        lat_within_q = lat_frac * 2 - q_row
        k_col = (lon_within_q * 3).to_i.clamp(0, 2)
        k_row = (lat_within_q * 3).to_i.clamp(0, 2)
        keypad = (2 - k_row) * 3 + k_col + 1
        result << keypad.to_s

        result
      end

      def decode(code)
        bounds = decode_bounds(code)
        {
          lat: (bounds[:min_lat] + bounds[:max_lat]) / 2.0,
          lng: (bounds[:min_lng] + bounds[:max_lng]) / 2.0
        }
      end

      def decode_bounds(code)
        lon_band = code[0, 3].to_i
        first_idx  = LETTERS.index(code[3])
        second_idx = LETTERS.index(code[4])
        raise ArgumentError, "Invalid GARS latitude band: #{code[3..4]}" unless first_idx && second_idx

        lat_band = first_idx * BANDS_PER_LETTER + second_idx + 1

        lng = -180.0 + (lon_band - 1) * 0.5
        lat = -90.0 + (lat_band - 1) * 0.5
        lng_step = 0.5
        lat_step = 0.5

        if code.length >= 6
          quadrant = code[5].to_i
          q_col, q_row = QUADRANT_DECODE[quadrant]
          raise ArgumentError, "Invalid GARS quadrant: #{code[5]}" unless q_col

          lng += q_col * 0.25
          lat += q_row * 0.25
          lng_step = 0.25
          lat_step = 0.25
        end

        if code.length >= 7
          keypad = code[6].to_i
          k_col, k_row = KEYPAD_DECODE[keypad]
          raise ArgumentError, "Invalid GARS keypad: #{code[6]}" unless k_col

          cell_size = 0.25 / 3.0
          lng += k_col * cell_size
          lat += k_row * cell_size
          lng_step = cell_size
          lat_step = cell_size
        end

        { min_lat: lat, max_lat: lat + lat_step, min_lng: lng, max_lng: lng + lng_step }
      end

      def validate_gars!(code)
        raise ArgumentError, "GARS code cannot be empty" if code.empty?
        unless VALID_LENGTHS.include?(code.length)
          raise ArgumentError, "GARS code must be 5, 6, or 7 characters (got #{code.length})"
        end
        unless valid_characters?(code)
          raise ArgumentError, "Invalid GARS code: #{code}"
        end
      end

      alias_method :validate_code!, :validate_gars!

      def valid_characters?(code)
        # First 3 chars: digits forming 001-720
        return false unless code[0, 3].match?(/\A\d{3}\z/)
        lon_band = code[0, 3].to_i
        return false unless lon_band >= 1 && lon_band <= 720

        # Next 2 chars: valid letters
        return false unless LETTERS_SET.include?(code[3])
        return false unless LETTERS_SET.include?(code[4])

        # First letter of lat band must be A-Q (index 0-14)
        first_idx = LETTERS.index(code[3])
        return false if first_idx > 14

        if code.length >= 6
          q = code[5].to_i
          return false unless q >= 1 && q <= 4
        end

        if code.length >= 7
          k = code[6].to_i
          return false unless k >= 1 && k <= 9
        end

        true
      end

      register_hash_system(:gars, self, default_precision: 7)
    end
  end
end
