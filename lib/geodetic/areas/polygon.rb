# frozen_string_literal: true

require_relative '../coordinate/lla'

module Geodetic
  module Areas
    class Polygon
      attr_reader :boundary, :centroid

      def initialize(boundary:)
        raise ArgumentError, "A Polygon requires more than #{boundary.length} points on its boundary" unless boundary.length > 2

        @boundary = boundary.dup
        @boundary << boundary[0] unless boundary.first == boundary.last

        centroid_lat = 0.0
        centroid_lng = 0.0
        area = 0.0

        0.upto(@boundary.length - 2) do |i|
          cross = @boundary[i].lng * @boundary[i + 1].lat - @boundary[i + 1].lng * @boundary[i].lat
          area += 0.5 * cross
          centroid_lng += (@boundary[i].lng + @boundary[i + 1].lng) * cross
          centroid_lat += (@boundary[i].lat + @boundary[i + 1].lat) * cross
        end

        centroid_lng /= (6.0 * area)
        centroid_lat /= (6.0 * area)

        @centroid = Coordinate::LLA.new(lat: centroid_lat, lng: centroid_lng, alt: 0.0)
      end

      def includes?(a_point)
        turn_angle = 0.0

        (@boundary.length - 2).times do |index|
          return true if @boundary[index] == a_point

          d_turn_angle  = a_point.bearing_to(@boundary[index + 1]) - a_point.bearing_to(@boundary[index])
          d_turn_angle += (d_turn_angle > 0.0 ? -360.0 : 360.0) if d_turn_angle.abs > 180.0
          turn_angle   += d_turn_angle
        end

        turn_angle.abs > 180.0
      end

      def excludes?(a_point)
        !includes?(a_point)
      end

      alias_method :include?, :includes?
      alias_method :exclude?, :excludes?
      alias_method :inside?,  :includes?
      alias_method :outside?, :excludes?
    end
  end
end
