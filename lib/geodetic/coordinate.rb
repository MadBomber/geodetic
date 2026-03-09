# frozen_string_literal: true

module Geodetic
  module Coordinate
    # Registry for coordinate classes — each class registers itself at load time
    @registered_classes = []

    class << self
      attr_reader :registered_classes

      def register_class(klass)
        @registered_classes << klass
      end
    end
  end
end

require_relative "coordinate/lla"
require_relative "coordinate/ecef"
require_relative "coordinate/utm"
require_relative "coordinate/enu"
require_relative "coordinate/ned"
require_relative "coordinate/mgrs"
require_relative "coordinate/usng"
require_relative "coordinate/web_mercator"
require_relative "coordinate/ups"
require_relative "coordinate/state_plane"
require_relative "coordinate/bng"
require_relative "coordinate/spatial_hash"
require_relative "coordinate/gh36"
require_relative "coordinate/gh"
require_relative "coordinate/ham"
require_relative "coordinate/olc"
require_relative "coordinate/georef"
require_relative "coordinate/gars"
require_relative "coordinate/h3"

module Geodetic
  module Coordinate
    # Vincenty great-circle distance between two LLA points (meters)
    def self.vincenty_distance(lla_a, lla_b)
      a   = WGS84.a
      f   = WGS84.f
      b   = WGS84.b

      lat1 = lla_a.lat * RAD_PER_DEG
      lat2 = lla_b.lat * RAD_PER_DEG
      l    = (lla_b.lng - lla_a.lng) * RAD_PER_DEG

      u1 = Math.atan((1 - f) * Math.tan(lat1))
      u2 = Math.atan((1 - f) * Math.tan(lat2))

      sin_u1 = Math.sin(u1); cos_u1 = Math.cos(u1)
      sin_u2 = Math.sin(u2); cos_u2 = Math.cos(u2)

      lambda_val  = l
      sin_sigma   = 0.0
      cos_sigma   = 0.0
      sigma       = 0.0
      cos2_alpha  = 0.0
      cos_2sigma_m = 0.0

      100.times do
        sin_lambda = Math.sin(lambda_val)
        cos_lambda = Math.cos(lambda_val)

        sin_sigma = Math.sqrt(
          (cos_u2 * sin_lambda)**2 +
          (cos_u1 * sin_u2 - sin_u1 * cos_u2 * cos_lambda)**2
        )

        return 0.0 if sin_sigma == 0.0

        cos_sigma    = sin_u1 * sin_u2 + cos_u1 * cos_u2 * cos_lambda
        sigma        = Math.atan2(sin_sigma, cos_sigma)
        sin_alpha    = cos_u1 * cos_u2 * sin_lambda / sin_sigma
        cos2_alpha   = 1 - sin_alpha**2
        cos_2sigma_m = cos2_alpha == 0.0 ? 0.0 : cos_sigma - 2 * sin_u1 * sin_u2 / cos2_alpha

        c = f / 16 * cos2_alpha * (4 + f * (4 - 3 * cos2_alpha))

        lambda_prev = lambda_val
        lambda_val = l + (1 - c) * f * sin_alpha *
          (sigma + c * sin_sigma * (cos_2sigma_m + c * cos_sigma * (-1 + 2 * cos_2sigma_m**2)))

        break if (lambda_val - lambda_prev).abs < 1e-12
      end

      u_sq = cos2_alpha * (a**2 - b**2) / b**2
      aa = 1 + u_sq / 16384 * (4096 + u_sq * (-768 + u_sq * (320 - 175 * u_sq)))
      bb = u_sq / 1024 * (256 + u_sq * (-128 + u_sq * (74 - 47 * u_sq)))

      delta_sigma = bb * sin_sigma * (cos_2sigma_m + bb / 4 *
        (cos_sigma * (-1 + 2 * cos_2sigma_m**2) -
         bb / 6 * cos_2sigma_m * (-3 + 4 * sin_sigma**2) * (-3 + 4 * cos_2sigma_m**2)))

      b * aa * (sigma - delta_sigma)
    end

    # ECEF Euclidean straight-line distance between two coordinates (meters)
    def self.ecef_distance(ecef_a, ecef_b)
      Math.sqrt((ecef_a.x - ecef_b.x)**2 + (ecef_a.y - ecef_b.y)**2 + (ecef_a.z - ecef_b.z)**2)
    end

    # Normalize splat or array input into a flat array of coordinates
    def self.normalize_coords(*coords)
      coords.length == 1 && coords[0].is_a?(Array) ? coords[0] : coords
    end
    private_class_method :normalize_coords

    # Convert any coordinate to LLA. ENU/NED require a reference point
    # and cannot be converted without one.
    def self.to_lla(coord)
      return coord if coord.is_a?(LLA)

      if coord.is_a?(ENU) || coord.is_a?(NED)
        raise ArgumentError,
          "#{coord.class.name.split('::').last} is a relative coordinate system " \
          "and requires a reference point for distance calculations. " \
          "Convert to an absolute system (e.g., LLA, UTM) first."
      end

      coord.to_lla
    end
    private_class_method :to_lla

    # Convert any coordinate to ECEF. ENU/NED require a reference point
    # and cannot be converted without one.
    def self.to_ecef(coord)
      return coord if coord.is_a?(ECEF)

      if coord.is_a?(ENU) || coord.is_a?(NED)
        raise ArgumentError,
          "#{coord.class.name.split('::').last} is a relative coordinate system " \
          "and requires a reference point for distance calculations. " \
          "Convert to an absolute system (e.g., LLA, UTM) first."
      end

      coord.to_ecef
    end
    private_class_method :to_ecef

    # Great-circle distance along consecutive pairs.
    # Two coordinates returns a Distance; more returns an Array of Distances.
    def self.distance_between(*coords)
      list = normalize_coords(*coords)
      raise ArgumentError, "At least 2 coordinates required" if list.length < 2

      llas = list.map { |c| to_lla(c) }
      distances = llas.each_cons(2).map { |a, b| Distance.new(vincenty_distance(a, b)) }

      distances.length == 1 ? distances[0] : distances
    end

    # ECEF Euclidean distance along consecutive pairs.
    # Two coordinates returns a Distance; more returns an Array of Distances.
    def self.straight_line_distance_between(*coords)
      list = normalize_coords(*coords)
      raise ArgumentError, "At least 2 coordinates required" if list.length < 2

      ecefs = list.map { |c| to_ecef(c) }
      distances = ecefs.each_cons(2).map { |a, b| Distance.new(ecef_distance(a, b)) }

      distances.length == 1 ? distances[0] : distances
    end

    # Great-circle forward azimuth from lla_a to lla_b (degrees, 0-360)
    def self.great_circle_bearing(lla_a, lla_b)
      lat1 = lla_a.lat * RAD_PER_DEG
      lat2 = lla_b.lat * RAD_PER_DEG
      delta_lng = (lla_b.lng - lla_a.lng) * RAD_PER_DEG

      x = Math.sin(delta_lng) * Math.cos(lat2)
      y = Math.cos(lat1) * Math.sin(lat2) - Math.sin(lat1) * Math.cos(lat2) * Math.cos(delta_lng)

      Math.atan2(x, y) * DEG_PER_RAD
    end

    # Elevation angle from observer to target using ECEF and local vertical.
    # Returns degrees (-90 to +90). Positive means target is above observer.
    def self.elevation_angle(lla_observer, ecef_observer, ecef_target)
      # Vector from observer to target
      vx = ecef_target.x - ecef_observer.x
      vy = ecef_target.y - ecef_observer.y
      vz = ecef_target.z - ecef_observer.z

      # Local up direction (geodetic surface normal)
      lat_rad = lla_observer.lat * RAD_PER_DEG
      lng_rad = lla_observer.lng * RAD_PER_DEG
      cos_lat = Math.cos(lat_rad)
      up_x = cos_lat * Math.cos(lng_rad)
      up_y = cos_lat * Math.sin(lng_rad)
      up_z = Math.sin(lat_rad)

      # Vertical component (dot product with up)
      vertical = vx * up_x + vy * up_y + vz * up_z

      # Total distance
      dist = Math.sqrt(vx**2 + vy**2 + vz**2)
      return 0.0 if dist == 0.0

      # Horizontal component
      horizontal = Math.sqrt([dist**2 - vertical**2, 0.0].max)

      Math.atan2(vertical, horizontal) * DEG_PER_RAD
    end

    # Great-circle bearing between consecutive pairs.
    # Two coordinates returns a Bearing; more returns an Array of Bearings.
    def self.bearing_between(*coords)
      list = normalize_coords(*coords)
      raise ArgumentError, "At least 2 coordinates required" if list.length < 2

      llas = list.map { |c| to_lla(c) }
      bearings = llas.each_cons(2).map { |a, b| Bearing.new(great_circle_bearing(a, b)) }

      bearings.length == 1 ? bearings[0] : bearings
    end

    # Mixin for all coordinate classes: distance methods
    module DistanceMethods
      # Great-circle distance from this coordinate to one or more others.
      # Single target returns a Distance; multiple returns an Array of Distances.
      def distance_to(*others)
        list = others.length == 1 && others[0].is_a?(Array) ? others[0] : others
        distances = list.map { |other| Coordinate.distance_between(self, other) }
        distances.length == 1 ? distances[0] : distances
      end

      # ECEF straight-line distance from this coordinate to one or more others.
      # Single target returns a Distance; multiple returns an Array of Distances.
      def straight_line_distance_to(*others)
        list = others.length == 1 && others[0].is_a?(Array) ? others[0] : others
        distances = list.map { |other| Coordinate.straight_line_distance_between(self, other) }
        distances.length == 1 ? distances[0] : distances
      end
    end

    # Mixin for all coordinate classes: bearing methods
    module BearingMethods
      # Great-circle forward azimuth from this coordinate to another.
      # Returns a Bearing (degrees 0-360).
      def bearing_to(other)
        Coordinate.bearing_between(self, other)
      end

      # Elevation angle from this coordinate to another.
      # Returns Float degrees (-90 to +90). Positive means target is above.
      def elevation_to(other)
        lla_self  = Coordinate.send(:to_lla, self)
        ecef_self = Coordinate.send(:to_ecef, self)
        ecef_other = Coordinate.send(:to_ecef, other)

        Coordinate.elevation_angle(lla_self, ecef_self, ecef_other)
      end
    end
  end
end

# Generate cross-hash conversion methods (to_gh, to_ham, etc.) between all spatial hash subclasses
Geodetic::Coordinate::SpatialHash.finalize_cross_hash_conversions!

# Generate hash conversion methods (to_gh, from_gh, etc.) on non-hash coordinate classes
sh = Geodetic::Coordinate::SpatialHash
sh.generate_hash_conversions_for(Geodetic::Coordinate::LLA,          style: :no_datum)
sh.generate_hash_conversions_for(Geodetic::Coordinate::ECEF,         style: :no_datum)
sh.generate_hash_conversions_for(Geodetic::Coordinate::UTM,          style: :no_datum)
sh.generate_hash_conversions_for(Geodetic::Coordinate::WebMercator,  style: :no_datum)
sh.generate_hash_conversions_for(Geodetic::Coordinate::BNG,          style: :with_datum)
sh.generate_hash_conversions_for(Geodetic::Coordinate::UPS,          style: :with_datum)
sh.generate_hash_conversions_for(Geodetic::Coordinate::MGRS,         style: :with_datum_and_precision)
sh.generate_hash_conversions_for(Geodetic::Coordinate::USNG,         style: :with_datum_and_precision)

# Include distance/bearing mixins in all registered coordinate classes
ALL_COORD_CLASSES = Geodetic::Coordinate.registered_classes.freeze

ALL_COORD_CLASSES.each do |klass|
  klass.include(Geodetic::Coordinate::DistanceMethods)
  klass.include(Geodetic::Coordinate::BearingMethods)
end

# GCS is a convenience alias for Geodetic::Coordinate, available after require "geodetic"
GCS = Geodetic::Coordinate
