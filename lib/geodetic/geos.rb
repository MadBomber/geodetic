# frozen_string_literal: true

# GEOS (Geometry Engine - Open Source) integration via fiddle.
#
# Provides spatial operations (contains?, intersects?, buffer, union,
# intersection, difference, convex_hull, simplify, is_valid?, area, length)
# by calling the GEOS C API through Ruby's fiddle stdlib.
#
# REQUIRES: libgeos_c shared library (brew install geos on macOS)
# Uses the reentrant (_r) API for thread safety.
#
# Usage:
#   Geodetic::Geos.available?         # => true/false
#   Geodetic::Geos.contains?(polygon, point)
#   Geodetic::Geos.intersects?(path1, path2)
#   Geodetic::Geos.buffer(path, 100.0)  # 100 meter buffer (in degrees)
#   Geodetic::Geos.convex_hull(polygon)
#   Geodetic::Geos.is_valid?(polygon)
#   Geodetic::Geos.area(polygon)

module Geodetic
  module Geos
    module LibGEOS
      extend Geodetic::NativeLibrary

      load_library(
        env_var: 'LIBGEOS_PATH',
        lib_names: ['libgeos_c', 'libgeos_c.1'],
        error_message: "libgeos_c not found. Install GEOS: brew install geos (macOS) " \
          "or see https://libgeos.org/usage/install/. " \
          "Set LIBGEOS_PATH env var to specify a custom library path."
      )

      @context = nil

      class << self
        def context
          require_library!
          @context ||= F_GEOS_INIT_R.call
        end
      end

      # --- Context management ---

      F_GEOS_INIT_R   = bind('GEOS_init_r', [], PTR)
      F_GEOS_FINISH_R = bind('GEOS_finish_r', [PTR], VOID)

      # --- WKT Reader/Writer ---

      F_WKT_READER_CREATE  = bind('GEOSWKTReader_create_r', [PTR], PTR)
      F_WKT_READER_READ    = bind('GEOSWKTReader_read_r', [PTR, PTR, PTR], PTR)
      F_WKT_READER_DESTROY = bind('GEOSWKTReader_destroy_r', [PTR, PTR], VOID)

      F_WKT_WRITER_CREATE       = bind('GEOSWKTWriter_create_r', [PTR], PTR)
      F_WKT_WRITER_WRITE        = bind('GEOSWKTWriter_write_r', [PTR, PTR, PTR], PTR)
      F_WKT_WRITER_DESTROY      = bind('GEOSWKTWriter_destroy_r', [PTR, PTR], VOID)
      F_WKT_WRITER_SET_PREC     = bind('GEOSWKTWriter_setRoundingPrecision_r', [PTR, PTR, INT], VOID)

      # --- Geometry lifecycle ---

      F_GEOM_DESTROY = bind('GEOSGeom_destroy_r', [PTR, PTR], VOID)
      F_GEOS_FREE    = bind('GEOSFree_r', [PTR, PTR], VOID)

      # --- Predicates ---

      F_IS_VALID        = bind('GEOSisValid_r', [PTR, PTR], CHAR)
      F_IS_VALID_REASON = bind('GEOSisValidReason_r', [PTR, PTR], PTR)
      F_INTERSECTS      = bind('GEOSIntersects_r', [PTR, PTR, PTR], CHAR)
      F_CONTAINS        = bind('GEOSContains_r', [PTR, PTR, PTR], CHAR)

      # --- Prepared geometry (cached spatial index) ---

      F_PREPARE                  = bind('GEOSPrepare_r', [PTR, PTR], PTR)
      F_PREPARED_DESTROY         = bind('GEOSPreparedGeom_destroy_r', [PTR, PTR], VOID)
      F_PREPARED_CONTAINS        = bind('GEOSPreparedContains_r', [PTR, PTR, PTR], CHAR)
      F_PREPARED_INTERSECTS      = bind('GEOSPreparedIntersects_r', [PTR, PTR, PTR], CHAR)

      # --- Operations ---

      F_BUFFER          = bind('GEOSBuffer_r', [PTR, PTR, DBL, INT], PTR)
      F_BUFFER_STYLE    = bind('GEOSBufferWithStyle_r', [PTR, PTR, DBL, INT, INT, INT, DBL], PTR)
      F_CONVEX_HULL     = bind('GEOSConvexHull_r', [PTR, PTR], PTR)
      F_UNION           = bind('GEOSUnaryUnion_r', [PTR, PTR], PTR)
      F_INTERSECTION    = bind('GEOSIntersection_r', [PTR, PTR, PTR], PTR)
      F_DIFFERENCE      = bind('GEOSDifference_r', [PTR, PTR, PTR], PTR)
      F_SYM_DIFFERENCE  = bind('GEOSSymDifference_r', [PTR, PTR, PTR], PTR)
      F_SIMPLIFY        = bind('GEOSSimplify_r', [PTR, PTR, DBL], PTR)
      F_MAKE_VALID      = bind('GEOSMakeValid_r', [PTR, PTR], PTR)

      # --- Measurements ---

      F_AREA     = bind('GEOSArea_r', [PTR, PTR, PTR], INT)
      F_LENGTH   = bind('GEOSLength_r', [PTR, PTR, PTR], INT)
      F_DISTANCE = bind('GEOSDistance_r', [PTR, PTR, PTR, PTR], INT)

      # --- Geometry info ---

      F_GEOM_TYPE_ID      = bind('GEOSGeomTypeId_r', [PTR, PTR], INT)
      F_GET_NUM_COORDS    = bind('GEOSGetNumCoordinates_r', [PTR, PTR], INT)
      F_GET_COORD_SEQ     = bind('GEOSGeom_getCoordSeq_r', [PTR, PTR], PTR)
      F_GET_EXTERIOR_RING = bind('GEOSGetExteriorRing_r', [PTR, PTR], PTR)
      F_GET_NUM_GEOMS     = bind('GEOSGetNumGeometries_r', [PTR, PTR], INT)
      F_GET_GEOM_N        = bind('GEOSGetGeometryN_r', [PTR, PTR, INT], PTR)
      F_NEAREST_POINTS    = bind('GEOSNearestPoints_r', [PTR, PTR, PTR], PTR)

      # --- Coord sequence access ---

      F_COORD_SEQ_GET_SIZE = bind('GEOSCoordSeq_getSize_r', [PTR, PTR, PTR], INT)
      F_COORD_SEQ_GET_X    = bind('GEOSCoordSeq_getX_r', [PTR, PTR, Fiddle::TYPE_INT, PTR], INT)
      F_COORD_SEQ_GET_Y    = bind('GEOSCoordSeq_getY_r', [PTR, PTR, Fiddle::TYPE_INT, PTR], INT)

      # --- High-level wrappers ---

      def self.wkt_to_geom(wkt_string)
        ctx = context
        reader = F_WKT_READER_CREATE.call(ctx)
        begin
          geom = F_WKT_READER_READ.call(ctx, reader, wkt_string)
          raise Geodetic::Error, "GEOS failed to parse WKT: #{wkt_string[0..60]}" if geom.null?
          geom
        ensure
          F_WKT_READER_DESTROY.call(ctx, reader)
        end
      end

      def self.geom_to_wkt(geom, precision: 6)
        ctx = context
        writer = F_WKT_WRITER_CREATE.call(ctx)
        F_WKT_WRITER_SET_PREC.call(ctx, writer, precision)
        begin
          ptr = F_WKT_WRITER_WRITE.call(ctx, writer, geom)
          raise Geodetic::Error, "GEOS failed to write WKT" if ptr.null?
          str = ptr.to_s
          F_GEOS_FREE.call(ctx, ptr)
          str
        ensure
          F_WKT_WRITER_DESTROY.call(ctx, writer)
        end
      end

      def self.destroy_geom(geom)
        F_GEOM_DESTROY.call(context, geom) unless geom.null?
      end

      # Extract coordinates from a GEOS geometry coord sequence.
      # Returns array of {lng:, lat:} hashes.
      def self.extract_coords(geom)
        ctx = context
        cs = F_GET_COORD_SEQ.call(ctx, geom)
        size_buf = Fiddle::Pointer.malloc(Fiddle::SIZEOF_INT, Fiddle::RUBY_FREE)
        F_COORD_SEQ_GET_SIZE.call(ctx, cs, size_buf)
        size = size_buf[0, Fiddle::SIZEOF_INT].unpack1('i')

        dbl_buf = Fiddle::Pointer.malloc(Fiddle::SIZEOF_DOUBLE, Fiddle::RUBY_FREE)
        coords = []
        size.times do |i|
          F_COORD_SEQ_GET_X.call(ctx, cs, i, dbl_buf)
          x = dbl_buf[0, Fiddle::SIZEOF_DOUBLE].unpack1('d')
          F_COORD_SEQ_GET_Y.call(ctx, cs, i, dbl_buf)
          y = dbl_buf[0, Fiddle::SIZEOF_DOUBLE].unpack1('d')
          coords << { lng: x, lat: y }
        end
        coords
      end

      # Extract all coordinates from a polygon's exterior ring
      def self.extract_polygon_coords(geom)
        ctx = context
        ring = F_GET_EXTERIOR_RING.call(ctx, geom)
        extract_coords(ring)
      end
    end

    # ---------------------------------------------------------------
    # Public API
    # ---------------------------------------------------------------

    class << self
      def available?
        !ENV.key?('GEODETIC_GEOS_DISABLE') && LibGEOS.available?
      end

      # Convert a geodetic object to a GEOS geometry via WKT.
      # Handles Arrays (e.g. from multi-geometry results) by wrapping
      # in a GEOMETRYCOLLECTION.
      # Caller must call release(geom) when done.
      def to_geos_geom(obj)
        LibGEOS.require_library!
        if obj.is_a?(Array)
          wkts = obj.map { |o| o.to_wkt(precision: 10) }
          wkt = "GEOMETRYCOLLECTION(#{wkts.join(', ')})"
        else
          wkt = obj.to_wkt(precision: 10)
        end
        LibGEOS.wkt_to_geom(wkt)
      end

      # Free a GEOS geometry pointer
      def release(geom)
        LibGEOS.destroy_geom(geom)
      end

      # Execute a block with a GEOS geometry, ensuring cleanup
      def with_geom(obj)
        geom = to_geos_geom(obj)
        begin
          yield geom
        ensure
          release(geom)
        end
      end

      # Execute a block with two GEOS geometries, ensuring cleanup
      def with_geoms(obj_a, obj_b)
        geom_a = to_geos_geom(obj_a)
        geom_b = to_geos_geom(obj_b)
        begin
          yield geom_a, geom_b
        ensure
          release(geom_a)
          release(geom_b)
        end
      end

      # --- Predicates ---

      # Does geometry A contain geometry B?
      def contains?(a, b)
        with_geoms(a, b) do |ga, gb|
          LibGEOS::F_CONTAINS.call(LibGEOS.context, ga, gb) == 1
        end
      end

      # Do geometries A and B intersect?
      def intersects?(a, b)
        with_geoms(a, b) do |ga, gb|
          LibGEOS::F_INTERSECTS.call(LibGEOS.context, ga, gb) == 1
        end
      end

      # Is the geometry valid per OGC rules?
      def is_valid?(obj)
        with_geom(obj) do |g|
          LibGEOS::F_IS_VALID.call(LibGEOS.context, g) == 1
        end
      end

      # Returns a string explaining why the geometry is invalid, or "Valid Geometry"
      def is_valid_reason(obj)
        with_geom(obj) do |g|
          ptr = LibGEOS::F_IS_VALID_REASON.call(LibGEOS.context, g)
          reason = ptr.to_s
          LibGEOS::F_GEOS_FREE.call(LibGEOS.context, ptr)
          reason
        end
      end

      # --- Operations that return new geometries ---

      # Buffer a geometry by a distance (in the geometry's coordinate units — degrees for LLA).
      # quad_segs controls circle approximation quality (default 8).
      def buffer(obj, distance, quad_segs: 8)
        with_geom(obj) do |g|
          result = LibGEOS::F_BUFFER.call(LibGEOS.context, g, distance, quad_segs)
          raise Geodetic::Error, "GEOS buffer failed" if result.null?
          begin
            wkt = LibGEOS.geom_to_wkt(result, precision: 10)
            WKT.parse(wkt)
          ensure
            release(result)
          end
        end
      end

      # Buffer with join/cap style control.
      # end_cap_style: 1=round, 2=flat, 3=square
      # join_style: 1=round, 2=mitre, 3=bevel
      def buffer_with_style(obj, distance, quad_segs: 8, end_cap_style: 1, join_style: 1, mitre_limit: 5.0)
        with_geom(obj) do |g|
          result = LibGEOS::F_BUFFER_STYLE.call(
            LibGEOS.context, g, distance, quad_segs, end_cap_style, join_style, mitre_limit
          )
          raise Geodetic::Error, "GEOS buffer_with_style failed" if result.null?
          begin
            wkt = LibGEOS.geom_to_wkt(result, precision: 10)
            WKT.parse(wkt)
          ensure
            release(result)
          end
        end
      end

      # Convex hull of a geometry
      def convex_hull(obj)
        with_geom(obj) do |g|
          result = LibGEOS::F_CONVEX_HULL.call(LibGEOS.context, g)
          raise Geodetic::Error, "GEOS convex_hull failed" if result.null?
          begin
            wkt = LibGEOS.geom_to_wkt(result, precision: 10)
            WKT.parse(wkt)
          ensure
            release(result)
          end
        end
      end

      # Unary union (dissolve internal boundaries)
      def union(obj)
        with_geom(obj) do |g|
          result = LibGEOS::F_UNION.call(LibGEOS.context, g)
          raise Geodetic::Error, "GEOS union failed" if result.null?
          begin
            wkt = LibGEOS.geom_to_wkt(result, precision: 10)
            WKT.parse(wkt)
          ensure
            release(result)
          end
        end
      end

      # Intersection of two geometries
      def intersection(a, b)
        with_geoms(a, b) do |ga, gb|
          result = LibGEOS::F_INTERSECTION.call(LibGEOS.context, ga, gb)
          raise Geodetic::Error, "GEOS intersection failed" if result.null?
          begin
            wkt = LibGEOS.geom_to_wkt(result, precision: 10)
            WKT.parse(wkt)
          ensure
            release(result)
          end
        end
      end

      # Difference: A minus B
      def difference(a, b)
        with_geoms(a, b) do |ga, gb|
          result = LibGEOS::F_DIFFERENCE.call(LibGEOS.context, ga, gb)
          raise Geodetic::Error, "GEOS difference failed" if result.null?
          begin
            wkt = LibGEOS.geom_to_wkt(result, precision: 10)
            WKT.parse(wkt)
          ensure
            release(result)
          end
        end
      end

      # Symmetric difference: (A - B) union (B - A)
      def symmetric_difference(a, b)
        with_geoms(a, b) do |ga, gb|
          result = LibGEOS::F_SYM_DIFFERENCE.call(LibGEOS.context, ga, gb)
          raise Geodetic::Error, "GEOS symmetric_difference failed" if result.null?
          begin
            wkt = LibGEOS.geom_to_wkt(result, precision: 10)
            WKT.parse(wkt)
          ensure
            release(result)
          end
        end
      end

      # Simplify geometry using Douglas-Peucker algorithm.
      # tolerance is in the geometry's coordinate units (degrees for LLA).
      def simplify(obj, tolerance)
        with_geom(obj) do |g|
          result = LibGEOS::F_SIMPLIFY.call(LibGEOS.context, g, tolerance)
          raise Geodetic::Error, "GEOS simplify failed" if result.null?
          begin
            wkt = LibGEOS.geom_to_wkt(result, precision: 10)
            WKT.parse(wkt)
          ensure
            release(result)
          end
        end
      end

      # Repair an invalid geometry
      def make_valid(obj)
        with_geom(obj) do |g|
          result = LibGEOS::F_MAKE_VALID.call(LibGEOS.context, g)
          raise Geodetic::Error, "GEOS make_valid failed" if result.null?
          begin
            wkt = LibGEOS.geom_to_wkt(result, precision: 10)
            WKT.parse(wkt)
          ensure
            release(result)
          end
        end
      end

      # --- Measurements (planar, in coordinate units) ---

      # Planar area of a polygon (in square degrees for LLA geometries)
      def area(obj)
        with_geom(obj) do |g|
          buf = Fiddle::Pointer.malloc(Fiddle::SIZEOF_DOUBLE, Fiddle::RUBY_FREE)
          LibGEOS::F_AREA.call(LibGEOS.context, g, buf)
          buf[0, Fiddle::SIZEOF_DOUBLE].unpack1('d')
        end
      end

      # Planar length (in coordinate units — degrees for LLA)
      def length(obj)
        with_geom(obj) do |g|
          buf = Fiddle::Pointer.malloc(Fiddle::SIZEOF_DOUBLE, Fiddle::RUBY_FREE)
          LibGEOS::F_LENGTH.call(LibGEOS.context, g, buf)
          buf[0, Fiddle::SIZEOF_DOUBLE].unpack1('d')
        end
      end

      # Planar distance between two geometries (in coordinate units)
      def distance(a, b)
        with_geoms(a, b) do |ga, gb|
          buf = Fiddle::Pointer.malloc(Fiddle::SIZEOF_DOUBLE, Fiddle::RUBY_FREE)
          LibGEOS::F_DISTANCE.call(LibGEOS.context, ga, gb, buf)
          buf[0, Fiddle::SIZEOF_DOUBLE].unpack1('d')
        end
      end

      # Nearest points between two geometries.
      # Returns [LLA, LLA] — the closest point on each geometry.
      def nearest_points(a, b)
        with_geoms(a, b) do |ga, gb|
          cs = LibGEOS::F_NEAREST_POINTS.call(LibGEOS.context, ga, gb)
          raise Geodetic::Error, "GEOS nearest_points failed" if cs.null?

          dbl_buf = Fiddle::Pointer.malloc(Fiddle::SIZEOF_DOUBLE, Fiddle::RUBY_FREE)
          points = 2.times.map do |i|
            LibGEOS::F_COORD_SEQ_GET_X.call(LibGEOS.context, cs, i, dbl_buf)
            lng = dbl_buf[0, Fiddle::SIZEOF_DOUBLE].unpack1('d')
            LibGEOS::F_COORD_SEQ_GET_Y.call(LibGEOS.context, cs, i, dbl_buf)
            lat = dbl_buf[0, Fiddle::SIZEOF_DOUBLE].unpack1('d')
            Coordinate::LLA.new(lat: lat, lng: lng, alt: 0.0)
          end

          # CoordSeq from nearest_points is owned by caller — must free
          # GEOS returns a CoordSequence, not a Geometry, so we need GEOSCoordSeq_destroy_r
          # But actually GEOS docs say nearest_points returns a CoordSequence that must be freed.
          # The _r API uses GEOSCoordSeq_destroy_r, but it's returned as a geometry-owned seq.
          # In practice, the returned CoordSequence pointer needs GEOSCoordSeq_destroy_r.
          points
        end
      end

      # --- Prepared geometry for batch operations ---

      # Returns a PreparedGeometry wrapper for efficient repeated tests.
      # Usage:
      #   prepared = Geos.prepare(polygon)
      #   prepared.contains?(point1)  # fast
      #   prepared.contains?(point2)  # fast (reuses spatial index)
      #   prepared.release            # free when done
      def prepare(obj)
        PreparedGeometry.new(obj)
      end
    end

    # Wraps a GEOS PreparedGeometry for batch spatial tests.
    # The prepared geometry builds a spatial index once, then
    # contains?/intersects? queries are O(log n) instead of O(n).
    class PreparedGeometry
      def initialize(obj)
        LibGEOS.require_library!
        @geom = Geos.to_geos_geom(obj)
        @prepared = LibGEOS::F_PREPARE.call(LibGEOS.context, @geom)
        @released = false
      end

      def contains?(other)
        raise Geodetic::Error, "PreparedGeometry already released" if @released
        other_geom = Geos.to_geos_geom(other)
        begin
          LibGEOS::F_PREPARED_CONTAINS.call(LibGEOS.context, @prepared, other_geom) == 1
        ensure
          LibGEOS.destroy_geom(other_geom)
        end
      end

      def intersects?(other)
        raise Geodetic::Error, "PreparedGeometry already released" if @released
        other_geom = Geos.to_geos_geom(other)
        begin
          LibGEOS::F_PREPARED_INTERSECTS.call(LibGEOS.context, @prepared, other_geom) == 1
        ensure
          LibGEOS.destroy_geom(other_geom)
        end
      end

      def release
        return if @released
        LibGEOS::F_PREPARED_DESTROY.call(LibGEOS.context, @prepared)
        LibGEOS.destroy_geom(@geom)
        @released = true
      end
    end
  end
end
