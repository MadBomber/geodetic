#!/usr/bin/env ruby

# Demonstration of GEOS operations visualized on a single LibGdGis map.
# Shows boolean operations, buffering, convex hull, simplification,
# nearest points, and prepared geometry — all rendered with distinct colors.
#
# Prerequisites:
#   gem install libgd-gis
#   brew install gd geos
#
# Usage:
#   ruby -Ilib examples/14_geos_map_rendering.rb
#   ruby -Ilib examples/14_geos_map_rendering.rb --dark

require_relative "../lib/geodetic"

include Geodetic
LLA     = Coordinate::LLA
Polygon = Areas::Polygon

unless Geos.available?
  abort "libgeos_c not found. Install with: brew install geos"
end

# --- Theme ---

def detect_macos_dark_mode
  `defaults read -g AppleInterfaceStyle 2>/dev/null`.strip == "Dark"
rescue
  false
end

DARK_MODE = if ARGV.include?("--dark") then true
            elsif ARGV.include?("--light") then false
            else detect_macos_dark_mode
            end

BASEMAP     = DARK_MODE ? :carto_dark : :carto_light
LABEL_COLOR = DARK_MODE ? [255, 255, 255] : [20, 20, 20]

# ─── Color palette ─────────────────────────────────────────────────────

# libgd alpha convention: 0 = opaque, 255 = fully transparent
# (ruby-libgd converts to GD's internal 0=opaque/127=transparent scale)
COLORS = {
  lower:          { fill: [70, 130, 255, 180],  stroke: [70, 130, 255, 40]   },  # blue
  midtown:        { fill: [255, 160, 40, 180],  stroke: [255, 160, 40, 40]   },  # orange
  overlap:        { fill: [255, 50, 50, 140],   stroke: [255, 50, 50, 0]     },  # red
  difference:     { fill: [180, 80, 220, 170],  stroke: [180, 80, 220, 40]   },  # purple
  buffer_point:   { fill: [0, 200, 120, 170],   stroke: [0, 200, 120, 30]    },  # green
  buffer_path:    { fill: [255, 220, 50, 180],  stroke: [255, 220, 50, 40]   },  # yellow
  hull:           { fill: [0, 220, 220, 245],   stroke: [0, 220, 220, 40]    },  # cyan — very transparent fill
  simplified:     { fill: [255, 100, 180, 170], stroke: [255, 100, 180, 40]  },  # pink
  nearest_line:   { stroke: [255, 255, 0, 0] },                                  # bright yellow (opaque)
  inside_point:   [0, 255, 100],                                                  # green dot
  outside_point:  [255, 60, 60],                                                  # red dot
  landmark_point: [255, 255, 255],                                                # white dot
}

# ─── 1. Build geometry ─────────────────────────────────────────────────

# Two overlapping polygons covering Manhattan
lower = Polygon.new(boundary: [
  LLA.new(lat: 40.700, lng: -74.020, alt: 0),
  LLA.new(lat: 40.700, lng: -73.970, alt: 0),
  LLA.new(lat: 40.730, lng: -73.970, alt: 0),
  LLA.new(lat: 40.730, lng: -74.020, alt: 0),
])

midtown = Polygon.new(boundary: [
  LLA.new(lat: 40.720, lng: -74.010, alt: 0),
  LLA.new(lat: 40.720, lng: -73.960, alt: 0),
  LLA.new(lat: 40.760, lng: -73.960, alt: 0),
  LLA.new(lat: 40.760, lng: -74.010, alt: 0),
])

# ─── 2. GEOS boolean operations ────────────────────────────────────────

puts "Computing GEOS operations..."

overlap    = Geos.intersection(lower, midtown)
diff_lower = Geos.difference(lower, midtown)

puts "  intersection:  #{overlap.class}"
puts "  difference:    #{diff_lower.class}"

# ─── 3. GEOS buffering ─────────────────────────────────────────────────

# Buffer a point (Empire State Building) — creates a circle-like polygon
empire = LLA.new(lat: 40.7484, lng: -73.9857, alt: 0)
point_buffer = Geos.buffer(empire, 0.008, quad_segs: 16)
puts "  point buffer:  #{point_buffer.class}"

# Buffer a path — creates a corridor
route = Path.new(coordinates: [
  LLA.new(lat: 40.7061, lng: -73.9969, alt: 0),   # Brooklyn Bridge
  LLA.new(lat: 40.7128, lng: -74.0060, alt: 0),   # One World Trade
  LLA.new(lat: 40.7484, lng: -73.9857, alt: 0),   # Empire State
  LLA.new(lat: 40.7580, lng: -73.9855, alt: 0),   # Times Square
])
path_buffer = Geos.buffer(route, 0.0015)
puts "  path buffer:   #{path_buffer.class}"

# ─── 4. Convex hull of scattered landmarks ─────────────────────────────

landmarks = {
  "Statue of Liberty" => LLA.new(lat: 40.6892, lng: -74.0445, alt: 0),
  "Brooklyn Bridge"   => LLA.new(lat: 40.7061, lng: -73.9969, alt: 0),
  "One World Trade"   => LLA.new(lat: 40.7128, lng: -74.0060, alt: 0),
  "Empire State"      => LLA.new(lat: 40.7484, lng: -73.9857, alt: 0),
  "Times Square"      => LLA.new(lat: 40.7580, lng: -73.9855, alt: 0),
  "Central Park S"    => LLA.new(lat: 40.7649, lng: -73.9727, alt: 0),
  "JFK Airport"       => LLA.new(lat: 40.6413, lng: -73.7781, alt: 0),
  "Coney Island"      => LLA.new(lat: 40.5749, lng: -73.9857, alt: 0),
}

landmark_path = Path.new(coordinates: landmarks.values)
hull = Geos.convex_hull(landmark_path)
puts "  convex hull:   #{hull.class} (from #{landmarks.size} landmarks)"

# ─── 5. Simplification ─────────────────────────────────────────────────

# Build a detailed 60-vertex circle
step = 360.0 / 60
detailed_circle = Polygon.new(boundary: 60.times.map { |i|
  angle = i * step * RAD_PER_DEG
  LLA.new(lat: 40.66 + 0.015 * Math.sin(angle),
          lng: -74.04 + 0.015 * Math.cos(angle), alt: 0)
})

simplified = Geos.simplify(detailed_circle, 0.004)
puts "  simplify:      60 vertices -> #{simplified.is_a?(Polygon) ? simplified.boundary.length - 1 : '?'} vertices"

# ─── 6. Nearest points between non-overlapping geometries ──────────────

brooklyn_poly = Polygon.new(boundary: [
  LLA.new(lat: 40.630, lng: -73.990, alt: 0),
  LLA.new(lat: 40.630, lng: -73.940, alt: 0),
  LLA.new(lat: 40.660, lng: -73.940, alt: 0),
  LLA.new(lat: 40.660, lng: -73.990, alt: 0),
])

nearest = Geos.nearest_points(lower, brooklyn_poly)
nearest_dist = nearest[0].distance_to(nearest[1])
puts "  nearest pts:   #{nearest_dist}"

# ─── 7. Prepared geometry — batch point-in-polygon ─────────────────────

srand(42)
test_points = 30.times.map do
  LLA.new(lat: 40.56 + rand * 0.22, lng: -74.06 + rand * 0.30, alt: 0)
end

prepared = Geos.prepare(hull)
inside_pts  = test_points.select { |pt| prepared.contains?(pt) }
outside_pts = test_points.reject { |pt| prepared.contains?(pt) }
prepared.release

puts "  prepared test: #{inside_pts.size} inside hull, #{outside_pts.size} outside"

# ─── 8. Compute bounding box for the map ───────────────────────────────

all_points = landmarks.values + test_points +
             [LLA.new(lat: 40.56, lng: -74.06, alt: 0),
              LLA.new(lat: 40.78, lng: -73.75, alt: 0)]
lats = all_points.map(&:lat)
lngs = all_points.map(&:lng)
padding = 0.02

bbox = Areas::BoundingBox.new(
  nw: LLA.new(lat: lats.max + padding, lng: lngs.min - padding, alt: 0),
  se: LLA.new(lat: lats.min - padding, lng: lngs.max + padding, alt: 0)
)

# ─── 9. Build the map and add all layers ───────────────────────────────

puts
puts "Building map..."

map = Map::LibGdGis.new(
  bbox:    bbox,
  zoom:    12,
  basemap: BASEMAP,
  width:   1400,
  height:  1000
)

# Layer 1: Convex hull (background — largest area)
if hull.is_a?(Polygon)
  hull.add_to_map(map, **COLORS[:hull])
end

# Layer 2: Input polygons
lower.add_to_map(map, **COLORS[:lower], width: 2)
midtown.add_to_map(map, **COLORS[:midtown], width: 2)

# Layer 3: Boolean intersection (overlap zone)
if overlap.is_a?(Polygon)
  overlap.add_to_map(map, **COLORS[:overlap], width: 2)
end

# Layer 4: Difference (lower minus midtown)
if diff_lower.is_a?(Polygon)
  diff_lower.add_to_map(map, **COLORS[:difference], width: 2)
end

# Layer 5: Point buffer (Empire State)
if point_buffer.is_a?(Polygon)
  point_buffer.add_to_map(map, **COLORS[:buffer_point], width: 2)
end

# Layer 6: Path buffer (route corridor)
if path_buffer.is_a?(Polygon)
  path_buffer.add_to_map(map, **COLORS[:buffer_path], width: 1)
end

# Layer 7: The route path itself
route.add_to_map(map, color: [255, 220, 50, 255], width: 2)

# Layer 8: Simplified polygon near Statue of Liberty
if simplified.is_a?(Polygon)
  simplified.add_to_map(map, **COLORS[:simplified], width: 2)
end

# Layer 9: Nearest-points connecting line
nearest_seg = Segment.new(nearest[0], nearest[1])
nearest_seg.add_to_map(map, color: COLORS[:nearest_line][:stroke], width: 2)

# Layer 10: Brooklyn polygon (for nearest-points context)
brooklyn_poly.add_to_map(map, fill: [100, 100, 100, 40], stroke: [150, 150, 150, 180], width: 1)

# ─── 10. Render and draw custom markers ────────────────────────────────

output_path = File.join(__dir__, "geos_showcase.png")
FONT = "/System/Library/Fonts/Supplemental/Arial Bold.ttf"

map.render(output_path) do |gd_map|
  img      = gd_map.image
  map_bbox = gd_map.instance_variable_get(:@bbox)
  zoom     = 12

  # Helper: project LLA to pixel coords
  project = ->(lla) {
    GD::GIS::Geometry.project(lla.lng, lla.lat, map_bbox, zoom).map(&:round)
  }

  # Draw landmark dots with labels
  landmarks.each do |name, pt|
    x, y = project.call(pt)
    img.filled_circle(x, y, 6, COLORS[:landmark_point])
    img.circle(x, y, 6, [0, 0, 0])
    img.text(name, x: x + 8, y: y + 4, font: FONT, size: 11, color: LABEL_COLOR)
  end

  # Draw test points (green inside hull, red outside)
  inside_pts.each do |pt|
    x, y = project.call(pt)
    img.filled_circle(x, y, 5, COLORS[:inside_point])
    img.circle(x, y, 5, [0, 80, 40])
  end

  outside_pts.each do |pt|
    x, y = project.call(pt)
    img.filled_circle(x, y, 5, COLORS[:outside_point])
    img.circle(x, y, 5, [150, 30, 30])
  end

  # Draw nearest-points markers
  nearest.each do |pt|
    x, y = project.call(pt)
    img.filled_circle(x, y, 7, [255, 255, 0])
    img.circle(x, y, 7, [0, 0, 0])
  end

  # Legend
  img.antialias = true
  lx, ly = 12, 12
  line_h = 20
  entries = [
    [[70, 130, 255],  "Lower Manhattan (input)"],
    [[255, 160, 40],  "Midtown (input)"],
    [[255, 50, 50],   "Intersection (overlap)"],
    [[180, 80, 220],  "Difference (lower - midtown)"],
    [[0, 200, 120],   "Point buffer (Empire State)"],
    [[255, 220, 50],  "Path buffer (route corridor)"],
    [[0, 220, 220],   "Convex hull (8 landmarks)"],
    [[255, 100, 180], "Simplified polygon (60->few vertices)"],
    [[255, 255, 0],   "Nearest points (Lower<->Brooklyn)"],
    [[100, 100, 100], "Brooklyn (nearest-points target)"],
    [[0, 255, 100],   "Test point: inside hull"],
    [[255, 60, 60],   "Test point: outside hull"],
  ]

  # Legend background
  legend_w = 310
  legend_h = entries.size * line_h + 10
  bg_color = DARK_MODE ? [30, 30, 30, 200] : [255, 255, 255, 200]
  img.filled_rectangle(lx, ly, lx + legend_w, ly + legend_h, bg_color)
  img.rectangle(lx, ly, lx + legend_w, ly + legend_h, [100, 100, 100])

  entries.each_with_index do |(color, label), i|
    y = ly + 6 + i * line_h
    img.filled_rectangle(lx + 6, y, lx + 20, y + 12, color)
    img.rectangle(lx + 6, y, lx + 20, y + 12, [60, 60, 60])
    img.text(label, x: lx + 26, y: y + 11, font: FONT, size: 10, color: LABEL_COLOR)
  end
end

puts "Map saved to #{output_path}"

puts <<~HEREDOC

  GEOS operations rendered:
    1. intersection(lower, midtown)      -> red overlay
    2. difference(lower, midtown)        -> purple area
    3. buffer(empire_state, 0.004)       -> green circle
    4. buffer(route, 0.0015)             -> yellow corridor
    5. convex_hull(8 landmarks)          -> cyan boundary
    6. simplify(60-vertex circle, 0.004) -> pink polygon
    7. nearest_points(lower, brooklyn)   -> yellow dots + line
    8. prepare(hull).contains?(30 pts)   -> green/red dots

HEREDOC
