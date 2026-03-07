#########################################################################
###
##  File: circle.rb
##  Desc: A class to support basic functions on circle-shaped areas
#

require_relative '../coordinates/lla'

module Geodetic
  module Areas
    class Circle

      attr_accessor :centroid
      attr_accessor :radius

      def initialize(centroid:, radius:)

        @centroid = centroid  # LLA point
        @radius   = radius   # in units of meters

      end

      ######################################
      def includes?(a_point)

        distance = @centroid.distance_to(a_point) * 1000.0  # in units of meters

        return ( distance <= radius )

      end ## end of def includes?(a_point)

      ######################################
      def excludes?(a_point)
        return (not includes?(a_point) )
      end ## end of def excludes?(a_point)

      alias :include? :includes?
      alias :exclude? :excludes?
      alias :inside? :includes?
      alias :outside? :excludes?

    end ## end of class Circle
  end ## end of module Areas
end ## end of module Geodetic
