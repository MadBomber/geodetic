#########################################################################
###
##  File: polygon.rb
##  Desc: A class to support basic functions on ploygon areas
#

require_relative '../coordinates/lla'

module Geodetic
  module Areas
    class Polygon

      attr_accessor :boundary
      attr_accessor :centroid

      def initialize(boundary:)

        throw "A Polygon requires more than #{boundary.length} points on its boundary" unless boundary.length > 2

        @boundary = boundary
        @boundary << boundary[0] unless boundary.first == boundary.last # close the polygon

        array_length = @boundary.length
        @centroid = Coordinates::LLA.new

        ## area is in square radians; its used within the centroid calculation below
        area = 0

        0.upto(array_length-2) do |index|

          area += 0.5 * ( @boundary[index].lng * @boundary[index + 1].lat \
                          - @boundary[index + 1].lng * @boundary[index].lat \
                        )

        end

        0.upto(array_length-2) do |index|

          @centroid.lng = @centroid.lng + (1 / (6.0 * area)) \
                          * ( @boundary[index].lng + @boundary[index + 1].lng ) \
                          * ( @boundary[index].lng * @boundary[index + 1].lat - @boundary[index + 1].lng * @boundary[index].lat )

          @centroid.lat = @centroid.lat + (1 / (6.0 * area)) \
                          * ( @boundary[index].lat + @boundary[index + 1].lat ) \
                          * ( @boundary[index].lng * @boundary[index + 1].lat - @boundary[index + 1].lng * @boundary[index].lat )

        end

      end

      ######################################
      def includes?(a_point)

        turn_angle = 0.0

        # MAGIC: 2 => 1 for zero based array + 1 for looking at next(+1) point
        (@boundary.length - 2).times do |index|

          return(true) if @boundary[index] == a_point

          d_turn_angle   = a_point.heading_to(@boundary[index + 1]) - a_point.heading_to(@boundary[index])
          d_turn_angle  += ( (d_turn_angle > 0.0) ? -360.0 : 360.0 ) if d_turn_angle.abs > 180.0
          turn_angle    += d_turn_angle

        end

        return(turn_angle.abs > 180.0)

      end ## end of def includes?(a_point)

      ######################################
      def excludes?(a_point)
        return (not includes?(a_point) )
      end ## end of def excludes?(a_point)

      alias :include? :includes?
      alias :exclude? :excludes?
      alias :inside? :includes?
      alias :outside? :excludes?

    end ## end of class Polygon
  end ## end of module Areas
end ## end of module Geodetic
