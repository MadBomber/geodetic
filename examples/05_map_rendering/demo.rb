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

if ARGV.include?("-h") || ARGV.include?("--help")
  puts <<~HELP
    Usage: ./demo.rb [options]

    Options:
      --light              Use light basemap with dark labels
      --dark               Use dark basemap with light labels
                           Default: follows macOS appearance setting

      --central-park       Show Central Park polygon boundary (default)
      --no-central-park    Hide Central Park polygon boundary

      --icon-scale=N       Scale icons by factor N (default: 0.5)
                           Examples: --icon-scale=0.25, --icon-scale=1.0

      -h, --help           Show this help message
  HELP
  exit
end

require_relative "../../lib/geodetic"
require "gd/gis"

include Geodetic
LLA = Coordinate::LLA

# --- Theme detection: --light, --dark, or macOS system default ---

def detect_macos_dark_mode
  result = `defaults read -g AppleInterfaceStyle 2>/dev/null`.strip
  result == "Dark"
rescue
  false
end

DARK_MODE = if ARGV.include?("--dark")
              true
            elsif ARGV.include?("--light")
              false
            else
              detect_macos_dark_mode
            end

BASEMAP      = DARK_MODE ? :carto_dark  : :carto_light
LABEL_COLOR  = DARK_MODE ? [255, 255, 255] : [0, 0, 0]
ICON_BG      = DARK_MODE  # draw a white disc behind icons on dark basemaps
CENTRAL_PARK = !ARGV.include?("--no-central-park")  # --central-park is the default
ICON_SCALE   = (ARGV.find { |a| a.start_with?("--icon-scale=") }&.split("=", 2)&.last&.to_f) || 0.5

# --- 1. Define landmarks as Features with icon paths ---

ICONS_DIR = File.join(__dir__, "icons")

landmarks = [
  Feature.new(label: "Statue of Liberty", geometry: LLA.new(lat: 40.6892, lng: -74.0445, alt: 0),
              metadata: { category: "monument", year: 1886, icon: File.join(ICONS_DIR, "monument.png") }),
  Feature.new(label: "Empire State Bldg",  geometry: LLA.new(lat: 40.7484, lng: -73.9857, alt: 0),
              metadata: { category: "building", floors: 102, icon: File.join(ICONS_DIR, "building.png") }),
  Feature.new(label: "Central Park",       geometry: LLA.new(lat: 40.7829, lng: -73.9654, alt: 0),
              metadata: { category: "park", acres: 843, icon: File.join(ICONS_DIR, "park.png") }),
  Feature.new(label: "Brooklyn Bridge",    geometry: LLA.new(lat: 40.7061, lng: -73.9969, alt: 0),
              metadata: { category: "bridge", year: 1883, icon: File.join(ICONS_DIR, "bridge.png") }),
  Feature.new(label: "Times Square",       geometry: LLA.new(lat: 40.7580, lng: -73.9855, alt: 0),
              metadata: { category: "landmark", icon: File.join(ICONS_DIR, "landmark.png") }),
]

# An area-based Feature: Central Park as a polygon boundary
# Vertices trace the park perimeter (59th St to 110th St)
central_park_area = Feature.new(
  label:    "Central Park",
  geometry: Areas::Polygon.new(boundary: [
    # Vertices from OpenStreetMap data (way 427818536), simplified.
    # Central Park is a parallelogram tilted ~29° with Manhattan's grid.
    LLA.new(lat: 40.7679, lng: -73.9818, alt: 0),  # SW corner (Columbus Circle, 59th & CPW)
    LLA.new(lat: 40.7649, lng: -73.9727, alt: 0),  # SE corner (Grand Army Plaza, 59th & 5th Ave)
    LLA.new(lat: 40.7691, lng: -73.9697, alt: 0),  # E edge — 65th St
    LLA.new(lat: 40.7728, lng: -73.9672, alt: 0),  # E edge — 70th St
    LLA.new(lat: 40.7766, lng: -73.9648, alt: 0),  # E edge — 75th St
    LLA.new(lat: 40.7812, lng: -73.9618, alt: 0),  # E edge — 81st St (Met Museum)
    LLA.new(lat: 40.7855, lng: -73.9592, alt: 0),  # E edge — 86th St
    LLA.new(lat: 40.7903, lng: -73.9561, alt: 0),  # E edge — 92nd St
    LLA.new(lat: 40.7950, lng: -73.9531, alt: 0),  # E edge — 97th St
    LLA.new(lat: 40.7994, lng: -73.9500, alt: 0),  # E edge — 108th St
    LLA.new(lat: 40.8003, lng: -73.9494, alt: 0),  # NE corner (110th & 5th Ave)
    LLA.new(lat: 40.8013, lng: -73.9580, alt: 0),  # N edge
    LLA.new(lat: 40.8008, lng: -73.9585, alt: 0),  # NW corner (110th & CPW)
    LLA.new(lat: 40.7962, lng: -73.9614, alt: 0),  # W edge — 103rd St
    LLA.new(lat: 40.7915, lng: -73.9648, alt: 0),  # W edge — 93rd St
    LLA.new(lat: 40.7863, lng: -73.9679, alt: 0),  # W edge — 86th St
    LLA.new(lat: 40.7815, lng: -73.9706, alt: 0),  # W edge — 79th St
    LLA.new(lat: 40.7769, lng: -73.9731, alt: 0),  # W edge — 73rd St
    LLA.new(lat: 40.7726, lng: -73.9755, alt: 0),  # W edge — 68th St
    LLA.new(lat: 40.7698, lng: -73.9772, alt: 0),  # W edge — 64th St
  ]),
  metadata: { note: "simplified boundary from OpenStreetMap way 427818536" }
)

# --- 2. Compute a bounding box from Feature coordinates ---

all_points = landmarks.map { |f| f.geometry }
all_points += central_park_area.geometry.boundary if CENTRAL_PARK
lats = all_points.map(&:lat)
lngs = all_points.map(&:lng)
padding = 0.03

bbox = [
  lngs.min - padding,  # west
  lats.min - padding,  # south
  lngs.max + padding,  # east
  lats.max + padding   # north
]

# --- 3. Create the map ---

ZOOM = 12

map = GD::GIS::Map.new(
  bbox:    bbox,
  zoom:    ZOOM,
  basemap: BASEMAP,
  width:   1024,
  height:  768
)

# --- 4. Optionally draw Central Park polygon on the map ---

if CENTRAL_PARK
  park_coords = central_park_area.geometry.boundary.map { |pt| [pt.lng, pt.lat] }

  map.add_polygons(
    [[park_coords]],  # polygons > rings > [lng, lat] points
    fill:   [80, 255, 120, 60],
    stroke: [50, 200, 80, 255],
    width:  2
  )
end

# Style must be set (add_polygons sets it as a side effect, but just in case)
map.style ||= GD::GIS::Style.default

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
zoom     = ZOOM
FONT     = "/System/Library/Fonts/Supplemental/Arial Bold.ttf"

# Draw landmark icons and labels
landmarks.each do |feature|
  pt     = feature.geometry
  px, py = GD::GIS::Geometry.project(pt.lng, pt.lat, map_bbox, zoom)
  x, y   = px.round, py.round

  # Load and scale the icon
  icon = GD::Image.open(feature.metadata[:icon])
  icon.alpha_blending = true
  icon.save_alpha = true
  iw = (icon.width  * ICON_SCALE).round
  ih = (icon.height * ICON_SCALE).round
  scaled = icon.scale(iw, ih)
  scaled.alpha_blending = true
  scaled.save_alpha = true

  # On dark basemaps, add a white disc so black icons are visible
  if ICON_BG
    radius = (iw / 2 * 1.3).round
    img.filled_circle(x, y, radius, [255, 255, 255])
  end

  img.copy(scaled, x - iw / 2, y - ih / 2, 0, 0, iw, ih)

  # Label to the right of the icon
  img.text(feature.label, x: x + iw / 2 + 6, y: y + 5,
                          font: FONT, size: 16, color: LABEL_COLOR)
end

# --- 8. Draw bearing arrows ---

def draw_bearing_arrow(img, from_feature, to_feature, map_bbox, zoom, color, font)
  bearing = from_feature.bearing_to(to_feature)

  x1, y1 = GD::GIS::Geometry.project(from_feature.geometry.lng, from_feature.geometry.lat, map_bbox, zoom).map(&:round)
  x2, y2 = GD::GIS::Geometry.project(to_feature.geometry.lng, to_feature.geometry.lat, map_bbox, zoom).map(&:round)

  # Line (doubled for thickness)
  img.line(x1, y1, x2, y2, color)
  img.line(x1 + 1, y1, x2 + 1, y2, color)

  # Arrowhead at destination
  dx, dy = (x2 - x1).to_f, (y2 - y1).to_f
  len = Math.sqrt(dx * dx + dy * dy)
  ux, uy = dx / len, dy / len

  tip_x  = x2 - (ux * 20).round
  tip_y  = y2 - (uy * 20).round
  base_x = tip_x - (ux * 14).round
  base_y = tip_y - (uy * 14).round
  px, py = -uy, ux
  p1x = base_x + (px * 7).round
  p1y = base_y + (py * 7).round
  p2x = base_x - (px * 7).round
  p2y = base_y - (py * 7).round
  img.filled_polygon([[tip_x, tip_y], [p1x, p1y], [p2x, p2y]], color)

  # Label at midpoint
  mid_x = (x1 + x2) / 2
  mid_y = (y1 + y2) / 2
  img.text("#{bearing.degrees.round(1)}\u00B0", x: mid_x + 8, y: mid_y + 5,
                                                 font: font, size: 14, color: color)
end

img.antialias = true
brooklyn = landmarks.find { |f| f.label == "Brooklyn Bridge" }
liberty  = landmarks.find { |f| f.label == "Statue of Liberty" }
empire   = landmarks.find { |f| f.label == "Empire State Bldg" }

arrow_color = DARK_MODE ? [255, 100, 100] : [200, 30, 30]

draw_bearing_arrow(img, brooklyn, liberty, map_bbox, zoom, arrow_color, FONT)
draw_bearing_arrow(img, brooklyn, empire,  map_bbox, zoom, arrow_color, FONT)

map.save(output_path)

puts "Map saved to #{output_path}"
