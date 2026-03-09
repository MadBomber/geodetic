# frozen_string_literal: true

module Geodetic
  class Path
    include Enumerable

    attr_reader :coordinates

    def initialize(coordinates: [])
      @coordinates = []
      coordinates.each { |c| append!(c) }
    end

    # --- Navigation ---

    def first
      @coordinates.first
    end

    def last
      @coordinates.last
    end

    def next(coordinate)
      idx = index_of!(coordinate)
      idx == @coordinates.length - 1 ? nil : @coordinates[idx + 1]
    end

    def prev(coordinate)
      idx = index_of!(coordinate)
      idx == 0 ? nil : @coordinates[idx - 1]
    end

    def segments
      @coordinates.each_cons(2).to_a
    end

    def size
      @coordinates.size
    end

    def each(&block)
      @coordinates.each(&block)
    end

    def empty?
      @coordinates.empty?
    end

    def include?(coordinate)
      @coordinates.any? { |c| c == coordinate }
    end

    alias includes? include?

    def ==(other)
      other.is_a?(Path) &&
        size == other.size &&
        @coordinates.zip(other.coordinates).all? { |a, b| a == b }
    end

    # --- Containment (on any segment within tolerance) ---

    DEFAULT_TOLERANCE_METERS = 10.0

    def contains?(coordinate, tolerance: DEFAULT_TOLERANCE_METERS)
      return true if include?(coordinate)

      segments.any? { |a, b| on_segment?(a, b, coordinate, tolerance) }
    end

    alias inside? contains?

    def excludes?(coordinate, tolerance: DEFAULT_TOLERANCE_METERS)
      !contains?(coordinate, tolerance: tolerance)
    end

    alias exclude? excludes?
    alias outside? excludes?

    # --- Spatial ---

    def nearest_waypoint(target)
      raise ArgumentError, "path is empty" if empty?

      @coordinates.min_by { |c| c.distance_to(target).meters }
    end

    def closest_coordinate_to(other)
      raise ArgumentError, "path is empty" if empty?

      result = resolve_and_compute(other)
      result[:path_point]
    end

    def closest_points_to(other)
      area = resolve_area(other)
      raise ArgumentError, "path is empty" if empty?

      if area.is_a?(Areas::Circle)
        closest_points_to_circle(area)
      elsif area.is_a?(Path)
        closest_points_to_boundary(area.coordinates)
      else
        closest_points_to_boundary(area_boundary(area))
      end
    end

    def distance_to(other)
      resolve_and_compute(other)[:distance]
    end

    def bearing_to(other)
      result = resolve_and_compute(other)
      result[:path_point].bearing_to(result[:area_point] || result[:target])
    end

    # --- Computed ---

    def reverse
      self.class.new(coordinates: @coordinates.reverse)
    end

    def between(from, to)
      i = index_of!(from)
      j = index_of!(to)
      raise ArgumentError, "from must precede to in path" if j < i

      self.class.new(coordinates: @coordinates[i..j])
    end

    def split_at(coordinate)
      idx = index_of!(coordinate)
      left  = self.class.new(coordinates: @coordinates[0..idx])
      right = self.class.new(coordinates: @coordinates[idx..])
      [left, right]
    end

    def at_distance(target_distance)
      raise ArgumentError, "path is empty" if empty?

      target_m = target_distance.is_a?(Distance) ? target_distance.meters : target_distance.to_f
      raise ArgumentError, "distance must be non-negative" if target_m < 0

      return @coordinates.first if target_m == 0 || size == 1

      accumulated = 0.0

      segments.each do |a, b|
        seg_len = a.distance_to(b).meters
        if accumulated + seg_len >= target_m
          fraction = (target_m - accumulated) / seg_len
          a_lla = a.is_a?(Coordinate::LLA) ? a : a.to_lla
          b_lla = b.is_a?(Coordinate::LLA) ? b : b.to_lla
          return Coordinate::LLA.new(
            lat: a_lla.lat + (b_lla.lat - a_lla.lat) * fraction,
            lng: a_lla.lng + (b_lla.lng - a_lla.lng) * fraction,
            alt: a_lla.alt + (b_lla.alt - a_lla.alt) * fraction
          )
        end
        accumulated += seg_len
      end

      @coordinates.last
    end

    def bounds
      raise ArgumentError, "path is empty" if empty?

      lats = @coordinates.map { |c| c.is_a?(Coordinate::LLA) ? c.lat : c.to_lla.lat }
      lngs = @coordinates.map { |c| c.is_a?(Coordinate::LLA) ? c.lng : c.to_lla.lng }

      Areas::Rectangle.new(
        nw: Coordinate::LLA.new(lat: lats.max, lng: lngs.min, alt: 0),
        se: Coordinate::LLA.new(lat: lats.min, lng: lngs.max, alt: 0)
      )
    end

    def to_polygon
      raise ArgumentError, "need at least 3 coordinates for a polygon" if size < 3

      # Check that closing last→first doesn't cross any interior segment
      closing_a = @coordinates.last
      closing_b = @coordinates.first
      interior = segments[1...-1] || []

      if interior.any? { |a, b| segments_intersect?(closing_a, closing_b, a, b) }
        raise ArgumentError, "closing segment intersects the path"
      end

      Areas::Polygon.new(boundary: @coordinates.dup)
    end

    def intersects?(other_path)
      raise ArgumentError, "expected a Path" unless other_path.is_a?(Path)

      segments.each do |a1, b1|
        other_path.segments.each do |a2, b2|
          return true if segments_intersect?(a1, b1, a2, b2)
        end
      end

      false
    end

    def total_distance
      segment_distances.reduce(Distance.new(0)) { |sum, d| sum + d }
    end

    def segment_distances
      segments.map { |a, b| a.distance_to(b) }
    end

    def segment_bearings
      segments.map { |a, b| a.bearing_to(b) }
    end

    # --- Non-mutating operators ---

    def +(coordinate)
      dup_path.tap { |p| p.send(:append!, coordinate) }
    end

    def -(other)
      if other.is_a?(Path)
        other.coordinates.each { |c| index_of!(c) }
        self.class.new(coordinates: @coordinates.reject { |c| other.include?(c) })
      else
        index_of!(other)
        dup_path_without(other)
      end
    end

    # --- Mutating operators ---

    def <<(coordinate)
      append!(coordinate)
      self
    end

    def >>(coordinate)
      prepend!(coordinate)
      self
    end

    def prepend(coordinate)
      prepend!(coordinate)
      self
    end

    def insert(coordinate, after: nil, before: nil)
      raise ArgumentError, "provide either after: or before:, not both" if after && before
      raise ArgumentError, "provide after: or before:" unless after || before

      check_duplicate!(coordinate)

      if after
        idx = index_of!(after)
        @coordinates.insert(idx + 1, coordinate)
      else
        idx = index_of!(before)
        @coordinates.insert(idx, coordinate)
      end
      self
    end

    def delete(coordinate)
      index_of!(coordinate)
      @coordinates.delete_if { |c| c == coordinate }
      self
    end

    alias remove delete

    # --- Display ---

    def to_s
      points = @coordinates.map(&:to_s).join(" -> ")
      "Path(#{size}): #{points}"
    end

    def inspect
      "#<Geodetic::Path size=#{size} first=#{first&.inspect} last=#{last&.inspect}>"
    end

    private

    def append!(other)
      if other.is_a?(Path)
        other.coordinates.each { |c| append!(c) }
      else
        check_duplicate!(other)
        @coordinates << other
      end
    end

    def prepend!(other)
      if other.is_a?(Path)
        other.coordinates.reverse_each { |c| prepend!(c) }
      else
        check_duplicate!(other)
        @coordinates.unshift(other)
      end
    end

    def check_duplicate!(coordinate)
      return unless include?(coordinate)

      raise ArgumentError, "duplicate coordinate: #{coordinate}"
    end

    def index_of!(coordinate)
      idx = @coordinates.index { |c| c == coordinate }
      raise ArgumentError, "coordinate not in path: #{coordinate}" unless idx

      idx
    end

    def resolve_and_compute(other)
      raise ArgumentError, "path is empty" if empty?

      geom = resolve_geometry(other)

      case geom
      when Areas::Circle
        closest_points_to_circle(geom)
      when Array
        closest_points_to_boundary(geom)
      else
        point = closest_point_to_coordinate(geom)
        dist = point.distance_to(geom)
        { path_point: point, area_point: nil, target: geom, distance: dist }
      end
    end

    def closest_point_to_coordinate(target)
      return @coordinates.first if size == 1

      waypoint = nearest_waypoint(target)
      idx = @coordinates.index { |c| c == waypoint }

      best = waypoint
      best_dist = waypoint.distance_to(target).meters

      if idx > 0
        candidate, candidate_dist = project_onto_segment(@coordinates[idx - 1], waypoint, target)
        if candidate_dist < best_dist
          best = candidate
          best_dist = candidate_dist
        end
      end

      if idx < @coordinates.length - 1
        candidate, candidate_dist = project_onto_segment(waypoint, @coordinates[idx + 1], target)
        if candidate_dist < best_dist
          best = candidate
          best_dist = candidate_dist
        end
      end

      best
    end

    def closest_points_to_boundary(boundary_coords)
      boundary_segments = boundary_coords.each_cons(2).to_a

      best = { path_point: nil, area_point: nil, distance: Distance.new(Float::INFINITY) }

      # For each path segment, project each boundary vertex onto it
      # For each boundary segment, project each path waypoint onto it
      segments.each do |seg_a, seg_b|
        boundary_coords.each do |bpt|
          candidate, dist = project_onto_segment(seg_a, seg_b, bpt)
          if dist < best[:distance].meters
            best = { path_point: candidate, area_point: bpt, distance: Distance.new(dist) }
          end
        end
      end

      boundary_segments.each do |bseg_a, bseg_b|
        @coordinates.each do |wpt|
          candidate, dist = project_onto_segment(bseg_a, bseg_b, wpt)
          if dist < best[:distance].meters
            best = { path_point: wpt, area_point: candidate, distance: Distance.new(dist) }
          end
        end
      end

      best
    end

    def closest_points_to_circle(circle)
      # Find closest point on path to the circle's centroid
      path_point = closest_point_to_coordinate(circle.centroid)
      dist_to_center = path_point.distance_to(circle.centroid).meters

      # The closest point on the circle is along the line from
      # centroid toward the path point, offset by the radius
      if dist_to_center < 1e-6
        # Path passes through the center — pick any point on the circle
        area_point = circle.centroid
        dist = circle.radius
      elsif dist_to_center <= circle.radius
        # Path is inside the circle
        area_point = path_point
        dist = 0.0
      else
        # Interpolate from centroid toward path_point by radius distance
        bearing = circle.centroid.bearing_to(path_point).degrees
        fraction = circle.radius / dist_to_center
        c_lla = circle.centroid
        p_lla = path_point.is_a?(Coordinate::LLA) ? path_point : path_point.to_lla

        area_point = Coordinate::LLA.new(
          lat: c_lla.lat + (p_lla.lat - c_lla.lat) * fraction,
          lng: c_lla.lng + (p_lla.lng - c_lla.lng) * fraction,
          alt: c_lla.alt + (p_lla.alt - c_lla.alt) * fraction
        )
        dist = dist_to_center - circle.radius
      end

      { path_point: path_point, area_point: area_point, distance: Distance.new([dist, 0.0].max) }
    end

    def area_boundary(area)
      case area
      when Areas::Polygon
        area.boundary
      when Areas::Rectangle
        [area.nw,
         Coordinate::LLA.new(lat: area.nw.lat, lng: area.se.lng, alt: 0),
         area.se,
         Coordinate::LLA.new(lat: area.se.lat, lng: area.nw.lng, alt: 0),
         area.nw]
      else
        raise ArgumentError, "unsupported area type: #{area.class}"
      end
    end

    def resolve_geometry(other)
      case other
      when Feature
        resolve_geometry(other.geometry)
      when Path
        other.coordinates
      when Areas::Polygon, Areas::Rectangle
        area_boundary(other)
      when Areas::Circle
        other  # handled specially in distance_to/bearing_to/closest_coordinate_to
      else
        other.respond_to?(:centroid) ? other.centroid : other
      end
    end

    def resolve_area(other)
      case other
      when Feature
        resolve_area(other.geometry)
      when Areas::Circle, Areas::Polygon, Areas::Rectangle, Path
        other
      else
        raise ArgumentError, "expected an Area or Path, got #{other.class}"
      end
    end

    # Projects target onto segment A→B using triangle geometry.
    # Returns [closest_coordinate, distance_to_target].
    #
    # Given triangle A-T with known:
    #   - bearing A→B (segment heading)
    #   - bearing A→T
    #   - distance A→T
    #
    # The angle between A→B and A→T gives us:
    #   - along-segment distance = dist_AT * cos(angle)
    #   - perpendicular distance = dist_AT * sin(angle)
    #
    # If the foot of the perpendicular falls between A and B,
    # that foot is the closest point. Otherwise the nearer
    # endpoint wins.
    def project_onto_segment(a, b, target)
      seg_dist   = a.distance_to(b).meters
      dist_a_t   = a.distance_to(target).meters

      # Degenerate: zero-length segment or target at endpoint
      return [a, dist_a_t] if seg_dist < 1e-6
      return [a, 0.0] if dist_a_t < 1e-6

      bearing_ab = a.bearing_to(b).degrees
      bearing_at = a.bearing_to(target).degrees

      # Angle between the segment direction and the line to target
      angle = (bearing_at - bearing_ab).abs
      angle = 360.0 - angle if angle > 180.0
      angle_rad = angle * Geodetic::RAD_PER_DEG

      # Distance along the segment from A to the foot of the perpendicular
      along = dist_a_t * Math.cos(angle_rad)

      # If the foot falls before A or beyond B, the closest point is an endpoint
      if along <= 0.0
        return [a, dist_a_t]
      elsif along >= seg_dist
        dist_b_t = b.distance_to(target).meters
        return [b, dist_b_t]
      end

      # Interpolate along the segment to find the foot
      fraction = along / seg_dist
      a_lla = a.is_a?(Coordinate::LLA) ? a : a.to_lla
      b_lla = b.is_a?(Coordinate::LLA) ? b : b.to_lla

      foot = Coordinate::LLA.new(
        lat: a_lla.lat + (b_lla.lat - a_lla.lat) * fraction,
        lng: a_lla.lng + (b_lla.lng - a_lla.lng) * fraction,
        alt: a_lla.alt + (b_lla.alt - a_lla.alt) * fraction
      )

      [foot, foot.distance_to(target).meters]
    end

    def resolve_point_from(other)
      case other
      when Feature
        geo = other.geometry
        geo.respond_to?(:centroid) ? geo.centroid : geo
      when Path
        raise ArgumentError, "path is empty" if other.empty?
        other.first
      else
        other.respond_to?(:centroid) ? other.centroid : other
      end
    end

    def on_segment?(a, b, point, tolerance)
      seg_dist = a.distance_to(b).meters
      return a == point || b == point if seg_dist < 1e-6

      dist_a_p = a.distance_to(point).meters
      dist_p_b = point.distance_to(b).meters

      # Point must be closer to both endpoints than the segment length
      return false if dist_a_p > seg_dist || dist_p_b > seg_dist

      # Bearing from A->P should match bearing from P->B within a
      # delta derived from the tolerance and segment distance
      delta = Math.atan(tolerance / seg_dist) * Geodetic::DEG_PER_RAD

      bearing_ap = a.bearing_to(point).degrees
      bearing_pb = point.bearing_to(b).degrees

      (bearing_ap - bearing_pb).abs <= delta
    end

    # Checks if two segments (a1→b1) and (a2→b2) intersect using
    # cross-product orientation tests on a flat lat/lng approximation.
    def segments_intersect?(a1, b1, a2, b2)
      p1 = to_flat(a1); q1 = to_flat(b1)
      p2 = to_flat(a2); q2 = to_flat(b2)

      d1 = cross_sign(p2, q2, p1)
      d2 = cross_sign(p2, q2, q1)
      d3 = cross_sign(p1, q1, p2)
      d4 = cross_sign(p1, q1, q2)

      return true if d1 != d2 && d3 != d4

      if d1 == 0 && on_collinear?(p2, q2, p1) then return true end
      if d2 == 0 && on_collinear?(p2, q2, q1) then return true end
      if d3 == 0 && on_collinear?(p1, q1, p2) then return true end
      if d4 == 0 && on_collinear?(p1, q1, q2) then return true end

      false
    end

    def to_flat(coord)
      c = coord.is_a?(Coordinate::LLA) ? coord : coord.to_lla
      [c.lat, c.lng]
    end

    def cross_sign(a, b, c)
      val = (b[0] - a[0]) * (c[1] - a[1]) - (b[1] - a[1]) * (c[0] - a[0])
      val > 1e-12 ? 1 : (val < -1e-12 ? -1 : 0)
    end

    def on_collinear?(a, b, p)
      p[0] >= [a[0], b[0]].min && p[0] <= [a[0], b[0]].max &&
        p[1] >= [a[1], b[1]].min && p[1] <= [a[1], b[1]].max
    end

    def dup_path
      self.class.new(coordinates: @coordinates.dup)
    end

    def dup_path_without(coordinate)
      self.class.new(coordinates: @coordinates.reject { |c| c == coordinate })
    end
  end
end
