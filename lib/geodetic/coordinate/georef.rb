# frozen_string_literal: true

# GEOREF (World Geographic Reference System) Coordinate
# A grid-based geocode for specifying locations on Earth, developed by the
# US military and adopted by ICAO for air navigation and air defense reporting.
#
# Encoding reads longitude first, then latitude. Uses a false coordinate
# system: longitude + 180°, latitude + 90° to make all values positive.
#
# Structure:
#   Chars 1-2: 15° tiles (24 lng × 12 lat letters)
#   Chars 3-4: 1° degree subdivision (15 letters each)
#   Chars 5+:  Minutes as even-length digit pairs (lng digits, then lat digits)
#
# Valid code lengths: 2, 4, 8, 10, 12, 14 characters
# (not 6 — minimum numeric portion is 2 digits per axis)
#
# This is a 2D coordinate system (no altitude). Conversions to/from other
# systems go through LLA as the intermediary.
#
# Usage:
#   GEOREF.new("GJPJ3417")              # from a GEOREF string
#   GEOREF.new(lla_coord)               # from any coordinate (converts via LLA)
#   GEOREF.new(utm_coord, precision: 10) # with 0.1-minute precision

require_relative 'spatial_hash'

module Geodetic
  module Coordinate
    class GEOREF < SpatialHash
      # 24 letters for longitude tiles (A-Z, omitting I and O)
      TILE_LNG_CHARS = 'ABCDEFGHJKLMNPQRSTUVWXYZ'.freeze

      # 12 letters for latitude tiles (A-M, omitting I)
      TILE_LAT_CHARS = 'ABCDEFGHJKLM'.freeze

      # 15 letters for degree subdivisions (A-Q, omitting I and O)
      DEGREE_CHARS = 'ABCDEFGHJKLMNPQ'.freeze

      TILE_LNG_SET = TILE_LNG_CHARS.chars.to_set.freeze
      TILE_LAT_SET = TILE_LAT_CHARS.chars.to_set.freeze
      DEGREE_SET   = DEGREE_CHARS.chars.to_set.freeze

      # Valid code lengths (no length 6 — can't have single-digit minutes)
      VALID_LENGTHS = [2, 4, 8, 10, 12, 14].freeze

      attr_reader :code

      def self.default_precision = 8
      def self.hash_system_name = :georef

      # --- Subclass contract implementations ---

      def valid?
        VALID_LENGTHS.include?(@code.length) && valid_characters?(@code)
      end

      protected

      def code_value
        @code
      end

      def normalize(string)
        string.upcase
      end

      def set_code(value)
        @code = value
      end

      private

      def encode(lat, lng, length = self.class.default_precision)
        # Snap to nearest valid length
        length = VALID_LENGTHS.min_by { |v| (v - length).abs }

        # Normalize to positive values, clamping at boundaries
        adj_lng = (lng + 180.0).clamp(0.0, 360.0 - 1e-10)
        adj_lat = (lat + 90.0).clamp(0.0, 180.0 - 1e-10)

        result = String.new(capacity: length)

        # Tile: 15° cells
        lng_tile = (adj_lng / 15.0).to_i.clamp(0, 23)
        lat_tile = (adj_lat / 15.0).to_i.clamp(0, 11)
        result << TILE_LNG_CHARS[lng_tile] << TILE_LAT_CHARS[lat_tile]
        return result if length <= 2

        # Degree within tile: 1° cells
        lng_within_tile = adj_lng - lng_tile * 15.0
        lat_within_tile = adj_lat - lat_tile * 15.0
        lng_deg = lng_within_tile.to_i.clamp(0, 14)
        lat_deg = lat_within_tile.to_i.clamp(0, 14)
        result << DEGREE_CHARS[lng_deg] << DEGREE_CHARS[lat_deg]
        return result if length <= 4

        # Minutes (numeric pairs, easting then northing)
        lng_minutes = (lng_within_tile - lng_deg) * 60.0
        lat_minutes = (lat_within_tile - lat_deg) * 60.0

        num_digits = (length - 4) / 2
        scale = 10**(num_digits - 2)

        lng_val = (lng_minutes * scale).to_i.clamp(0, 60 * scale - 1)
        lat_val = (lat_minutes * scale).to_i.clamp(0, 60 * scale - 1)

        result << format("%0#{num_digits}d", lng_val)
        result << format("%0#{num_digits}d", lat_val)

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
        adj_lng = 0.0
        adj_lat = 0.0

        # Tile
        lng_tile = TILE_LNG_CHARS.index(code[0])
        lat_tile = TILE_LAT_CHARS.index(code[1])
        raise ArgumentError, "Invalid GEOREF tile: #{code[0..1]}" unless lng_tile && lat_tile

        adj_lng = lng_tile * 15.0
        adj_lat = lat_tile * 15.0
        lng_step = 15.0
        lat_step = 15.0

        if code.length >= 4
          lng_deg = DEGREE_CHARS.index(code[2])
          lat_deg = DEGREE_CHARS.index(code[3])
          raise ArgumentError, "Invalid GEOREF degree: #{code[2..3]}" unless lng_deg && lat_deg

          adj_lng += lng_deg
          adj_lat += lat_deg
          lng_step = 1.0
          lat_step = 1.0
        end

        if code.length > 4
          num_digits = (code.length - 4) / 2
          lng_min_str = code[4, num_digits]
          lat_min_str = code[4 + num_digits, num_digits]

          scale = 10**(num_digits - 2)
          lng_min = lng_min_str.to_f / scale
          lat_min = lat_min_str.to_f / scale

          adj_lng += lng_min / 60.0
          adj_lat += lat_min / 60.0

          lng_step = 1.0 / (60.0 * scale)
          lat_step = 1.0 / (60.0 * scale)
        end

        lng = adj_lng - 180.0
        lat = adj_lat - 90.0

        { min_lat: lat, max_lat: lat + lat_step, min_lng: lng, max_lng: lng + lng_step }
      end

      def validate_georef!(code)
        raise ArgumentError, "GEOREF code cannot be empty" if code.empty?
        unless VALID_LENGTHS.include?(code.length)
          raise ArgumentError,
            "GEOREF code must be 2, 4, 8, 10, 12, or 14 characters (got #{code.length})"
        end
        unless valid_characters?(code)
          raise ArgumentError, "Invalid GEOREF code: #{code}"
        end
      end

      alias_method :validate_code!, :validate_georef!

      def valid_characters?(code)
        return false unless TILE_LNG_SET.include?(code[0])
        return false unless TILE_LAT_SET.include?(code[1])

        if code.length >= 4
          return false unless DEGREE_SET.include?(code[2])
          return false unless DEGREE_SET.include?(code[3])
        end

        if code.length > 4
          digits = code[4..]
          return false unless digits.match?(/\A\d+\z/)
          return false unless digits.length.even?
        end

        true
      end

      register_hash_system(:georef, self, default_precision: 8)
    end
  end
end
