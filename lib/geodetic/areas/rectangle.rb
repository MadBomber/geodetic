# frozen_string_literal: true

require_relative '../coordinates/lla'

module Geodetic
  module Areas
    class Rectangle
      attr_reader :nw, :se, :centroid

      # Define an axis-aligned rectangle by its NW and SE corners.
      # Accepts any coordinate that responds to to_lla.
      #
      #   Rectangle.new(
      #     nw: LLA.new(lat: 41.0, lng: -75.0),
      #     se: LLA.new(lat: 40.0, lng: -74.0)
      #   )
      def initialize(nw:, se:)
        @nw = nw.is_a?(Coordinates::LLA) ? nw : nw.to_lla
        @se = se.is_a?(Coordinates::LLA) ? se : se.to_lla

        raise ArgumentError, "NW corner must have higher latitude than SE corner" if @nw.lat < @se.lat
        raise ArgumentError, "NW corner must have lower longitude than SE corner" if @nw.lng > @se.lng

        @centroid = Coordinates::LLA.new(
          lat: (@nw.lat + @se.lat) / 2.0,
          lng: (@nw.lng + @se.lng) / 2.0,
          alt: 0.0
        )
      end

      def ne
        Coordinates::LLA.new(lat: @nw.lat, lng: @se.lng, alt: 0.0)
      end

      def sw
        Coordinates::LLA.new(lat: @se.lat, lng: @nw.lng, alt: 0.0)
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
