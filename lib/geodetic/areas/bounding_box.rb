# frozen_string_literal: true

require_relative '../coordinate/lla'

module Geodetic
  module Areas
    class BoundingBox
      attr_reader :nw, :se, :centroid

      # Define an axis-aligned bounding box by its NW and SE corners.
      # Accepts any coordinate that responds to to_lla.
      #
      #   BoundingBox.new(
      #     nw: LLA.new(lat: 41.0, lng: -75.0),
      #     se: LLA.new(lat: 40.0, lng: -74.0)
      #   )
      def initialize(nw:, se:)
        @nw = nw.is_a?(Coordinate::LLA) ? nw : nw.to_lla
        @se = se.is_a?(Coordinate::LLA) ? se : se.to_lla

        raise ArgumentError, "NW corner must have higher latitude than SE corner" if @nw.lat < @se.lat
        raise ArgumentError, "NW corner must have lower longitude than SE corner" if @nw.lng > @se.lng

        @centroid = Coordinate::LLA.new(
          lat: (@nw.lat + @se.lat) / 2.0,
          lng: (@nw.lng + @se.lng) / 2.0,
          alt: 0.0
        )
      end

      def ne
        Coordinate::LLA.new(lat: @nw.lat, lng: @se.lng, alt: 0.0)
      end

      def sw
        Coordinate::LLA.new(lat: @se.lat, lng: @nw.lng, alt: 0.0)
      end

      def includes?(a_point)
        lla = a_point.respond_to?(:to_lla) ? a_point.to_lla : a_point
        lla.lat >= @se.lat && lla.lat <= @nw.lat &&
          lla.lng >= @nw.lng && lla.lng <= @se.lng
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
