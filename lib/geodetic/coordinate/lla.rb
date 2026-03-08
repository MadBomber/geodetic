# frozen_string_literal: true

################################
## Latitude, Longitude, Altitude
##
## A negative longitude is the Western hemisphere.
## A negative latitude is in the Southern hemisphere.
## Altitude is in decimal meters

require_relative '../datum'
require_relative '../geoid_height'

module Geodetic
  module Coordinate
    class LLA
      include GeoidHeightSupport
      attr_reader :lat, :lng, :alt
      alias_method :latitude, :lat
      alias_method :longitude, :lng
      alias_method :lon, :lng         # Other popular shortcuts for referencing longitude
      alias_method :long, :lng
      alias_method :altitude, :alt

      def initialize(lat: 0.0, lng: nil, lon: nil, long: nil, alt: 0.0)
        longitude_args = { lng: lng, lon: lon, long: long }.compact
        if longitude_args.size > 1
          raise ArgumentError, "Provide only one of lng:, lon:, or long: (got #{longitude_args.keys.join(', ')})"
        end

        @lat = lat.to_f
        @lng = (longitude_args.values.first || 0.0).to_f
        @alt = alt.to_f

        validate_coordinates!
      end

      def lat=(value)
        value = value.to_f
        raise ArgumentError, "Latitude must be a finite number" if value.nan? || value.infinite?
        raise ArgumentError, "Latitude must be between -90 and 90 degrees" if value < -90 || value > 90
        @lat = value
      end
      alias_method :latitude=, :lat=

      def lng=(value)
        value = value.to_f
        raise ArgumentError, "Longitude must be a finite number" if value.nan? || value.infinite?
        raise ArgumentError, "Longitude must be between -180 and 180 degrees" if value < -180 || value > 180
        @lng = value
      end
      alias_method :longitude=, :lng=
      alias_method :lon=, :lng=
      alias_method :long=, :lng=

      def alt=(value)
        value = value.to_f
        raise ArgumentError, "Altitude must be a finite number" if value.nan? || value.infinite?
        @alt = value
      end
      alias_method :altitude=, :alt=

      def to_ecef(datum = WGS84)
        latitude_rad  = @lat * RAD_PER_DEG
        longitude_rad = @lng * RAD_PER_DEG

        a  = datum.a
        e2 = datum.e2

        n = a / Math.sqrt(1 - e2 * (Math.sin(latitude_rad))**2)

        cos_lat = Math.cos(latitude_rad)
        sin_lat = Math.sin(latitude_rad)
        cos_lon = Math.cos(longitude_rad)
        sin_lon = Math.sin(longitude_rad)

        x = (n + @alt) * cos_lat * cos_lon
        y = (n + @alt) * cos_lat * sin_lon
        z = (n * (1 - e2) + @alt) * sin_lat

        ECEF.new(x: x, y: y, z: z)
      end

      def self.from_ecef(ecef, datum = WGS84)
        raise ArgumentError, "Expected ECEF" unless ecef.is_a?(ECEF)

        ecef.to_lla(datum)
      end

      def to_utm(datum = WGS84)
        lat_rad = @lat * RAD_PER_DEG
        lon_rad = @lng * RAD_PER_DEG

        zone = (((@lng + 180) / 6).floor + 1).to_i
        zone = 60 if zone > 60
        zone = 1 if zone < 1

        a = datum.a
        e2 = datum.e2
        e4 = e2 * e2
        e6 = e4 * e2

        lon0_deg = (zone - 1) * 6 - 180 + 3
        lon0_rad = lon0_deg * RAD_PER_DEG

        k0 = 0.9996

        sin_lat = Math.sin(lat_rad)
        cos_lat = Math.cos(lat_rad)
        tan_lat = Math.tan(lat_rad)

        n = a / Math.sqrt(1 - e2 * sin_lat**2)
        t = tan_lat
        t2 = t * t
        c = e2 * cos_lat**2 / (1 - e2)
        aa = cos_lat * (lon_rad - lon0_rad)

        # Meridional arc — distance along the meridian from equator to lat_rad
        m = a * ((1 - e2 / 4 - 3 * e4 / 64 - 5 * e6 / 256) * lat_rad -
                 (3 * e2 / 8 + 3 * e4 / 32 + 45 * e6 / 1024) * Math.sin(2 * lat_rad) +
                 (15 * e4 / 256 + 45 * e6 / 1024) * Math.sin(4 * lat_rad) -
                 (35 * e6 / 3072) * Math.sin(6 * lat_rad))

        x = k0 * n * (aa +
                       (1 - t2 + c) * aa**3 / 6 +
                       (5 - 18 * t2 + t2**2 + 72 * c - 58 * e2 / (1 - e2)) * aa**5 / 120)

        y = k0 * (m + n * t * (aa**2 / 2 +
                                (5 - t2 + 9 * c + 4 * c**2) * aa**4 / 24 +
                                (61 - 58 * t2 + t2**2 + 600 * c - 330 * e2 / (1 - e2)) * aa**6 / 720))

        x += 500000
        y += 10000000 if @lat < 0

        hemisphere = @lat >= 0 ? 'N' : 'S'

        UTM.new(easting: x, northing: y, altitude: @alt, zone: zone, hemisphere: hemisphere)
      end

      def self.from_utm(utm, datum = WGS84)
        raise ArgumentError, "Expected UTM" unless utm.is_a?(UTM)

        utm.to_lla(datum)
      end

      def to_ned(reference_lla)
        raise ArgumentError, "Expected LLA" unless reference_lla.is_a?(LLA)

        ecef = self.to_ecef
        ref_ecef = reference_lla.to_ecef

        ecef.to_ned(ref_ecef, reference_lla)
      end

      def self.from_ned(ned, reference_lla)
        raise ArgumentError, "Expected NED" unless ned.is_a?(NED)
        raise ArgumentError, "Expected LLA" unless reference_lla.is_a?(LLA)

        ned.to_lla(reference_lla)
      end

      def to_enu(reference_lla)
        raise ArgumentError, "Expected LLA" unless reference_lla.is_a?(LLA)

        ecef = self.to_ecef
        ref_ecef = reference_lla.to_ecef

        ecef.to_enu(ref_ecef, reference_lla)
      end

      def self.from_enu(enu, reference_lla)
        raise ArgumentError, "Expected ENU" unless enu.is_a?(ENU)
        raise ArgumentError, "Expected LLA" unless reference_lla.is_a?(LLA)

        enu.to_lla(reference_lla)
      end

      def to_dms
        lat_abs = @lat.abs
        lat_deg = lat_abs.floor
        lat_min_total = (lat_abs - lat_deg) * 60.0
        lat_min = lat_min_total.floor
        lat_sec = (lat_min_total - lat_min) * 60.0
        lat_hemi = @lat >= 0 ? 'N' : 'S'

        lon_abs = @lng.abs
        lon_deg = lon_abs.floor
        lon_min_total = (lon_abs - lon_deg) * 60.0
        lon_min = lon_min_total.floor
        lon_sec = (lon_min_total - lon_min) * 60.0
        lon_hemi = @lng >= 0 ? 'E' : 'W'

        lat_str = format("%d° %d' %.2f\" %s", lat_deg, lat_min, lat_sec, lat_hemi)
        lon_str = format("%d° %d' %.2f\" %s", lon_deg, lon_min, lon_sec, lon_hemi)
        alt_str = format("%.2f m", @alt)

        "#{lat_str}, #{lon_str}, #{alt_str}"
      end

      def self.from_dms(dms_str)
        regex = /^\s*([0-9]+)°\s*([0-9]+)'\s*([0-9]+(?:\.[0-9]+)?)"\s*([NS])\s*,\s*([0-9]+)°\s*([0-9]+)'\s*([0-9]+(?:\.[0-9]+)?)"\s*([EW])\s*(?:,\s*([\-+]?[0-9]+(?:\.[0-9]+)?)\s*m?)?\s*$/i
        m = dms_str.match(regex)
        raise ArgumentError, "Invalid DMS format" unless m

        lat_deg = m[1].to_i
        lat_min = m[2].to_i
        lat_sec = m[3].to_f
        lat_hemi = m[4].upcase

        lon_deg = m[5].to_i
        lon_min = m[6].to_i
        lon_sec = m[7].to_f
        lon_hemi = m[8].upcase

        alt = m[9] ? m[9].to_f : 0.0

        lat = lat_deg + lat_min / 60.0 + lat_sec / 3600.0
        lat = -lat if lat_hemi == 'S'

        lng = lon_deg + lon_min / 60.0 + lon_sec / 3600.0
        lng = -lng if lon_hemi == 'W'

        new(lat: lat, lng: lng, alt: alt)
      end

      def to_gh36(precision: 10)
        GH36.new(self, precision: precision)
      end

      def self.from_gh36(gh36_coord, datum = WGS84)
        gh36_coord.to_lla(datum)
      end

      def to_gh(precision: 12)
        GH.new(self, precision: precision)
      end

      def self.from_gh(gh_coord, datum = WGS84)
        gh_coord.to_lla(datum)
      end

      def to_ham(precision: 6)
        HAM.new(self, precision: precision)
      end

      def self.from_ham(ham_coord, datum = WGS84)
        ham_coord.to_lla(datum)
      end

      def to_olc(precision: 10)
        OLC.new(self, precision: precision)
      end

      def self.from_olc(olc_coord, datum = WGS84)
        olc_coord.to_lla(datum)
      end

      def to_s(precision = 6)
        precision = precision.to_i
        if precision == 0
          "#{@lat.round}, #{@lng.round}, #{@alt.round}"
        else
          alt_precision = [precision, 2].min
          format("%.#{precision}f, %.#{precision}f, %.#{alt_precision}f", @lat, @lng, @alt)
        end
      end

      def to_a
        [@lat, @lng, @alt]
      end

      def self.from_array(array)
        new(lat: array[0].to_f, lng: array[1].to_f, alt: array[2].to_f)
      end

      def self.from_string(string)
        parts = string.split(',').map(&:strip)
        new(lat: parts[0].to_f, lng: parts[1].to_f, alt: parts[2].to_f)
      end

      def ==(other)
        return false unless other.is_a?(LLA)

        delta_lat = (@lat - other.lat).abs
        delta_lng = (@lng - other.lng).abs
        delta_alt = (@alt - other.alt).abs

        delta_lat <= 1e-6 && delta_lng <= 1e-6 && delta_alt <= 1e-6
      end

      private

      def validate_coordinates!
        raise ArgumentError, "Latitude must be a finite number" if @lat.nan? || @lat.infinite?
        raise ArgumentError, "Longitude must be a finite number" if @lng.nan? || @lng.infinite?
        raise ArgumentError, "Altitude must be a finite number" if @alt.nan? || @alt.infinite?
        raise ArgumentError, "Latitude must be between -90 and 90 degrees" if @lat < -90 || @lat > 90
        raise ArgumentError, "Longitude must be between -180 and 180 degrees" if @lng < -180 || @lng > 180
      end
    end
  end
end
