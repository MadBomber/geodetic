#!/usr/bin/env ruby

# Demonstration of rendering geodetic coordinates on a map
# using the libgd-gis gem for native Ruby map generation.
# Shows how Geodetic::Feature wraps named coordinates and areas.
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

# --- 1. Define landmarks as Features ---

landmarks = [
  Feature.new(label: "Statue of Liberty", geometry: LLA.new(lat: 40.6892, lng: -74.0445, alt: 0),
              metadata: { category: "monument", year: 1886 }),
  Feature.new(label: "Empire State Bldg",  geometry: LLA.new(lat: 40.7484, lng: -73.9857, alt: 0),
              metadata: { category: "building", floors: 102 }),
  Feature.new(label: "Central Park",       geometry: LLA.new(lat: 40.7829, lng: -73.9654, alt: 0),
              metadata: { category: "park", acres: 843 }),
  Feature.new(label: "Brooklyn Bridge",    geometry: LLA.new(lat: 40.7061, lng: -73.9969, alt: 0),
              metadata: { category: "bridge", year: 1883 }),
  Feature.new(label: "Times Square",       geometry: LLA.new(lat: 40.7580, lng: -73.9855, alt: 0),
              metadata: { category: "landmark" }),
]

# An area-based Feature: Central Park as a 500m-radius circle
central_park_area = Feature.new(
  label:    "Central Park Area",
  geometry: Areas::Circle.new(
    centroid: LLA.new(lat: 40.7829, lng: -73.9654, alt: 0),
    radius:   500
  ),
  metadata: { note: "approximate boundary" }
)

# --- 2. Compute a bounding box from Feature coordinates ---

points = landmarks.map { |f| f.geometry }
lats   = points.map(&:lat)
lngs   = points.map(&:lng)
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

# Set a default style (required by render, previously set as side effect of add_polygons)
map.style = GD::GIS::Style.default

# --- 6. Show Feature info using delegation ---

liberty = landmarks.first

puts "Landmarks relative to #{liberty.label}:"
puts "-" * 60

landmarks.each do |feature|
  utm = feature.geometry.to_utm

  puts <<~INFO
    #{feature.label} [#{feature.metadata[:category]}]
      LLA: #{feature.geometry.to_s(4)}
      UTM: #{utm.to_s(2)}
      Distance to #{liberty.label}: #{feature.distance_to(liberty).to_km}
      Bearing to #{liberty.label}:  #{feature.bearing_to(liberty)}

  INFO
end

# Distance from an area Feature to a point Feature
puts "#{central_park_area.label} -> #{liberty.label}: #{central_park_area.distance_to(liberty).to_km}"
puts

# --- 7. Render, draw markers/areas/labels, and save ---

output_path = File.join(__dir__, "nyc_landmarks.png")
map.render

img      = map.image
map_bbox = map.instance_variable_get(:@bbox)
zoom     = 13
FONT     = "/System/Library/Fonts/Supplemental/Arial Bold.ttf"

# Draw Central Park area circle (green outline + semi-transparent fill)
centroid = central_park_area.geometry.centroid
cx, cy   = GD::GIS::Geometry.project(centroid.lng, centroid.lat, map_bbox, zoom)

# Convert 500m radius to approximate pixels at this zoom/latitude
meters_per_pixel = 156543.03 * Math.cos(centroid.lat * Math::PI / 180.0) / (2 ** zoom)
park_radius_px   = (central_park_area.geometry.radius / meters_per_pixel).round

img.filled_circle(cx.round, cy.round, park_radius_px, [80, 255, 120, 80])
img.circle(cx.round, cy.round, park_radius_px, [100, 255, 150], thickness: 2)

# Draw landmark markers (red filled circles) and white labels
landmarks.each do |feature|
  pt     = feature.geometry
  px, py = GD::GIS::Geometry.project(pt.lng, pt.lat, map_bbox, zoom)
  x, y   = px.round, py.round

  img.filled_circle(x, y, 8, [255, 0, 0])
  img.circle(x, y, 8, [255, 255, 0], thickness: 2)
  img.text(feature.label, x: x + 12, y: y + 5,
                          font: FONT, size: 16, color: [255, 255, 255])
end

map.save(output_path)

puts "Map saved to #{output_path}"
