# frozen_string_literal: true

# H3 (Uber's Hexagonal Hierarchical Spatial Index) Coordinate
#
# A hierarchical geospatial index that divides the globe into hexagonal cells
# (and 12 pentagons) at 16 resolution levels (0-15). Each cell is identified
# by a 64-bit integer (H3Index), typically displayed as a 15-character hex string.
#
# REQUIRES: libh3 shared library (brew install h3)
# Uses Ruby's fiddle (stdlib) to call H3 v4 C API — no gem dependency.
#
# Key differences from other spatial hashes:
#   - Cells are hexagons (6 vertices), not rectangles
#   - to_area returns Areas::Polygon, not Areas::Rectangle
#   - neighbors returns an Array (6 cells), not a directional Hash
#   - "precision" maps to H3 resolution (0-15), not string length
#
# Usage:
#   H3.new("872a1072bffffff")              # from hex string
#   H3.new(0x872a1072bffffff)              # from integer
#   H3.new(lla_coord)                      # from any coordinate
#   H3.new(lla_coord, precision: 9)        # resolution 9

require_relative 'spatial_hash'

module Geodetic
  module Coordinate
    class H3 < SpatialHash
      # --- FFI bindings to libh3 via fiddle ---

      module LibH3
        require 'fiddle'

        SEARCH_PATHS = [
          ENV['LIBH3_PATH'],
          '/opt/homebrew/lib/libh3.dylib',
          '/opt/homebrew/lib/libh3.1.dylib',
          '/usr/local/lib/libh3.dylib',
          '/usr/local/lib/libh3.1.dylib',
          '/usr/lib/libh3.so',
          '/usr/lib/libh3.so.1',
          '/usr/local/lib/libh3.so',
          '/usr/local/lib/libh3.so.1',
          '/usr/lib/x86_64-linux-gnu/libh3.so',
          '/usr/lib/aarch64-linux-gnu/libh3.so',
        ].compact.freeze

        @handle = nil
        @available = false

        class << self
          attr_reader :handle

          def available?
            @available
          end

          def require_library!
            return if @available
            raise Geodetic::Error,
              "libh3 not found. Install H3: brew install h3 (macOS) " \
              "or see https://h3geo.org/docs/installation. " \
              "Set LIBH3_PATH env var to specify a custom library path."
          end
        end

        begin
          path = SEARCH_PATHS.find { |p| File.exist?(p) }
          if path
            @handle = Fiddle.dlopen(path)
            @available = true
          end
        rescue Fiddle::DLError
          @available = false
        end

        # Struct sizes
        SIZEOF_LATLNG = 2 * Fiddle::SIZEOF_DOUBLE          # 16 bytes
        SIZEOF_CELL_BOUNDARY = 8 + 10 * SIZEOF_LATLNG       # 168 bytes (int + pad + 10 LatLngs)
        SIZEOF_H3INDEX = Fiddle::SIZEOF_LONG_LONG            # 8 bytes
        SIZEOF_INT64 = Fiddle::SIZEOF_LONG_LONG              # 8 bytes

        # Function bindings (lazy-loaded)
        def self.bind(name, args, ret)
          return nil unless @available
          ptr = @handle[name]
          Fiddle::Function.new(ptr, args, ret)
        rescue Fiddle::DLError
          nil
        end

        # H3Error latLngToCell(const LatLng *g, int res, H3Index *out)
        F_LAT_LNG_TO_CELL = bind('latLngToCell',
          [Fiddle::TYPE_VOIDP, Fiddle::TYPE_INT, Fiddle::TYPE_VOIDP],
          Fiddle::TYPE_INT)

        # H3Error cellToLatLng(H3Index h3, LatLng *g)
        F_CELL_TO_LAT_LNG = bind('cellToLatLng',
          [Fiddle::TYPE_LONG_LONG, Fiddle::TYPE_VOIDP],
          Fiddle::TYPE_INT)

        # H3Error cellToBoundary(H3Index h3, CellBoundary *gp)
        F_CELL_TO_BOUNDARY = bind('cellToBoundary',
          [Fiddle::TYPE_LONG_LONG, Fiddle::TYPE_VOIDP],
          Fiddle::TYPE_INT)

        # int getResolution(H3Index h)
        F_GET_RESOLUTION = bind('getResolution',
          [Fiddle::TYPE_LONG_LONG],
          Fiddle::TYPE_INT)

        # int isValidCell(H3Index h)
        F_IS_VALID_CELL = bind('isValidCell',
          [Fiddle::TYPE_LONG_LONG],
          Fiddle::TYPE_INT)

        # int isPentagon(H3Index h)
        F_IS_PENTAGON = bind('isPentagon',
          [Fiddle::TYPE_LONG_LONG],
          Fiddle::TYPE_INT)

        # H3Error gridDisk(H3Index origin, int k, H3Index *out)
        F_GRID_DISK = bind('gridDisk',
          [Fiddle::TYPE_LONG_LONG, Fiddle::TYPE_INT, Fiddle::TYPE_VOIDP],
          Fiddle::TYPE_INT)

        # H3Error maxGridDiskSize(int k, int64_t *out)
        F_MAX_GRID_DISK_SIZE = bind('maxGridDiskSize',
          [Fiddle::TYPE_INT, Fiddle::TYPE_VOIDP],
          Fiddle::TYPE_INT)

        # H3Error cellAreaM2(H3Index h, double *out)
        F_CELL_AREA_M2 = bind('cellAreaM2',
          [Fiddle::TYPE_LONG_LONG, Fiddle::TYPE_VOIDP],
          Fiddle::TYPE_INT)

        # H3Error cellToParent(H3Index h, int parentRes, H3Index *out)
        F_CELL_TO_PARENT = bind('cellToParent',
          [Fiddle::TYPE_LONG_LONG, Fiddle::TYPE_INT, Fiddle::TYPE_VOIDP],
          Fiddle::TYPE_INT)

        # H3Error cellToChildrenSize(H3Index h, int childRes, int64_t *out)
        F_CELL_TO_CHILDREN_SIZE = bind('cellToChildrenSize',
          [Fiddle::TYPE_LONG_LONG, Fiddle::TYPE_INT, Fiddle::TYPE_VOIDP],
          Fiddle::TYPE_INT)

        # H3Error cellToChildren(H3Index h, int childRes, H3Index *out)
        F_CELL_TO_CHILDREN = bind('cellToChildren',
          [Fiddle::TYPE_LONG_LONG, Fiddle::TYPE_INT, Fiddle::TYPE_VOIDP],
          Fiddle::TYPE_INT)

        # --- High-level wrappers ---

        def self.lat_lng_to_cell(lat_rad, lng_rad, resolution)
          require_library!
          latlng = Fiddle::Pointer.malloc(SIZEOF_LATLNG, Fiddle::RUBY_FREE)
          latlng[0, SIZEOF_LATLNG] = [lat_rad, lng_rad].pack('d2')
          out = Fiddle::Pointer.malloc(SIZEOF_H3INDEX, Fiddle::RUBY_FREE)
          err = F_LAT_LNG_TO_CELL.call(latlng, resolution, out)
          raise ArgumentError, "H3 latLngToCell error (code #{err})" unless err == 0
          out[0, SIZEOF_H3INDEX].unpack1('Q')
        end

        def self.cell_to_lat_lng(h3_index)
          require_library!
          latlng = Fiddle::Pointer.malloc(SIZEOF_LATLNG, Fiddle::RUBY_FREE)
          err = F_CELL_TO_LAT_LNG.call(h3_index, latlng)
          raise ArgumentError, "H3 cellToLatLng error (code #{err})" unless err == 0
          lat_rad, lng_rad = latlng[0, SIZEOF_LATLNG].unpack('d2')
          { lat: lat_rad * DEG_PER_RAD, lng: lng_rad * DEG_PER_RAD }
        end

        def self.cell_to_boundary(h3_index)
          require_library!
          cb = Fiddle::Pointer.malloc(SIZEOF_CELL_BOUNDARY, Fiddle::RUBY_FREE)
          err = F_CELL_TO_BOUNDARY.call(h3_index, cb)
          raise ArgumentError, "H3 cellToBoundary error (code #{err})" unless err == 0
          num_verts = cb[0, 4].unpack1('i')
          # Vertices start at offset 8 (4 byte int + 4 byte padding)
          verts = cb[8, num_verts * SIZEOF_LATLNG].unpack("d#{num_verts * 2}")
          (0...num_verts).map do |i|
            { lat: verts[i * 2] * DEG_PER_RAD, lng: verts[i * 2 + 1] * DEG_PER_RAD }
          end
        end

        def self.get_resolution(h3_index)
          require_library!
          F_GET_RESOLUTION.call(h3_index)
        end

        def self.is_valid_cell(h3_index)
          require_library!
          F_IS_VALID_CELL.call(h3_index) == 1
        end

        def self.is_pentagon(h3_index)
          require_library!
          F_IS_PENTAGON.call(h3_index) == 1
        end

        def self.grid_disk(h3_index, k)
          require_library!
          size_ptr = Fiddle::Pointer.malloc(SIZEOF_INT64, Fiddle::RUBY_FREE)
          err = F_MAX_GRID_DISK_SIZE.call(k, size_ptr)
          raise ArgumentError, "H3 maxGridDiskSize error (code #{err})" unless err == 0
          max_size = size_ptr[0, SIZEOF_INT64].unpack1('q')

          out = Fiddle::Pointer.malloc(max_size * SIZEOF_H3INDEX, Fiddle::RUBY_FREE)
          err = F_GRID_DISK.call(h3_index, k, out)
          raise ArgumentError, "H3 gridDisk error (code #{err})" unless err == 0

          out[0, max_size * SIZEOF_H3INDEX].unpack("Q#{max_size}").reject(&:zero?)
        end

        def self.cell_area_m2(h3_index)
          require_library!
          out = Fiddle::Pointer.malloc(Fiddle::SIZEOF_DOUBLE, Fiddle::RUBY_FREE)
          err = F_CELL_AREA_M2.call(h3_index, out)
          raise ArgumentError, "H3 cellAreaM2 error (code #{err})" unless err == 0
          out[0, Fiddle::SIZEOF_DOUBLE].unpack1('d')
        end

        def self.cell_to_parent(h3_index, parent_res)
          require_library!
          out = Fiddle::Pointer.malloc(SIZEOF_H3INDEX, Fiddle::RUBY_FREE)
          err = F_CELL_TO_PARENT.call(h3_index, parent_res, out)
          raise ArgumentError, "H3 cellToParent error (code #{err})" unless err == 0
          out[0, SIZEOF_H3INDEX].unpack1('Q')
        end

        def self.cell_to_children(h3_index, child_res)
          require_library!
          size_ptr = Fiddle::Pointer.malloc(SIZEOF_INT64, Fiddle::RUBY_FREE)
          err = F_CELL_TO_CHILDREN_SIZE.call(h3_index, child_res, size_ptr)
          raise ArgumentError, "H3 cellToChildrenSize error (code #{err})" unless err == 0
          count = size_ptr[0, SIZEOF_INT64].unpack1('q')

          out = Fiddle::Pointer.malloc(count * SIZEOF_H3INDEX, Fiddle::RUBY_FREE)
          err = F_CELL_TO_CHILDREN.call(h3_index, child_res, out)
          raise ArgumentError, "H3 cellToChildren error (code #{err})" unless err == 0

          out[0, count * SIZEOF_H3INDEX].unpack("Q#{count}").reject(&:zero?)
        end
      end

      # --- Class configuration ---

      attr_reader :code

      def self.default_precision = 7
      def self.hash_system_name = :h3

      def self.available?
        LibH3.available?
      end

      # --- Constructor ---

      def initialize(source, precision: self.class.default_precision)
        case source
        when Integer
          hex = format('%x', source)
          validate_code!(hex)
          set_code(hex)
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
              "Expected an H3 hex String, Integer, or coordinate object, got #{source.class}"
          end
        end
      end

      # --- H3-specific methods ---

      # The 64-bit H3 cell index
      def h3_index
        @h3_index ||= code.to_i(16)
      end

      # H3 resolution (0-15)
      def precision
        @resolution ||= LibH3.get_resolution(h3_index)
      end
      alias_method :resolution, :precision

      # Is this cell a pentagon? (12 per resolution level)
      def pentagon?
        LibH3.is_pentagon(h3_index)
      end

      # Parent cell at a coarser resolution
      def parent(parent_resolution)
        raise ArgumentError, "Parent resolution must be < #{resolution}" unless parent_resolution < resolution
        parent_idx = LibH3.cell_to_parent(h3_index, parent_resolution)
        self.class.new(parent_idx)
      end

      # Child cells at a finer resolution
      def children(child_resolution)
        raise ArgumentError, "Child resolution must be > #{resolution}" unless child_resolution > resolution
        child_indices = LibH3.cell_to_children(h3_index, child_resolution)
        child_indices.map { |idx| self.class.new(idx) }
      end

      # All cells within k steps (k=0 returns self, k=1 returns 7 cells, etc.)
      def grid_disk(k = 1)
        indices = LibH3.grid_disk(h3_index, k)
        indices.map { |idx| self.class.new(idx) }
      end

      # Cell area in square meters
      def cell_area
        LibH3.cell_area_m2(h3_index)
      end

      # --- Override SpatialHash methods ---

      def valid?
        LibH3.is_valid_cell(h3_index)
      end

      # Returns all adjacent cells as an Array of H3 instances.
      # Hexagons have 6 neighbors; pentagons have 5.
      # Note: returns Array, not directional Hash (hexagons have no cardinal directions).
      def neighbors
        indices = LibH3.grid_disk(h3_index, 1)
        indices.reject { |idx| idx == h3_index }.map { |idx| self.class.new(idx) }
      end

      # Returns the hexagonal cell boundary as an Areas::Polygon.
      def to_area
        verts = LibH3.cell_to_boundary(h3_index)
        boundary = verts.map { |v| LLA.new(lat: v[:lat], lng: v[:lng], alt: 0.0) }
        Areas::Polygon.new(boundary: boundary)
      end

      # Returns approximate precision in meters as { lat:, lng:, area_m2: }
      def precision_in_meters
        area = cell_area
        edge = Math.sqrt(area)
        { lat: edge, lng: edge, area_m2: area }
      end

      def to_s(format = nil)
        if format == :integer
          h3_index
        else
          code
        end
      end

      def code_value
        @code
      end

      protected

      def normalize(string)
        string.downcase.delete_prefix('0x')
      end

      def set_code(value)
        @code = value
        @h3_index = nil
        @resolution = nil
      end

      private

      def encode(lat, lng, resolution = self.class.default_precision)
        resolution = resolution.clamp(0, 15)
        lat_rad = lat * RAD_PER_DEG
        lng_rad = lng * RAD_PER_DEG
        idx = LibH3.lat_lng_to_cell(lat_rad, lng_rad, resolution)
        format('%x', idx)
      end

      def decode(code_string)
        idx = code_string.to_i(16)
        LibH3.cell_to_lat_lng(idx)
      end

      def decode_bounds(code_string)
        idx = code_string.to_i(16)
        verts = LibH3.cell_to_boundary(idx)
        lats = verts.map { |v| v[:lat] }
        lngs = verts.map { |v| v[:lng] }
        { min_lat: lats.min, max_lat: lats.max, min_lng: lngs.min, max_lng: lngs.max }
      end

      def validate_h3!(code_string)
        raise ArgumentError, "H3 code cannot be empty" if code_string.empty?
        raise ArgumentError, "Invalid H3 hex string: #{code_string}" unless code_string.match?(/\A[0-9a-f]+\z/)
        idx = code_string.to_i(16)
        raise ArgumentError, "Invalid H3 cell index: #{code_string}" unless LibH3.is_valid_cell(idx)
      end

      alias_method :validate_code!, :validate_h3!

      register_hash_system(:h3, self, default_precision: 7)
      Coordinate.register_class(self)
    end
  end
end
