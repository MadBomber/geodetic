# frozen_string_literal: true

# S2 (Google's Spherical Geometry) Coordinate
#
# A hierarchical geospatial index that projects a cube onto the unit sphere,
# then recursively subdivides each face into quadrilateral cells using a
# Hilbert curve. Each cell is identified by a 64-bit S2CellId, displayed
# as a hex token with trailing zeros stripped.
#
# REQUIRES: libs2 shared library (brew install s2geometry)
# Uses Ruby's fiddle (stdlib) to call S2 C++ API — no gem dependency.
#
# Key differences from other spatial hashes:
#   - Cells are quadrilaterals bounded by geodesics (not rectangles)
#   - 31 levels (0-30); level 30 ≈ 0.7 cm², level 0 ≈ 85M km²
#   - to_area returns Areas::Polygon with 4 vertices
#   - neighbors returns an Array of 4 edge neighbors
#   - "precision" maps to S2 level (0-30), not string length
#   - Hilbert curve ordering: nearby cell IDs ↔ nearby cells
#   - No seams, singularities, or polar distortion
#
# Usage:
#   S2.new("54906ab12f10f899")           # from hex token
#   S2.new(6093487605063678105)          # from integer cell ID
#   S2.new(lla_coord)                    # from any coordinate (level 15)
#   S2.new(lla_coord, precision: 20)     # custom level

require_relative 'spatial_hash'

module Geodetic
  module Coordinate
    class S2 < SpatialHash
      # --- FFI bindings to libs2 via fiddle ---

      module LibS2
        extend Geodetic::NativeLibrary

        load_library(
          env_var: 'LIBS2_PATH',
          lib_names: ['libs2', 'libs2.0'],
          error_message: "libs2 not found. Install S2 Geometry: brew install s2geometry (macOS) " \
            "or see https://github.com/google/s2geometry. " \
            "Set LIBS2_PATH env var to specify a custom library path."
        )

        # S2CellId::S2CellId(S2LatLng const&) — C1 complete constructor
        # S2CellId is 8 bytes (uint64); S2LatLng is 16 bytes (two doubles in radians)
        F_CELLID_FROM_LATLNG = bind(
          '_ZN8S2CellIdC1ERK8S2LatLng',
          [PTR, PTR],
          Fiddle::TYPE_VOID
        )

        # int S2CellId::ToFaceIJOrientation(int* pi, int* pj, int* pOrientation) const
        # Returns face as int; writes i, j, orientation to output pointers
        F_CELLID_TO_FACE_IJ = bind(
          '_ZNK8S2CellId19ToFaceIJOrientationEPiS0_S0_',
          [PTR, PTR, PTR, PTR],
          INT
        )

        # S2CellId S2CellId::FromFaceIJ(int face, int i, int j) — static
        F_CELLID_FROM_FACE_IJ = bind(
          '_ZN8S2CellId10FromFaceIJEiii',
          [INT, INT, INT],
          UINT64
        )

        # void S2CellId::GetEdgeNeighbors(S2CellId* neighbors) const
        # Writes 4 S2CellIds (32 bytes) to the output array
        F_CELLID_EDGE_NEIGHBORS = bind(
          '_ZNK8S2CellId16GetEdgeNeighborsEPS_',
          [PTR, PTR],
          Fiddle::TYPE_VOID
        )

        # S2Cell::S2Cell(S2CellId) — C1 constructor; takes uint64 by value
        F_S2CELL_CTOR = bind(
          '_ZN6S2CellC1E8S2CellId',
          [PTR, UINT64],
          Fiddle::TYPE_VOID
        )

        # double S2Cell::ExactArea() const
        F_S2CELL_EXACT_AREA = bind(
          '_ZNK6S2Cell9ExactAreaEv',
          [PTR],
          DBL
        )

        # double S2Cell::AverageArea(int level) — static
        F_S2CELL_AVERAGE_AREA = bind(
          '_ZN6S2Cell11AverageAreaEi',
          [INT],
          DBL
        )

        # --- High-level wrappers ---

        # Encode lat/lng (degrees) to S2CellId (uint64) at level 30
        def self.lat_lng_to_cell_id(lat_deg, lng_deg)
          require_library!
          latlng_buf = [lat_deg * RAD_PER_DEG, lng_deg * RAD_PER_DEG].pack('dd')
          cellid_buf = "\0" * 8
          F_CELLID_FROM_LATLNG.call(Fiddle::Pointer[cellid_buf], Fiddle::Pointer[latlng_buf])
          cellid_buf.unpack1('Q')
        end

        # Decode S2CellId to face, i, j using the C++ library
        def self.cell_id_to_face_ij(cell_id)
          require_library!
          cellid_buf = [cell_id].pack('Q')
          pi = [0].pack('i'); pj = [0].pack('i'); po = [0].pack('i')
          face = F_CELLID_TO_FACE_IJ.call(
            Fiddle::Pointer[cellid_buf],
            Fiddle::Pointer[pi], Fiddle::Pointer[pj], Fiddle::Pointer[po]
          )
          { face: face, i: pi.unpack1('i'), j: pj.unpack1('i') }
        end

        # Get 4 edge neighbors for a cell ID
        def self.edge_neighbors(cell_id)
          require_library!
          cellid_buf = [cell_id].pack('Q')
          neighbors_buf = "\0" * 32
          F_CELLID_EDGE_NEIGHBORS.call(Fiddle::Pointer[cellid_buf], Fiddle::Pointer[neighbors_buf])
          neighbors_buf.unpack('Q4')
        end

        # Exact area in steradians for a specific cell
        def self.exact_area(cell_id)
          require_library!
          s2cell_buf = "\0" * 256
          F_S2CELL_CTOR.call(Fiddle::Pointer[s2cell_buf], cell_id)
          F_S2CELL_EXACT_AREA.call(Fiddle::Pointer[s2cell_buf])
        end

        # Average area in steradians for a given level
        def self.average_area(level)
          require_library!
          F_S2CELL_AVERAGE_AREA.call(level)
        end
      end

      # --- Pure Ruby S2 coordinate math ---

      module S2Math
        module_function

        # S2 quadratic ST→UV transform (from s2coords.h)
        def st_to_uv(s)
          s >= 0.5 ? (1.0 / 3.0) * (4 * s * s - 1) : (1.0 / 3.0) * (1 - 4 * (1 - s) * (1 - s))
        end

        # S2 quadratic UV→ST inverse transform
        def uv_to_st(u)
          u >= 0 ? 0.5 * Math.sqrt(1 + 3 * u) : 1.0 - 0.5 * Math.sqrt(1 - 3 * u)
        end

        # Face/UV → XYZ unit vector (from s2coords.h)
        def face_uv_to_xyz(face, u, v)
          case face
          when 0 then [ 1,  u,  v]
          when 1 then [-u,  1,  v]
          when 2 then [-u, -v,  1]
          when 3 then [-1, -v, -u]
          when 4 then [ v, -1, -u]
          when 5 then [ v,  u, -1]
          end
        end

        # XYZ → face (largest absolute component determines face)
        def xyz_to_face(x, y, z)
          ax, ay, az = x.abs, y.abs, z.abs
          if ax > ay
            ax > az ? (x > 0 ? 0 : 3) : (z > 0 ? 2 : 5)
          else
            ay > az ? (y > 0 ? 1 : 4) : (z > 0 ? 2 : 5)
          end
        end

        # XYZ → lat/lng in degrees
        def xyz_to_lat_lng(x, y, z)
          norm = Math.sqrt(x * x + y * y + z * z)
          x /= norm; y /= norm; z /= norm
          lat = Math.atan2(z, Math.sqrt(x * x + y * y)) * DEG_PER_RAD
          lng = Math.atan2(y, x) * DEG_PER_RAD
          [lat, lng]
        end

        # IJ → lat/lng via the full S2 coordinate pipeline
        def ij_to_lat_lng(face, i, j, level)
          # IJ → ST: center of the cell
          size = 1 << (30 - level)
          s = (2 * i + size).to_f / (2 << 30)
          t = (2 * j + size).to_f / (2 << 30)

          # ST → UV → XYZ → LatLng
          u = st_to_uv(s)
          v = st_to_uv(t)
          x, y, z = face_uv_to_xyz(face, u, v)
          xyz_to_lat_lng(x, y, z)
        end

        # Compute the 4 corner vertices of a cell in lat/lng degrees
        def cell_vertices(face, i, j, level)
          size = 1 << (30 - level)
          corners = [
            [i,        j       ],
            [i + size, j       ],
            [i + size, j + size],
            [i,        j + size],
          ]

          corners.map do |ci, cj|
            s = ci.to_f / (1 << 30)
            t = cj.to_f / (1 << 30)
            u = st_to_uv(s)
            v = st_to_uv(t)
            x, y, z = face_uv_to_xyz(face, u, v)
            xyz_to_lat_lng(x, y, z)
          end
        end

        # Extract level from cell ID via trailing zeros
        def cell_level(id)
          30 - ((id & -id).bit_length - 1) / 2
        end

        # Extract face from cell ID (bits 61-63)
        def cell_face(id)
          (id >> 61) & 7
        end

        # Compute parent cell ID at a coarser level
        def cell_parent(id, level)
          shift = 2 * (30 - level) + 1
          (id & (~0 << shift)) | (1 << (shift - 1))
        end

        # Compute child cell ID (pos 0-3)
        def cell_child(id, pos)
          new_lsb = (id & -id) >> 2
          id + (2 * pos - 3) * new_lsb
        end

        # Cell ID validity check
        def valid_cell_id?(id)
          return false unless id.is_a?(Integer) && id > 0
          face = (id >> 61) & 7
          return false if face > 5
          lsb = id & -id
          return false if lsb == 0
          # The sentinel bit must be at an even position from bit 0
          (lsb.bit_length - 1).even?
        end

        # Token → cell ID
        def token_to_cell_id(token)
          token.ljust(16, '0').to_i(16)
        end

        # Cell ID → token (hex with trailing zeros stripped)
        def cell_id_to_token(id)
          format('%016x', id).sub(/0+$/, '')
        end

        # Range min/max for database scans
        def range_min(id)
          id - (id & -id) + 1
        end

        def range_max(id)
          id + (id & -id) - 1
        end
      end

      # --- Class configuration ---

      attr_reader :code

      def self.default_precision = 15
      def self.hash_system_name = :s2

      def self.available?
        LibS2.available?
      end

      # --- Constructor ---

      def initialize(source, precision: self.class.default_precision)
        case source
        when Integer
          validate_integer!(source)
          @cell_id = source
          set_code(S2Math.cell_id_to_token(source))
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
              "Expected an S2 token String, Integer cell ID, or coordinate object, got #{source.class}"
          end
        end
      end

      # --- S2-specific methods ---

      # The 64-bit S2 cell ID
      def cell_id
        @cell_id ||= S2Math.token_to_cell_id(@code)
      end

      # S2 cell level (0-30)
      def precision
        @level ||= S2Math.cell_level(cell_id)
      end
      alias_method :level, :precision

      # Cube face (0-5)
      def face
        S2Math.cell_face(cell_id)
      end

      # Is this a level-30 (leaf) cell?
      def leaf?
        level == 30
      end

      # Is this a level-0 (face) cell?
      def face_cell?
        level == 0
      end

      # Parent cell at a coarser level
      def parent(parent_level = nil)
        parent_level ||= level - 1
        raise ArgumentError, "Parent level must be in 0..#{level - 1}, got #{parent_level}" unless parent_level >= 0 && parent_level < level
        self.class.new(S2Math.cell_parent(cell_id, parent_level))
      end

      # 4 child cells at level + 1
      def children
        raise ArgumentError, "Leaf cells (level 30) have no children" if leaf?
        4.times.map { |pos| self.class.new(S2Math.cell_child(cell_id, pos)) }
      end

      # Cell area in square meters
      def cell_area
        LibS2.exact_area(cell_id) * WGS84.a**2
      end

      # Average cell area in square meters for a given level
      def self.average_cell_area(level)
        LibS2.average_area(level) * WGS84.a**2
      end

      # Does this cell contain another?
      def contains?(other)
        other_id = other.is_a?(S2) ? other.cell_id : other
        range_min = S2Math.range_min(cell_id)
        range_max = S2Math.range_max(cell_id)
        other_id >= range_min && other_id <= range_max
      end

      # Does this cell intersect another?
      def intersects?(other)
        other_id = other.is_a?(S2) ? other.cell_id : other
        contains?(other) || S2Math.range_min(other_id) <= S2Math.range_max(cell_id) &&
          S2Math.range_max(other_id) >= S2Math.range_min(cell_id)
      end

      # Range min/max cell IDs for database range scans
      def range_min
        S2Math.range_min(cell_id)
      end

      def range_max
        S2Math.range_max(cell_id)
      end

      # --- Override SpatialHash methods ---

      def valid?
        S2Math.valid_cell_id?(cell_id)
      end

      # Returns 4 edge neighbors as an Array of S2 instances.
      # S2 cells have 4 edge neighbors (not 8 directional like rectangular hashes).
      def neighbors
        ids = LibS2.edge_neighbors(cell_id)
        ids.map { |id| self.class.new(id) }
      end

      # Returns the quadrilateral cell boundary as an Areas::Polygon.
      def to_area
        fij = face_ij
        verts = S2Math.cell_vertices(fij[:face], fij[:i], fij[:j], level)
        boundary = verts.map { |lat, lng| LLA.new(lat: lat, lng: lng, alt: 0.0) }
        Areas::Polygon.new(boundary: boundary)
      end

      # Returns precision in meters as { lat:, lng:, area_m2: }
      def precision_in_meters
        area = cell_area
        edge = Math.sqrt(area)
        { lat: edge, lng: edge, area_m2: area }
      end

      def to_s(format = nil)
        if format == :integer
          cell_id
        else
          @code
        end
      end

      def inspect
        "#<Geodetic::Coordinate::S2 token=#{@code} level=#{level} face=#{face}>"
      end

      protected

      def code_value
        @code
      end

      def normalize(string)
        string.downcase.delete_prefix('0x')
      end

      def set_code(value)
        @code = value
        @cell_id = nil
        @level = nil
        @face_ij_cache = nil
      end

      private

      def face_ij
        @face_ij_cache ||= LibS2.cell_id_to_face_ij(cell_id)
      end

      def encode(lat, lng, level = self.class.default_precision)
        level = level.clamp(0, 30)
        leaf_id = LibS2.lat_lng_to_cell_id(lat, lng)
        parent_id = level == 30 ? leaf_id : S2Math.cell_parent(leaf_id, level)
        S2Math.cell_id_to_token(parent_id)
      end

      def decode(code_string)
        id = S2Math.token_to_cell_id(code_string)
        fij = LibS2.cell_id_to_face_ij(id)
        lat, lng = S2Math.ij_to_lat_lng(fij[:face], fij[:i], fij[:j], S2Math.cell_level(id))
        { lat: lat, lng: lng }
      end

      def decode_bounds(code_string)
        id = S2Math.token_to_cell_id(code_string)
        fij = LibS2.cell_id_to_face_ij(id)
        verts = S2Math.cell_vertices(fij[:face], fij[:i], fij[:j], S2Math.cell_level(id))
        lats = verts.map(&:first)
        lngs = verts.map(&:last)
        { min_lat: lats.min, max_lat: lats.max, min_lng: lngs.min, max_lng: lngs.max }
      end

      def validate_integer!(id)
        raise ArgumentError, "Invalid S2 cell ID: #{id}" unless S2Math.valid_cell_id?(id)
      end

      def validate_code!(code_string)
        raise ArgumentError, "S2 token cannot be empty" if code_string.empty?
        raise ArgumentError, "Invalid S2 token: #{code_string}" unless code_string.match?(/\A[0-9a-f]{1,16}\z/)
        id = S2Math.token_to_cell_id(code_string)
        raise ArgumentError, "Invalid S2 cell ID from token: #{code_string}" unless S2Math.valid_cell_id?(id)
      end

      register_hash_system(:s2, self, default_precision: 15)
    end
  end
end
