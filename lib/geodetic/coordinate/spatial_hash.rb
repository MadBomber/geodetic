# frozen_string_literal: true

# Base class for spatial hash coordinate systems (GH, GH36, HAM, OLC, etc.)
#
# Spatial hash systems encode latitude/longitude into a string code that
# represents a rectangular cell on the globe. They are immutable, 2D (no altitude),
# and convert to/from other coordinate systems through LLA as intermediary.
#
# Subclass contract — MUST implement:
#   encode(lat, lng, precision)   → String
#   decode(code_string)           → { lat:, lng: }
#   decode_bounds(code_string)    → { min_lat:, max_lat:, min_lng:, max_lng: }
#   validate_code!(string)        → raises ArgumentError or nil
#   set_code(normalized_string)   → sets the internal ivar (@geohash, @code, etc.)
#   code_value                    → returns the internal ivar (protected)
#   self.default_precision        → Integer
#   self.hash_system_name         → Symbol (:gh, :gh36, :ham, :olc)
#
# MAY override:
#   normalize(string)             → String (default: identity)
#   to_s(truncate_to)
#   valid?
#   precision
#   neighbors
#   precision_in_meters

module Geodetic
  module Coordinate
    class SpatialHash
      require_relative '../datum'

      # Direction offsets for neighbors: [lat_direction, lng_direction]
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

      # Registry of spatial hash subclasses for cross-hash conversion generation
      @hash_registry = {}

      class << self
        attr_reader :hash_registry

        def register_hash_system(name, klass, default_precision:)
          SpatialHash.hash_registry[name] = {
            class_name: klass.name.split('::').last,
            default_precision: default_precision
          }
          Coordinate.register_class(klass)
        end

        # Called once after all spatial hash subclasses are loaded.
        # Generates cross-hash to_*/from_* methods with correct keyword names.
        def finalize_cross_hash_conversions!
          SpatialHash.hash_registry.each do |source_name, _source_config|
            source_klass = Geodetic::Coordinate.const_get(SpatialHash.hash_registry[source_name][:class_name])

            SpatialHash.hash_registry.each do |target_name, target_config|
              next if source_name == target_name

              target_class_name = target_config[:class_name]
              precision_kwarg = "#{target_name}_precision"
              default_prec = target_config[:default_precision]

              # Instance method: to_<target>(datum = WGS84, <target>_precision: <default>)
              unless source_klass.method_defined?(:"to_#{target_name}")
                source_klass.class_eval <<~RUBY, __FILE__, __LINE__ + 1
                  def to_#{target_name}(datum = WGS84, #{precision_kwarg}: #{default_prec})
                    #{target_class_name}.new(to_lla(datum), precision: #{precision_kwarg})
                  end
                RUBY
              end

              # Class method: from_<target>(coord, datum = WGS84, precision = default_precision)
              unless source_klass.respond_to?(:"from_#{target_name}")
                source_klass.class_eval <<~RUBY, __FILE__, __LINE__ + 1
                  def self.from_#{target_name}(coord, datum = WGS84, precision = default_precision)
                    new(coord, precision: precision)
                  end
                RUBY
              end
            end
          end
        end

        # Generate hash conversion methods (to_gh, from_gh, etc.) on non-hash coordinate classes.
        # Styles:
        #   :no_datum      — to_gh(precision: N), from_gh(coord, datum = WGS84)
        #   :with_datum    — to_gh(datum = WGS84, precision: N), from_gh(coord, datum = WGS84)
        #   :with_datum_and_precision — same to_* as :with_datum,
        #                               from_gh(coord, datum = WGS84, precision = 5)
        def generate_hash_conversions_for(target_klass, style: :no_datum)
          SpatialHash.hash_registry.each do |hash_name, config|
            hash_class_name = config[:class_name]
            default_prec = config[:default_precision]

            # Instance method: to_<hash>
            unless target_klass.method_defined?(:"to_#{hash_name}")
              case style
              when :no_datum
                target_klass.class_eval <<~RUBY, __FILE__, __LINE__ + 1
                  def to_#{hash_name}(precision: #{default_prec})
                    #{hash_class_name}.new(to_lla, precision: precision)
                  end
                RUBY
              when :with_datum, :with_datum_and_precision
                target_klass.class_eval <<~RUBY, __FILE__, __LINE__ + 1
                  def to_#{hash_name}(datum = WGS84, precision: #{default_prec})
                    #{hash_class_name}.new(to_lla(datum), precision: precision)
                  end
                RUBY
              end
            end

            # Class method: from_<hash>
            unless target_klass.respond_to?(:"from_#{hash_name}")
              case style
              when :no_datum, :with_datum
                target_klass.class_eval <<~RUBY, __FILE__, __LINE__ + 1
                  def self.from_#{hash_name}(coord, datum = WGS84)
                    from_lla(coord.to_lla(datum), datum)
                  end
                RUBY
              when :with_datum_and_precision
                target_klass.class_eval <<~RUBY, __FILE__, __LINE__ + 1
                  def self.from_#{hash_name}(coord, datum = WGS84, precision = 5)
                    from_lla(coord.to_lla(datum), datum, precision)
                  end
                RUBY
              end
            end
          end
        end
      end

      def initialize(source, precision: self.class.default_precision)
        case source
        when String
          normalized = normalize(source.strip)
          validate_code!(normalized)
          set_code(normalized)
        when LLA
          set_code(encode(source.lat, source.lng, precision))
        else
          if source.respond_to?(:to_lla)
            lla = source.to_lla
            set_code(encode(lla.lat, lla.lng, precision))
          else
            raise ArgumentError,
              "Expected a code String or a coordinate object, got #{source.class}"
          end
        end
      end

      def precision
        code_value.length
      end

      def to_s(truncate_to = nil)
        if truncate_to
          code_value[0, truncate_to.to_i]
        else
          code_value
        end
      end

      def to_a
        coords = decode(code_value)
        [coords[:lat], coords[:lng]]
      end

      def self.from_array(array)
        new(LLA.new(lat: array[0].to_f, lng: array[1].to_f))
      end

      def self.from_string(string)
        new(string.strip)
      end

      # Decode to LLA (altitude is always 0.0 since spatial hashes are 2D)
      def to_lla(datum = WGS84)
        coords = decode(code_value)
        lat = coords[:lat].clamp(-90.0, 90.0)
        lng = coords[:lng].clamp(-180.0, 180.0)
        LLA.new(lat: lat, lng: lng, alt: 0.0)
      end

      def self.from_lla(lla, datum = WGS84, precision = default_precision)
        new(lla, precision: precision)
      end

      # --- Standard conversions (all chain through LLA) ---

      def to_ecef(datum = WGS84)
        to_lla(datum).to_ecef(datum)
      end

      def self.from_ecef(ecef, datum = WGS84, precision = default_precision)
        new(ecef, precision: precision)
      end

      def to_utm(datum = WGS84)
        to_lla(datum).to_utm(datum)
      end

      def self.from_utm(utm, datum = WGS84, precision = default_precision)
        new(utm, precision: precision)
      end

      def to_enu(reference_lla, datum = WGS84)
        to_lla(datum).to_enu(reference_lla)
      end

      def self.from_enu(enu, reference_lla, datum = WGS84, precision = default_precision)
        lla_coord = enu.to_lla(reference_lla)
        new(lla_coord, precision: precision)
      end

      def to_ned(reference_lla, datum = WGS84)
        to_lla(datum).to_ned(reference_lla)
      end

      def self.from_ned(ned, reference_lla, datum = WGS84, precision = default_precision)
        lla_coord = ned.to_lla(reference_lla)
        new(lla_coord, precision: precision)
      end

      def to_mgrs(datum = WGS84, mgrs_precision = 5)
        MGRS.from_lla(to_lla(datum), datum, mgrs_precision)
      end

      def self.from_mgrs(mgrs, datum = WGS84, precision = default_precision)
        new(mgrs, precision: precision)
      end

      def to_usng(datum = WGS84, usng_precision = 5)
        USNG.from_lla(to_lla(datum), datum, usng_precision)
      end

      def self.from_usng(usng, datum = WGS84, precision = default_precision)
        new(usng, precision: precision)
      end

      def to_web_mercator(datum = WGS84)
        WebMercator.from_lla(to_lla(datum), datum)
      end

      def self.from_web_mercator(web_mercator, datum = WGS84, precision = default_precision)
        new(web_mercator, precision: precision)
      end

      def to_ups(datum = WGS84)
        UPS.from_lla(to_lla(datum), datum)
      end

      def self.from_ups(ups, datum = WGS84, precision = default_precision)
        new(ups, precision: precision)
      end

      def to_state_plane(zone_code, datum = WGS84)
        StatePlane.from_lla(to_lla(datum), zone_code, datum)
      end

      def self.from_state_plane(state_plane, datum = WGS84, precision = default_precision)
        new(state_plane, precision: precision)
      end

      def to_bng(datum = WGS84)
        BNG.from_lla(to_lla(datum), datum)
      end

      def self.from_bng(bng, datum = WGS84, precision = default_precision)
        new(bng, precision: precision)
      end

      # --- Equality and utility ---

      def ==(other)
        return false unless other.is_a?(self.class)
        code_value == other.code_value
      end


      # Returns all 8 neighboring cells
      # Keys: :N, :S, :E, :W, :NE, :NW, :SE, :SW
      def neighbors
        bb = decode_bounds(code_value)
        lat_step = bb[:max_lat] - bb[:min_lat]
        lng_step = bb[:max_lng] - bb[:min_lng]
        center_lat = (bb[:min_lat] + bb[:max_lat]) / 2.0
        center_lng = (bb[:min_lng] + bb[:max_lng]) / 2.0
        len = precision

        DIRECTIONS.each_with_object({}) do |(dir, delta), result|
          nlat = center_lat + delta[0] * lat_step
          nlng = center_lng + delta[1] * lng_step

          nlat = nlat.clamp(-89.99999999, 89.99999999)
          nlng += 360.0 if nlng < -180.0
          nlng -= 360.0 if nlng > 180.0

          result[dir] = self.class.new(LLA.new(lat: nlat, lng: nlng), precision: len)
        end
      end

      # Returns the cell as an Areas::BoundingBox
      def to_area
        bb = decode_bounds(code_value)
        nw = LLA.new(lat: bb[:max_lat], lng: bb[:min_lng], alt: 0.0)
        se = LLA.new(lat: bb[:min_lat], lng: bb[:max_lng], alt: 0.0)
        Areas::BoundingBox.new(nw: nw, se: se)
      end

      # Returns precision in meters as {lat:, lng:}
      def precision_in_meters
        bb = decode_bounds(code_value)
        lat_center = (bb[:min_lat] + bb[:max_lat]) / 2.0

        lat_meters_per_deg = 111_320.0
        lng_meters_per_deg = 111_320.0 * Math.cos(lat_center * Math::PI / 180.0)

        lat_range = bb[:max_lat] - bb[:min_lat]
        lng_range = bb[:max_lng] - bb[:min_lng]

        { lat: lat_range * lat_meters_per_deg, lng: lng_range * lng_meters_per_deg }
      end

      protected

      # Default normalize is identity — subclasses override (e.g., downcase, upcase)
      def normalize(string)
        string
      end
    end
  end
end
