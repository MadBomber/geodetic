# frozen_string_literal: true

module Geodetic
  class Feature
    attr_accessor :label, :geometry, :metadata

    def initialize(label:, geometry:, metadata: {})
      @label    = label
      @geometry = geometry
      @metadata = metadata
    end

    def distance_to(other)
      resolve_point.distance_to(resolve_point_from(other))
    end

    def bearing_to(other)
      resolve_point.bearing_to(resolve_point_from(other))
    end

    def to_s
      "#{@label} (#{@geometry})"
    end

    def inspect
      "#<Geodetic::Feature name=#{@label.inspect} geometry=#{@geometry.inspect} metadata=#{@metadata.inspect}>"
    end

    private

    def resolve_point
      @geometry.respond_to?(:centroid) ? @geometry.centroid : @geometry
    end

    def resolve_point_from(other)
      case other
      when Feature
        other.send(:resolve_point)
      else
        other.respond_to?(:centroid) ? other.centroid : other
      end
    end
  end
end
