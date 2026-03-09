#!/usr/bin/env ruby

# Demonstration of rendering geodetic coordinates on a map
# using the libgd-gis gem for native Ruby map generation.
#
# Prerequisites:
#   gem install libgd-gis
#   brew install gd  (macOS) or apt install libgd-dev (Linux)
#
# Usage:
#   ruby -Ilib examples/05_map_rendering.rb

require_relative "../lib/geodetic"
require "gd/gis"

include Geodetic
LLA = Coordinate::LLA
UTM = Coordinate::UTM

# --- 1. Define some points of interest (lat, lng, alt) ---

landmarks = {
  "Statue of Liberty"  => LLA.new(lat: 40.6892, lng: -74.0445, alt: 0),
  "Empire State Bldg"  => LLA.new(lat: 40.7484, lng: -73.9857, alt: 0),
  "Central Park"       => LLA.new(lat: 40.7829, lng: -73.9654, alt: 0),
  "Brooklyn Bridge"    => LLA.new(lat: 40.7061, lng: -73.9969, alt: 0),
  "Times Square"       => LLA.new(lat: 40.7580, lng: -73.9855, alt: 0),
}

# --- 2. Compute a bounding box from the coordinates ---

lats = landmarks.values.map(&:lat)
lngs = landmarks.values.map(&:lng)
padding = 0.02

bbox = [
  lngs.min - padding,  # west
  lats.min - padding,  # south
  lngs.max + padding,  # east
  lats.max + padding   # north
]

# --- 3. Create the map ---

map = GD::GIS::Map.new(
  bbox:    bbox,
  zoom:    13,
  basemap: :carto_dark,
  width:   1024,
  height:  768
)

# --- Helper: generate a circle polygon in [lng, lat] coords ---

def circle_coords(center_lat, center_lng, radius_m, segments = 24)
  lat1 = center_lat * Math::PI / 180.0
  lng1 = center_lng * Math::PI / 180.0
  d    = radius_m / 6_371_000.0

  (0...segments).map do |i|
    brng = (360.0 / segments) * i * Math::PI / 180.0
    lat2 = Math.asin(Math.sin(lat1) * Math.cos(d) + Math.cos(lat1) * Math.sin(d) * Math.cos(brng))
    lng2 = lng1 + Math.atan2(Math.sin(brng) * Math.sin(d) * Math.cos(lat1),
                             Math.cos(d) - Math.sin(lat1) * Math.sin(lat2))
    [lng2 * 180.0 / Math::PI, lat2 * 180.0 / Math::PI]
  end
end

# --- 4. Plot each landmark as a bright filled circle ---
#
# Note: add_point requires a label+font to render (and img.text has a
# compatibility issue with ruby-libgd 0.3.0), so we use add_polygons
# to draw visible marker circles instead.

marker_polygons = landmarks.values.map do |lla|
  [circle_coords(lla.lat, lla.lng, 200)]  # 200m radius marker, wrapped in ring array
end

map.add_polygons(
  marker_polygons,
  fill:   [255, 0, 0, 0],
  stroke: [255, 255, 0, 0],
  width:  2
)

# --- 5. Draw a larger circle around Central Park ---

central_park_center = landmarks["Central Park"]
park_ring = circle_coords(central_park_center.lat, central_park_center.lng, 500, 32)

map.add_polygons(
  [[park_ring]],
  fill:   [80, 255, 120, 80],
  stroke: [100, 255, 150, 255],
  width:  2
)

# --- 6. Show coordinate conversions in the console ---

puts "Landmarks and their UTM coordinates:"
puts "-" * 60

landmarks.each do |name, lla|
  utm = lla.to_utm

  puts <<~INFO
    #{name}
      LLA: #{lla.to_s(4)}
      UTM: #{utm.to_s(2)}
      Distance to Statue of Liberty: #{lla.distance_to(landmarks["Statue of Liberty"]).to_km}
      Bearing to Statue of Liberty:  #{lla.bearing_to(landmarks["Statue of Liberty"])}

  INFO
end

# --- 7. Render, add labels, and save ---

output_path = File.join(__dir__, "nyc_landmarks.png")
map.render

# Draw landmark labels directly on the rendered image using the map's
# internal viewport-adjusted bbox for accurate projection.
FONT = "/System/Library/Fonts/Supplemental/Arial Bold.ttf"
map_bbox = map.instance_variable_get(:@bbox)

landmarks.each do |name, lla|
  px, py = GD::GIS::Geometry.project(lla.lng, lla.lat, map_bbox, 13)
  map.image.text(name, x: px.round + 12, y: py.round + 5,
                       font: FONT, size: 16, color: [255, 255, 255])
end

map.save(output_path)

puts "Map saved to #{output_path}"
