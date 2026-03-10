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
      @coordinates.each_cons(2).map { |a, b| Segment.new(a, b) }
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

      segments.any? { |seg| seg.contains?(coordinate, tolerance: tolerance) }
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

      segments.each do |seg|
        seg_len = seg.length_meters
        if accumulated + seg_len >= target_m
          fraction = (target_m - accumulated) / seg_len
          return seg.interpolate(fraction)
        end
        accumulated += seg_len
      end

      @coordinates.last
    end

    def bounds
      raise ArgumentError, "path is empty" if empty?

      lats = @coordinates.map { |c| c.is_a?(Coordinate::LLA) ? c.lat : c.to_lla.lat }
      lngs = @coordinates.map { |c| c.is_a?(Coordinate::LLA) ? c.lng : c.to_lla.lng }

      Areas::BoundingBox.new(
        nw: Coordinate::LLA.new(lat: lats.max, lng: lngs.min, alt: 0),
        se: Coordinate::LLA.new(lat: lats.min, lng: lngs.max, alt: 0)
      )
    end

    def to_polygon
      raise ArgumentError, "need at least 3 coordinates for a polygon" if size < 3

      closing = Segment.new(@coordinates.last, @coordinates.first)
      interior = segments[1...-1] || []

      if interior.any? { |seg| closing.intersects?(seg) }
        raise ArgumentError, "closing segment intersects the path"
      end

      Areas::Polygon.new(boundary: @coordinates.dup)
    end

    def intersects?(other_path)
      raise ArgumentError, "expected a Path" unless other_path.is_a?(Path)

      segments.each do |seg1|
        other_path.segments.each do |seg2|
          return true if seg1.intersects?(seg2)
        end
      end

      false
    end

    def total_distance
      segment_distances.reduce(Distance.new(0)) { |sum, d| sum + d }
    end

    def segment_distances
      segments.map(&:length)
    end

    def segment_bearings
      segments.map(&:bearing)
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

    # --- Translation ---

    def *(other)
      raise ArgumentError, "expected a Vector, got #{other.class}" unless other.is_a?(Vector)

      self.class.new(coordinates: @coordinates.map { |c| other.destination_from(c) })
    end

    alias translate *

    # --- Geometric conversions ---

    def to_corridor(width:)
      raise ArgumentError, "need at least 2 coordinates for a corridor" if size < 2

      half = (width.is_a?(Distance) ? width.meters : width.to_f) / 2.0
      segs = segments
      bearings = segs.map { |s| s.bearing.degrees }

      left_side  = []
      right_side = []

      @coordinates.each_with_index do |coord, i|
        lla = coord.is_a?(Coordinate::LLA) ? coord : coord.to_lla

        if i == 0
          perp = bearings[0]
        elsif i == @coordinates.length - 1
          perp = bearings[-1]
        else
          perp = mean_bearing(bearings[i - 1], bearings[i])
        end

        left_side  << offset_point(lla, perp - 90.0, half)
        right_side << offset_point(lla, perp + 90.0, half)
      end

      Areas::Polygon.new(boundary: left_side + right_side.reverse)
    end

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
      elsif other.is_a?(Segment)
        [other.start_point, other.end_point].each { |c| append!(c) }
      elsif other.is_a?(Vector)
        dest = other.destination_from(@coordinates.last)
        check_duplicate!(dest)
        @coordinates << dest
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
        seg = Segment.new(@coordinates[idx - 1], waypoint)
        candidate, candidate_dist = seg.project(target)
        if candidate_dist < best_dist
          best = candidate
          best_dist = candidate_dist
        end
      end

      if idx < @coordinates.length - 1
        seg = Segment.new(waypoint, @coordinates[idx + 1])
        candidate, candidate_dist = seg.project(target)
        if candidate_dist < best_dist
          best = candidate
          best_dist = candidate_dist
        end
      end

      best
    end

    def closest_points_to_boundary(boundary_coords)
      boundary_segs = boundary_coords.each_cons(2).map { |a, b| Segment.new(a, b) }

      best = { path_point: nil, area_point: nil, distance: Distance.new(Float::INFINITY) }

      segments.each do |seg|
        boundary_coords.each do |bpt|
          candidate, dist = seg.project(bpt)
          if dist < best[:distance].meters
            best = { path_point: candidate, area_point: bpt, distance: Distance.new(dist) }
          end
        end
      end

      boundary_segs.each do |bseg|
        @coordinates.each do |wpt|
          candidate, dist = bseg.project(wpt)
          if dist < best[:distance].meters
            best = { path_point: wpt, area_point: candidate, distance: Distance.new(dist) }
          end
        end
      end

      best
    end

    def closest_points_to_circle(circle)
      path_point = closest_point_to_coordinate(circle.centroid)
      dist_to_center = path_point.distance_to(circle.centroid).meters

      if dist_to_center < 1e-6
        area_point = circle.centroid
        dist = circle.radius
      elsif dist_to_center <= circle.radius
        area_point = path_point
        dist = 0.0
      else
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
      when Areas::BoundingBox
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
      when Areas::Polygon, Areas::BoundingBox
        area_boundary(other)
      when Areas::Circle
        other
      else
        other.respond_to?(:centroid) ? other.centroid : other
      end
    end

    def resolve_area(other)
      case other
      when Feature
        resolve_area(other.geometry)
      when Areas::Circle, Areas::Polygon, Areas::BoundingBox, Path
        other
      else
        raise ArgumentError, "expected an Area or Path, got #{other.class}"
      end
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

    def dup_path
      self.class.new(coordinates: @coordinates.dup)
    end

    def dup_path_without(coordinate)
      self.class.new(coordinates: @coordinates.reject { |c| c == coordinate })
    end

    def offset_point(lla, bearing_deg, distance_m)
      Vector.new(distance: distance_m, bearing: bearing_deg).destination_from(lla)
    end

    def mean_bearing(b1, b2)
      r1 = b1 * RAD_PER_DEG
      r2 = b2 * RAD_PER_DEG
      Math.atan2(
        Math.sin(r1) + Math.sin(r2),
        Math.cos(r1) + Math.cos(r2)
      ) * DEG_PER_RAD
    end
  end
end
