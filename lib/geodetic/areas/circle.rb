# frozen_string_literal: true

require_relative '../coordinate/lla'

module Geodetic
  module Areas
    class Circle
      attr_reader :centroid, :radius

      def initialize(centroid:, radius:)
        @centroid = centroid  # LLA point
        @radius   = radius   # in units of meters
      end

      def includes?(a_point)
        @centroid.distance_to(a_point).meters <= @radius
      end

      def excludes?(a_point)
        !includes?(a_point)
      end

      alias_method :include?, :includes?
      alias_method :exclude?, :excludes?
      alias_method :inside?,  :includes?
      alias_method :outside?, :excludes?

      def *(other)
        raise ArgumentError, "expected a Vector, got #{other.class}" unless other.is_a?(Vector)

        self.class.new(centroid: other.destination_from(@centroid), radius: @radius)
      end

      alias_method :translate, :*
    end
  end
end
