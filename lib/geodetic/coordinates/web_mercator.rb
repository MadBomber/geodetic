# frozen_string_literal: true

# Web Mercator Coordinate System (EPSG:3857)
# Also known as Pseudo-Mercator, Spherical Mercator, or Google Web Mercator
# Used by Google Maps, OpenStreetMap, Bing Maps, and most web mapping services

module Geodetic
  module Coordinates
    class WebMercator
      require_relative '../datum'

      attr_reader :x, :y

      # Web Mercator constants
      EARTH_RADIUS = 6378137.0  # WGS84 semi-major axis in meters
      ORIGIN_SHIFT = Math::PI * EARTH_RADIUS  # 20037508.342789244
      MAX_LATITUDE = 85.0511287798  # Maximum latitude for Web Mercator

      def initialize(x: 0.0, y: 0.0)
        @x = x.to_f
        @y = y.to_f
      end

      def x=(value)
        @x = value.to_f
      end

      def y=(value)
        @y = value.to_f
      end

      def to_s(precision = 2)
        precision = precision.to_i
        if precision == 0
          "#{@x.round}, #{@y.round}"
        else
          format("%.#{precision}f, %.#{precision}f", @x, @y)
        end
      end

      def to_a
        [@x, @y]
      end

      def self.from_array(array)
        new(x: array[0].to_f, y: array[1].to_f)
      end

      def self.from_string(string)
        parts = string.split(',').map(&:strip)
        new(x: parts[0].to_f, y: parts[1].to_f)
      end

      def to_lla(datum = WGS84)
        # Convert from Web Mercator to WGS84 lat/lng
        lng = (@x / EARTH_RADIUS) * DEG_PER_RAD
        lat = (2.0 * Math.atan(Math.exp(@y / EARTH_RADIUS)) - Math::PI / 2.0) * DEG_PER_RAD

        # Clamp latitude to valid range
        lat = [[-MAX_LATITUDE, lat].max, MAX_LATITUDE].min

        LLA.new(lat: lat, lng: lng, alt: 0.0)
      end

      def self.from_lla(lla_coord, datum = WGS84)
        lat = lla_coord.lat
        lng = lla_coord.lng

        # Clamp latitude to Web Mercator limits
        lat = [[-MAX_LATITUDE, lat].max, MAX_LATITUDE].min

        # Convert to Web Mercator
        x = lng * RAD_PER_DEG * EARTH_RADIUS
        y = Math.log(Math.tan((90.0 + lat) * RAD_PER_DEG / 2.0)) * EARTH_RADIUS

        new(x: x, y: y)
      end

      def to_ecef(datum = WGS84)
        to_lla(datum).to_ecef(datum)
      end

      def self.from_ecef(ecef_coord, datum = WGS84)
        lla_coord = ecef_coord.to_lla(datum)
        from_lla(lla_coord, datum)
      end

      def to_utm(datum = WGS84)
        to_lla(datum).to_utm(datum)
      end

      def self.from_utm(utm_coord, datum = WGS84)
        lla_coord = utm_coord.to_lla(datum)
        from_lla(lla_coord, datum)
      end

      def to_enu(reference_lla, datum = WGS84)
        to_lla(datum).to_enu(reference_lla)
      end

      def self.from_enu(enu_coord, reference_lla, datum = WGS84)
        lla_coord = enu_coord.to_lla(reference_lla)
        from_lla(lla_coord, datum)
      end

      def to_ned(reference_lla, datum = WGS84)
        to_lla(datum).to_ned(reference_lla)
      end

      def self.from_ned(ned_coord, reference_lla, datum = WGS84)
        lla_coord = ned_coord.to_lla(reference_lla)
        from_lla(lla_coord, datum)
      end

      def to_mgrs(datum = WGS84, precision = 5)
        MGRS.from_lla(to_lla(datum), datum, precision)
      end

      def self.from_mgrs(mgrs_coord, datum = WGS84)
        lla_coord = mgrs_coord.to_lla(datum)
        from_lla(lla_coord, datum)
      end

      def to_usng(datum = WGS84, precision = 5)
        USNG.from_lla(to_lla(datum), datum, precision)
      end

      def self.from_usng(usng_coord, datum = WGS84)
        from_lla(usng_coord.to_lla(datum), datum)
      end

      def to_ups(datum = WGS84)
        UPS.from_lla(to_lla(datum), datum)
      end

      def self.from_ups(ups_coord, datum = WGS84)
        from_lla(ups_coord.to_lla(datum), datum)
      end

      def to_state_plane(zone_code, datum = WGS84)
        StatePlane.from_lla(to_lla(datum), zone_code, datum)
      end

      def self.from_state_plane(sp_coord, datum = WGS84)
        from_lla(sp_coord.to_lla(datum), datum)
      end

      def to_bng(datum = WGS84)
        BNG.from_lla(to_lla(datum))
      end

      def self.from_bng(bng_coord, datum = WGS84)
        from_lla(bng_coord.to_lla, datum)
      end

      def to_gh36(precision: 10)
        GH36.new(to_lla, precision: precision)
      end

      def self.from_gh36(gh36_coord, datum = WGS84)
        from_lla(gh36_coord.to_lla, datum)
      end

      def to_gh(precision: 12)
        GH.new(to_lla, precision: precision)
      end

      def self.from_gh(gh_coord, datum = WGS84)
        from_lla(gh_coord.to_lla, datum)
      end

      def to_ham(precision: 6)
        HAM.new(to_lla, precision: precision)
      end

      def self.from_ham(ham_coord, datum = WGS84)
        from_lla(ham_coord.to_lla, datum)
      end

      def to_olc(precision: 10)
        OLC.new(to_lla, precision: precision)
      end

      def self.from_olc(olc_coord, datum = WGS84)
        from_lla(olc_coord.to_lla, datum)
      end

      # Tile coordinate methods for web mapping
      def to_tile_coordinates(zoom_level)
        lat_lng = to_lla
        lat_rad = lat_lng.lat * RAD_PER_DEG

        n = 2.0 ** zoom_level
        x_tile = ((lat_lng.lng + 180.0) / 360.0 * n).floor
        y_tile = ((1.0 - Math.asinh(Math.tan(lat_rad)) / Math::PI) / 2.0 * n).floor

        [x_tile, y_tile, zoom_level]
      end

      def self.from_tile_coordinates(x_tile, y_tile, zoom_level)
        n = 2.0 ** zoom_level
        lng = x_tile.to_f / n * 360.0 - 180.0
        lat_rad = Math.atan(Math.sinh(Math::PI * (1 - 2 * y_tile.to_f / n)))
        lat = lat_rad * DEG_PER_RAD

        lla = LLA.new(lat: lat, lng: lng, alt: 0.0)
        from_lla(lla)
      end

      # Pixel coordinate methods (assuming 256x256 pixel tiles)
      def to_pixel_coordinates(zoom_level, tile_size = 256)
        lat_lng = to_lla
        lat_rad = lat_lng.lat * RAD_PER_DEG

        n = 2.0 ** zoom_level
        x_pixel = (lat_lng.lng + 180.0) / 360.0 * n * tile_size
        y_pixel = (1.0 - Math.asinh(Math.tan(lat_rad)) / Math::PI) / 2.0 * n * tile_size

        [x_pixel.round, y_pixel.round, zoom_level]
      end

      def self.from_pixel_coordinates(x_pixel, y_pixel, zoom_level, tile_size = 256)
        n = 2.0 ** zoom_level
        lng = x_pixel.to_f / (n * tile_size) * 360.0 - 180.0
        lat_rad = Math.atan(Math.sinh(Math::PI * (1 - 2 * y_pixel.to_f / (n * tile_size))))
        lat = lat_rad * DEG_PER_RAD

        lla = LLA.new(lat: lat, lng: lng, alt: 0.0)
        from_lla(lla)
      end

      def ==(other)
        return false unless other.is_a?(WebMercator)

        (@x - other.x).abs <= 1e-6 && (@y - other.y).abs <= 1e-6
      end

      # Bounds checking
      def valid?
        @x.abs <= ORIGIN_SHIFT && @y.abs <= ORIGIN_SHIFT
      end

      def clamp!
        @x = [[-ORIGIN_SHIFT, @x].max, ORIGIN_SHIFT].min
        @y = [[-ORIGIN_SHIFT, @y].max, ORIGIN_SHIFT].min
        self
      end


      # Get bounds for a tile
      def self.tile_bounds(x_tile, y_tile, zoom_level)
        nw = from_tile_coordinates(x_tile, y_tile + 1, zoom_level)
        se = from_tile_coordinates(x_tile + 1, y_tile, zoom_level)

        {
          north_west: nw,
          south_east: se,
          north: nw.y,
          south: se.y,
          west: nw.x,
          east: se.x
        }
      end
    end
  end
end
