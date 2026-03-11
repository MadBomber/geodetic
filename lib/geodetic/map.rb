# frozen_string_literal: true

require_relative "map/base"
require_relative "map/lib_gd_gis"

module Geodetic
  module Map
    # Mixin that adds add_to_map to geometry classes.
    # Applied to coordinates, areas, paths, segments, and features.
    module MapMethods
      def add_to_map(map, **style)
        map.add(self, **style)
      end
    end
  end
end

# Apply MapMethods to all coordinate classes
Geodetic::Coordinate.systems.each do |klass|
  klass.include(Geodetic::Map::MapMethods)
end

# Apply MapMethods to geometry types
[
  Geodetic::Path,
  Geodetic::Segment,
  Geodetic::Feature,
  Geodetic::Areas::Polygon,
  Geodetic::Areas::Circle,
  Geodetic::Areas::BoundingBox
].each { |klass| klass.include(Geodetic::Map::MapMethods) }
