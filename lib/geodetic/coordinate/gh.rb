# frozen_string_literal: true

# Geohash (Base-32) Coordinate System
# The standard geohash algorithm by Gustavo Niemeyer that encodes latitude/longitude
# into a compact string using a 32-character alphabet (0-9, b-z excluding a, i, l, o).
# Uses interleaved longitude and latitude bits.
#
# Widely supported by Elasticsearch, Redis, PostGIS, and many geocoding services.
#
# This is a 2D coordinate system (no altitude). Conversions to/from other
# systems go through LLA as the intermediary.
#
# Usage:
#   GH.new("dr5ru7")                    # from a geohash string
#   GH.new(lla_coord)                   # from any coordinate (converts via LLA)
#   GH.new(utm_coord, precision: 8)     # with custom precision

require_relative 'spatial_hash'

module Geodetic
  module Coordinate
    class GH < SpatialHash
      # Base-32 alphabet used by the standard geohash algorithm
      BASE32 = '0123456789bcdefghjkmnpqrstuvwxyz'

      # Reverse lookup: character -> index (0..31)
      CHAR_INDEX = {}.tap do |h|
        BASE32.each_char.with_index { |ch, i| h[ch] = i }
      end.freeze

      attr_reader :geohash

      def self.default_precision = 12
      def self.hash_system_name = :gh

      # --- Subclass contract implementations ---

      def valid?
        @geohash.length > 0 && @geohash.each_char.all? { |c| CHAR_INDEX.key?(c) }
      end

      protected

      def code_value
        @geohash
      end

      def normalize(string)
        string.downcase
      end

      def set_code(value)
        @geohash = value
      end

      private

      # Encode lat/lng to a geohash string of given length using bit interleaving
      def encode(lat, lng, length = self.class.default_precision)
        lat_min, lat_max = -90.0, 90.0
        lng_min, lng_max = -180.0, 180.0

        result = String.new(capacity: length)
        bits = 0
        ch_idx = 0
        even_bit = true  # true = longitude bit, false = latitude bit

        while result.length < length
          if even_bit
            mid = (lng_min + lng_max) / 2.0
            if lng >= mid
              ch_idx = (ch_idx << 1) | 1
              lng_min = mid
            else
              ch_idx = ch_idx << 1
              lng_max = mid
            end
          else
            mid = (lat_min + lat_max) / 2.0
            if lat >= mid
              ch_idx = (ch_idx << 1) | 1
              lat_min = mid
            else
              ch_idx = ch_idx << 1
              lat_max = mid
            end
          end

          even_bit = !even_bit
          bits += 1

          if bits == 5
            result << BASE32[ch_idx]
            bits = 0
            ch_idx = 0
          end
        end

        result
      end

      # Decode a geohash string to lat/lng (returns midpoint of bounding box)
      def decode(geohash)
        bounds = decode_bounds(geohash)
        {
          lat: (bounds[:min_lat] + bounds[:max_lat]) / 2.0,
          lng: (bounds[:min_lng] + bounds[:max_lng]) / 2.0
        }
      end

      # Decode a geohash string to its bounding box
      def decode_bounds(geohash)
        lat_min, lat_max = -90.0, 90.0
        lng_min, lng_max = -180.0, 180.0
        even_bit = true

        geohash.each_char do |ch|
          idx = CHAR_INDEX[ch]
          raise ArgumentError, "Invalid geohash character: #{ch}" unless idx

          4.downto(0) do |i|
            bit = (idx >> i) & 1
            if even_bit
              mid = (lng_min + lng_max) / 2.0
              if bit == 1
                lng_min = mid
              else
                lng_max = mid
              end
            else
              mid = (lat_min + lat_max) / 2.0
              if bit == 1
                lat_min = mid
              else
                lat_max = mid
              end
            end
            even_bit = !even_bit
          end
        end

        { min_lat: lat_min, max_lat: lat_max, min_lng: lng_min, max_lng: lng_max }
      end

      def validate_geohash!(geohash)
        raise ArgumentError, "Geohash string cannot be empty" if geohash.empty?
        normalized = geohash.downcase
        invalid = normalized.chars.reject { |c| CHAR_INDEX.key?(c) }
        unless invalid.empty?
          raise ArgumentError, "Invalid geohash characters: #{invalid.join(', ')}"
        end
      end

      alias_method :validate_code!, :validate_geohash!

      register_hash_system(:gh, self, default_precision: 12)
    end
  end
end
