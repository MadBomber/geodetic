# frozen_string_literal: true

# Geohash-36 Coordinate System
# A hierarchical spatial hashing algorithm that encodes latitude/longitude
# into a compact, URL-friendly string using a case-sensitive 36-character alphabet.
# Uses a 6x6 grid subdivision (radix-36) providing higher precision per character
# than standard Geohash (radix-32).
#
# Character set: 23456789bBCdDFgGhHjJKlLMnNPqQrRtTVWX
# (avoids vowels, vowel-like numbers, and ambiguous characters like 0/O, 1/I/l)
#
# This is a 2D coordinate system (no altitude). Conversions to/from other
# systems go through LLA as the intermediary.
#
# Usage:
#   GH36.new("bdrdC26BqH")              # from a geohash string
#   GH36.new(lla_coord)                 # from any coordinate (converts via LLA)
#   GH36.new(utm_coord, precision: 8)   # with custom precision

module Geodetic
  module Coordinates
    class GH36
      require_relative '../datum'

      # 6x6 encoding matrix mapping (row, col) to character
      # Row 0 is the northernmost latitude slice; row 5 is southernmost
      # Col 0 is the westernmost longitude slice; col 5 is easternmost
      MATRIX = [
        ['2', '3', '4', '5', '6', '7'],
        ['8', '9', 'b', 'B', 'C', 'd'],
        ['D', 'F', 'g', 'G', 'h', 'H'],
        ['j', 'J', 'K', 'l', 'L', 'M'],
        ['n', 'N', 'P', 'q', 'Q', 'r'],
        ['R', 't', 'T', 'V', 'W', 'X']
      ].freeze

      MATRIX_SIDE = 6
      MAX_INDEX   = 5

      # Valid characters in a Geohash-36 string
      VALID_CHARS = '23456789bBCdDFgGhHjJKlLMnNPqQrRtTVWX'
      VALID_CHARS_SET = VALID_CHARS.chars.to_set.freeze

      # Default hash length (10 chars gives sub-meter precision)
      DEFAULT_LENGTH = 10

      # Reverse lookup: character -> [row, col] in the matrix
      CHAR_INDEX = {}.tap do |h|
        MATRIX.each_with_index do |row, r|
          row.each_with_index do |ch, c|
            h[ch] = [r, c]
          end
        end
      end.freeze

      # Neighbor direction offsets as [row_delta, col_delta]
      # Matrix row 0 = north, row 5 = south; col 0 = west, col 5 = east
      DIRECTIONS = {
        N:  [-1,  0],
        S:  [ 1,  0],
        E:  [ 0,  1],
        W:  [ 0, -1],
        NE: [-1,  1],
        NW: [-1, -1],
        SE: [ 1,  1],
        SW: [ 1, -1]
      }.freeze

      attr_reader :geohash

      # Create a GH36 from a geohash string or any coordinate object.
      #
      #   GH36.new("bdrdC26BqH")              # from geohash string
      #   GH36.new(lla)                        # from LLA coordinate
      #   GH36.new(utm, precision: 8)          # from any coordinate with custom precision
      def initialize(source, precision: DEFAULT_LENGTH)
        case source
        when String
          validate_geohash!(source)
          @geohash = source
        when LLA
          @geohash = encode(source.lat, source.lng, precision)
        else
          if source.respond_to?(:to_lla)
            lla = source.to_lla
            @geohash = encode(lla.lat, lla.lng, precision)
          else
            raise ArgumentError,
              "Expected a geohash String or a coordinate object, got #{source.class}"
          end
        end
      end

      def precision
        @geohash.length
      end

      def to_s(truncate_to = nil)
        if truncate_to
          @geohash[0, truncate_to.to_i]
        else
          @geohash
        end
      end

      def to_a
        coords = decode(@geohash)
        [coords[:lat], coords[:lng]]
      end

      def self.from_array(array)
        new(LLA.new(lat: array[0].to_f, lng: array[1].to_f))
      end

      def self.from_string(string)
        new(string.strip)
      end

      # Decode to LLA (altitude is always 0.0 since GH36 is 2D)
      def to_lla(datum = WGS84)
        coords = decode(@geohash)
        LLA.new(lat: coords[:lat], lng: coords[:lng], alt: 0.0)
      end

      def self.from_lla(lla_coord, datum = WGS84, precision = DEFAULT_LENGTH)
        new(lla_coord, precision: precision)
      end

      # All other conversions chain through LLA

      def to_ecef(datum = WGS84)
        to_lla(datum).to_ecef(datum)
      end

      def self.from_ecef(ecef_coord, datum = WGS84, precision = DEFAULT_LENGTH)
        new(ecef_coord, precision: precision)
      end

      def to_utm(datum = WGS84)
        to_lla(datum).to_utm(datum)
      end

      def self.from_utm(utm_coord, datum = WGS84, precision = DEFAULT_LENGTH)
        new(utm_coord, precision: precision)
      end

      def to_enu(reference_lla, datum = WGS84)
        to_lla(datum).to_enu(reference_lla)
      end

      def self.from_enu(enu_coord, reference_lla, datum = WGS84, precision = DEFAULT_LENGTH)
        lla_coord = enu_coord.to_lla(reference_lla)
        new(lla_coord, precision: precision)
      end

      def to_ned(reference_lla, datum = WGS84)
        to_lla(datum).to_ned(reference_lla)
      end

      def self.from_ned(ned_coord, reference_lla, datum = WGS84, precision = DEFAULT_LENGTH)
        lla_coord = ned_coord.to_lla(reference_lla)
        new(lla_coord, precision: precision)
      end

      def to_mgrs(datum = WGS84, mgrs_precision = 5)
        MGRS.from_lla(to_lla(datum), datum, mgrs_precision)
      end

      def self.from_mgrs(mgrs_coord, datum = WGS84, precision = DEFAULT_LENGTH)
        new(mgrs_coord, precision: precision)
      end

      def to_usng(datum = WGS84, usng_precision = 5)
        USNG.from_lla(to_lla(datum), datum, usng_precision)
      end

      def self.from_usng(usng_coord, datum = WGS84, precision = DEFAULT_LENGTH)
        new(usng_coord, precision: precision)
      end

      def to_web_mercator(datum = WGS84)
        WebMercator.from_lla(to_lla(datum), datum)
      end

      def self.from_web_mercator(wm_coord, datum = WGS84, precision = DEFAULT_LENGTH)
        new(wm_coord, precision: precision)
      end

      def to_ups(datum = WGS84)
        UPS.from_lla(to_lla(datum), datum)
      end

      def self.from_ups(ups_coord, datum = WGS84, precision = DEFAULT_LENGTH)
        new(ups_coord, precision: precision)
      end

      def to_state_plane(zone_code, datum = WGS84)
        StatePlane.from_lla(to_lla(datum), zone_code, datum)
      end

      def self.from_state_plane(sp_coord, datum = WGS84, precision = DEFAULT_LENGTH)
        new(sp_coord, precision: precision)
      end

      def to_bng(datum = WGS84)
        BNG.from_lla(to_lla(datum), datum)
      end

      def self.from_bng(bng_coord, datum = WGS84, precision = DEFAULT_LENGTH)
        new(bng_coord, precision: precision)
      end

      def to_gh(datum = WGS84, gh_precision: 12)
        GH.new(to_lla(datum), precision: gh_precision)
      end

      def self.from_gh(gh_coord, datum = WGS84, precision = DEFAULT_LENGTH)
        new(gh_coord, precision: precision)
      end

      def ==(other)
        return false unless other.is_a?(GH36)
        @geohash == other.geohash
      end

      def valid?
        @geohash.length > 0 && @geohash.each_char.all? { |c| VALID_CHARS_SET.include?(c) }
      end

      # Returns all 8 neighboring geohash cells as GH36 instances
      # Keys: :N, :S, :E, :W, :NE, :NW, :SE, :SW
      def neighbors
        DIRECTIONS.each_with_object({}) do |(dir, delta), result|
          hash = self.class.send(:neighbor_hash, @geohash, delta[0], delta[1])
          result[dir] = self.class.new(hash)
        end
      end

      # Returns the geohash cell as an Areas::Rectangle
      def to_area
        bb = self.class.send(:decode_bounds, @geohash)
        nw = LLA.new(lat: bb[:max_lat], lng: bb[:min_lng], alt: 0.0)
        se = LLA.new(lat: bb[:min_lat], lng: bb[:max_lng], alt: 0.0)
        Areas::Rectangle.new(nw: nw, se: se)
      end

      # Returns precision in meters as {lat:, lng:}
      def precision_in_meters
        one_degree_meters = (2 * Math::PI * 6_370_000) / 360.0
        lat_prec = (90.0 / (MATRIX_SIDE ** precision)) * one_degree_meters
        { lat: lat_prec, lng: lat_prec * 2 }
      end

      # URL-friendly slug (the geohash itself is already URL-safe)
      alias_method :to_slug, :to_s

      private

      # Encode lat/lng to a geohash string of given length
      def encode(lat, lng, length = DEFAULT_LENGTH)
        lat_min, lat_max = -90.0, 90.0
        lng_min, lng_max = -180.0, 180.0

        result = String.new(capacity: length)

        length.times do
          # Subdivide longitude into 6 slices
          lng_slice = (lng_max - lng_min) / MATRIX_SIDE.to_f
          col = 0
          MATRIX_SIDE.times do |i|
            left  = lng_min + i * lng_slice
            right = lng_min + (i + 1) * lng_slice
            if (i == 0 ? lng >= left : lng > left) && lng <= right
              col = i
              lng_min = left
              lng_max = right
              break
            end
          end

          # Subdivide latitude into 6 slices (row 0 = south, row 5 = north)
          lat_slice = (lat_max - lat_min) / MATRIX_SIDE.to_f
          row = 0
          MATRIX_SIDE.times do |i|
            bottom = lat_min + i * lat_slice
            top    = lat_min + (i + 1) * lat_slice
            if (i == 0 ? lat >= bottom : lat > bottom) && lat <= top
              row = MAX_INDEX - i  # Invert: matrix row 0 = north
              lat_min = bottom
              lat_max = top
              break
            end
          end

          result << MATRIX[row][col]
        end

        result
      end

      # Decode a geohash string to lat/lng (returns midpoint of bounding box)
      def decode(geohash)
        bounds = self.class.send(:decode_bounds, geohash)
        {
          lat: (bounds[:min_lat] + bounds[:max_lat]) / 2.0,
          lng: (bounds[:min_lng] + bounds[:max_lng]) / 2.0
        }
      end

      # Decode a geohash string to its bounding box
      def self.decode_bounds(geohash)
        lat_min, lat_max = -90.0, 90.0
        lng_min, lng_max = -180.0, 180.0

        geohash.each_char do |ch|
          indices = CHAR_INDEX[ch]
          raise ArgumentError, "Invalid Geohash-36 character: #{ch}" unless indices

          row, col = indices
          lat_row = MAX_INDEX - row  # Invert back to bottom-up

          lng_slice = (lng_max - lng_min) / MATRIX_SIDE.to_f
          lng_min_new = lng_min + col * lng_slice
          lng_max = lng_min + (col + 1) * lng_slice
          lng_min = lng_min_new

          lat_slice = (lat_max - lat_min) / MATRIX_SIDE.to_f
          lat_min_new = lat_min + lat_row * lat_slice
          lat_max = lat_min + (lat_row + 1) * lat_slice
          lat_min = lat_min_new
        end

        { min_lat: lat_min, max_lat: lat_max, min_lng: lng_min, max_lng: lng_max }
      end
      private_class_method :decode_bounds

      # Compute a neighbor hash by adjusting the last character's position
      # in the matrix. When the adjustment wraps beyond the matrix edge,
      # we recurse on the parent prefix and carry the wrap.
      #
      # Matrix layout: row 0 = north (high lat), row 5 = south (low lat)
      #                col 0 = west (low lng),  col 5 = east (high lng)
      def self.neighbor_hash(hash, row_delta, col_delta)
        return hash if hash.empty?

        prefix = hash[0..-2]
        last_char = hash[-1]
        indices = CHAR_INDEX[last_char]
        raise ArgumentError, "Invalid Geohash-36 character: #{last_char}" unless indices

        row, col = indices
        new_row = row + row_delta
        new_col = col + col_delta

        # Check if we need to carry to the parent
        carry_row = 0
        carry_col = 0

        if new_row < 0
          carry_row = row_delta  # Propagate same direction
          new_row += MATRIX_SIDE
        elsif new_row >= MATRIX_SIDE
          carry_row = row_delta
          new_row -= MATRIX_SIDE
        end

        if new_col < 0
          carry_col = col_delta
          new_col += MATRIX_SIDE
        elsif new_col >= MATRIX_SIDE
          carry_col = col_delta
          new_col -= MATRIX_SIDE
        end

        if (carry_row != 0 || carry_col != 0) && !prefix.empty?
          prefix = neighbor_hash(prefix, carry_row, carry_col)
        end

        prefix + MATRIX[new_row][new_col]
      end
      private_class_method :neighbor_hash

      def validate_geohash!(geohash)
        raise ArgumentError, "Geohash-36 string cannot be empty" if geohash.empty?
        invalid = geohash.chars.reject { |c| VALID_CHARS_SET.include?(c) }
        unless invalid.empty?
          raise ArgumentError, "Invalid Geohash-36 characters: #{invalid.join(', ')}"
        end
      end
    end
  end
end
