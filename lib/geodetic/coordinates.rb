# frozen_string_literal: true

require_relative "coordinates/lla"
require_relative "coordinates/ecef"
require_relative "coordinates/utm"
require_relative "coordinates/enu"
require_relative "coordinates/ned"
require_relative "coordinates/mgrs"
require_relative "coordinates/usng"
require_relative "coordinates/web_mercator"
require_relative "coordinates/ups"
require_relative "coordinates/state_plane"
require_relative "coordinates/bng"

module Geodetic
  module Coordinates
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

    # Mixin for all coordinate classes
    module DistanceMethods
      # Great-circle distance from this coordinate to one or more others.
      # Single target returns a Float; multiple returns an Array of Floats.
      def distance_to(*others)
        list = others.length == 1 && others[0].is_a?(Array) ? others[0] : others
        distances = list.map { |other| Coordinates.distance_between(self, other) }
        distances.length == 1 ? distances[0] : distances
      end

      # ECEF straight-line distance from this coordinate to one or more others.
      # Single target returns a Float; multiple returns an Array of Floats.
      def straight_line_distance_to(*others)
        list = others.length == 1 && others[0].is_a?(Array) ? others[0] : others
        distances = list.map { |other| Coordinates.straight_line_distance_between(self, other) }
        distances.length == 1 ? distances[0] : distances
      end
    end
  end
end

# Include DistanceMethods in all coordinate classes
[
  Geodetic::Coordinates::LLA,
  Geodetic::Coordinates::ECEF,
  Geodetic::Coordinates::UTM,
  Geodetic::Coordinates::ENU,
  Geodetic::Coordinates::NED,
  Geodetic::Coordinates::MGRS,
  Geodetic::Coordinates::USNG,
  Geodetic::Coordinates::WebMercator,
  Geodetic::Coordinates::UPS,
  Geodetic::Coordinates::StatePlane,
  Geodetic::Coordinates::BNG,
].each { |klass| klass.include(Geodetic::Coordinates::DistanceMethods) }

# GCS is a convenience alias for Geodetic::Coordinates, available after require "geodetic"
GCS = Geodetic::Coordinates
