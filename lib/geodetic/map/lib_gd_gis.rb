# frozen_string_literal: true

require_relative "base"

module Geodetic
  module Map
    class LibGdGis < Base
      def initialize(bbox: nil, zoom: 10, width: nil, height: nil, basemap: :osm, **options)
        super(**options)
        @bbox    = resolve_bbox(bbox)
        @zoom    = zoom
        @width   = width
        @height  = height
        @basemap = basemap
      end

      def render(output_path = nil, &block)
        require_gd_gis!

        @gd_map = build_map
        apply_layers(@gd_map)
        @gd_map.render

        yield @gd_map if block_given?

        if output_path
          @gd_map.save(output_path)
        end

        @gd_map
      end

      # Access the underlying GD::GIS::Map after render.
      attr_reader :gd_map

      private

      def require_gd_gis!
        require "gd/gis"
      rescue LoadError
        raise LoadError,
          "libgd-gis is required for Geodetic::Map::LibGdGis. " \
          "Add `gem 'libgd-gis'` to your Gemfile."
      end

      def build_map
        args = { zoom: @zoom, basemap: @basemap }
        args[:bbox]   = @bbox   if @bbox
        args[:width]  = @width  if @width
        args[:height] = @height if @height

        ::GD::GIS::Map.new(**args)
      end

      def apply_layers(map)
        @layers.each do |layer|
          case layer[:type]
          when :point
            apply_point(map, layer)
          when :line
            apply_line(map, layer)
          when :polygon
            apply_polygon(map, layer)
          end
        end
      end

      def apply_point(map, layer)
        lla   = layer[:lla]
        style = layer[:style]

        map.add_point(
          lon: lla.longitude,
          lat: lla.latitude,
          **point_options(style)
        )
      end

      def apply_line(map, layer)
        coords = layer[:llas].map { |p| [p.longitude, p.latitude] }
        style  = layer[:style]

        map.add_lines(
          [coords],
          **line_options(style)
        )
      end

      def apply_polygon(map, layer)
        ring  = layer[:llas].map { |p| [p.longitude, p.latitude] }
        style = layer[:style]

        map.add_polygons(
          [[ring]],
          **polygon_options(style)
        )
      end

      # --- Style translation ---

      def point_options(style)
        opts = {}
        opts[:label]      = style[:label]      if style[:label]
        opts[:icon]       = style[:icon]        if style[:icon]
        opts[:font]       = style[:font]        if style[:font]
        opts[:size]       = style[:size]        if style[:size]
        opts[:color]      = style[:color]       if style[:color]
        opts[:font_color] = style[:font_color]  if style[:font_color]
        opts[:symbol]     = style[:symbol]      if style[:symbol]
        opts
      end

      def line_options(style)
        opts = {}
        opts[:stroke] = style[:stroke] || style[:color] || [255, 0, 0]
        opts[:width]  = style[:width] || 2
        opts
      end

      def polygon_options(style)
        opts = {}
        opts[:fill]   = style[:fill]   || style[:color] || [0, 0, 255, 80]
        opts[:stroke] = style[:stroke] if style[:stroke]
        opts[:width]  = style[:width]  if style[:width]
        opts
      end

      # --- BBox resolution ---

      def resolve_bbox(bbox)
        case bbox
        when nil
          nil
        when Array
          bbox
        when Areas::BoundingBox
          [bbox.nw.longitude, bbox.se.latitude, bbox.se.longitude, bbox.nw.latitude]
        else
          if Coordinate.systems.any? { |klass| bbox.is_a?(klass) }
            raise ArgumentError,
              "single coordinate is not a valid bbox. " \
              "Use Geodetic::Areas::BoundingBox or a [west, south, east, north] array."
          end
          bbox
        end
      end
    end
  end
end
