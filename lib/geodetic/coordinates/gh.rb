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

module Geodetic
  module Coordinates
    class GH
      require_relative '../datum'

      # Base-32 alphabet used by the standard geohash algorithm
      BASE32 = '0123456789bcdefghjkmnpqrstuvwxyz'

      # Reverse lookup: character -> index (0..31)
      CHAR_INDEX = {}.tap do |h|
        BASE32.each_char.with_index { |ch, i| h[ch] = i }
      end.freeze

      # Default hash length (12 chars gives sub-centimeter precision)
      DEFAULT_LENGTH = 12

      # Direction offsets: [lat_direction, lng_direction]
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

      attr_reader :geohash

      # Create a GH from a geohash string or any coordinate object.
      #
      #   GH.new("dr5ru7")                    # from geohash string
      #   GH.new(lla)                         # from LLA coordinate
      #   GH.new(utm, precision: 8)           # from any coordinate with custom precision
      def initialize(source, precision: DEFAULT_LENGTH)
        case source
        when String
          validate_geohash!(source)
          @geohash = source.downcase
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

      # Decode to LLA (altitude is always 0.0 since GH is 2D)
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

      def to_gh36(datum = WGS84, gh36_precision: 10)
        GH36.new(to_lla(datum), precision: gh36_precision)
      end

      def self.from_gh36(gh36_coord, datum = WGS84, precision = DEFAULT_LENGTH)
        new(gh36_coord, precision: precision)
      end

      def to_ham(datum = WGS84, ham_precision: 6)
        HAM.new(to_lla(datum), precision: ham_precision)
      end

      def self.from_ham(ham_coord, datum = WGS84, precision = DEFAULT_LENGTH)
        new(ham_coord, precision: precision)
      end

      def to_olc(datum = WGS84, olc_precision: 10)
        OLC.new(to_lla(datum), precision: olc_precision)
      end

      def self.from_olc(olc_coord, datum = WGS84, precision = DEFAULT_LENGTH)
        new(olc_coord, precision: precision)
      end

      def ==(other)
        return false unless other.is_a?(GH)
        @geohash == other.geohash
      end

      def valid?
        @geohash.length > 0 && @geohash.each_char.all? { |c| CHAR_INDEX.key?(c) }
      end

      # Returns all 8 neighboring geohash cells as GH instances
      # Keys: :N, :S, :E, :W, :NE, :NW, :SE, :SW
      def neighbors
        bb = decode_bounds(@geohash)
        lat_step = (bb[:max_lat] - bb[:min_lat])
        lng_step = (bb[:max_lng] - bb[:min_lng])
        center_lat = (bb[:min_lat] + bb[:max_lat]) / 2.0
        center_lng = (bb[:min_lng] + bb[:max_lng]) / 2.0
        len = @geohash.length

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

      # Returns the geohash cell as an Areas::Rectangle
      def to_area
        bb = decode_bounds(@geohash)
        nw = LLA.new(lat: bb[:max_lat], lng: bb[:min_lng], alt: 0.0)
        se = LLA.new(lat: bb[:min_lat], lng: bb[:max_lng], alt: 0.0)
        Areas::Rectangle.new(nw: nw, se: se)
      end

      # Returns precision in meters as {lat:, lng:}
      def precision_in_meters
        bb = decode_bounds(@geohash)
        lat_center = (bb[:min_lat] + bb[:max_lat]) / 2.0

        lat_meters_per_deg = 111_320.0
        lng_meters_per_deg = 111_320.0 * Math.cos(lat_center * Math::PI / 180.0)

        lat_range = bb[:max_lat] - bb[:min_lat]
        lng_range = bb[:max_lng] - bb[:min_lng]

        { lat: lat_range * lat_meters_per_deg, lng: lng_range * lng_meters_per_deg }
      end

      # URL-friendly slug (the geohash itself is already URL-safe)
      alias_method :to_slug, :to_s

      private

      # Encode lat/lng to a geohash string of given length using bit interleaving
      def encode(lat, lng, length = DEFAULT_LENGTH)
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
    end
  end
end
