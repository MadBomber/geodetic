# Geodetic

> [!INFO]
> See the [CHANGELOG](CHANGELOG.md) for the latest changes. The [examples directory has runnable demo apps](examples/) that show-off the various capabilities of the Geodetic library.

<br>
<table>
<tr>
<td width="50%" align="center" valign="top">
<img src="docs/assets/images/geodetic.jpg" alt="Geodetic"><br>
<em>"Convert coordinates. Map the world."</em>
</td>
<td width="50%" valign="top">
<strong>Key Features</strong><br>

- <strong>18 Coordinate Systems</strong> - LLA, ECEF, UTM, ENU, NED, MGRS, USNG, Web Mercator, UPS, State Plane, BNG, GH36, GH, HAM, OLC, GEOREF, GARS, H3<br>
- <strong>Full Bidirectional Conversions</strong> - Every system converts to and from every other system<br>
- <strong>Distance Calculations</strong> - Vincenty great-circle and straight-line with unit tracking<br>
- <strong>Bearing Calculations</strong> - Forward azimuth, back azimuth, compass directions, elevation angles<br>
- <strong>Geoid Height Support</strong> - EGM96, EGM2008, GEOID18, GEOID12B models<br>
- <strong>Geographic Areas</strong> - Circle, Polygon, BoundingBox, Triangle, Rectangle, Pentagon, Hexagon, Octagon<br>
- <strong>Segments</strong> - Directed two-point line segments with projection, intersection, and interpolation<br>
- <strong>Paths</strong> - Directed coordinate sequences with navigation, interpolation, closest approach, intersection, and area conversion<br>
- <strong>Features</strong> - Named geometry wrapper with metadata and delegated distance/bearing<br>
- <strong>Vectors</strong> - Geodetic displacement (distance + bearing) with full arithmetic and Vincenty direct<br>
- <strong>Geodetic Arithmetic</strong> - Compose geometry with operators: P1 + P2 → Segment, + P3 → Path, + Distance → Circle, * Vector → translate<br>
- <strong>GeoJSON Export</strong> - Build FeatureCollections from any mix of objects and save to file<br>
- <strong>Validated Setters</strong> - Type coercion and range validation on all coordinate attributes<br>
- <strong>Serialization</strong> - to_s(precision), to_a, from_string, from_array, DMS format<br>
- <strong>Multiple Datums</strong> - WGS84, Clarke 1866, GRS 1980, Airy 1830, and more<br>
- <strong>Immutable Value Types</strong> - Distance and Bearing with arithmetic and comparison
</td>
</tr>
</table>

<p>Geodetic enables precise conversion between geodetic coordinate systems in Ruby. All 18 coordinate systems support complete bidirectional conversions with high precision. Review the <a href="https://madbomber.github.io/geodetic/">full documentation website</a> and explore the <a href="examples/">runnable examples</a>.</p>

## Installation

Add to your Gemfile:

```ruby
gem "geodetic"
```

Or install directly:

```bash
gem install geodetic
```

### Optional: H3 Hexagonal Index

The H3 coordinate system requires Uber's [H3 C library](https://h3geo.org/) installed on your system. Without it, all other 17 coordinate systems work normally; H3 operations will raise a helpful error.

```bash
# macOS
brew install h3

# Linux (build from source)
# See https://h3geo.org/docs/installation
```

You can also set the `LIBH3_PATH` environment variable to point to a custom `libh3` location.

## Usage

### Basic Coordinate Creation

All constructors use keyword arguments:

```ruby
require "geodetic"

include Geodetic

# lng:, lon:, and long: are all accepted for longitude
lla = Coordinate::LLA.new(lat: 47.6205, lng: -122.3493, alt: 184.0)
lla = Coordinate::LLA.new(lat: 47.6205, lon: -122.3493, alt: 184.0)
lla = Coordinate::LLA.new(lat: 47.6205, long: -122.3493, alt: 184.0)
# Readers: lla.lng, lla.lon, lla.long, lla.longitude all return the same value
ecef = Coordinate::ECEF.new(x: -2304643.57, y: -3638650.07, z: 4688674.43)
utm = Coordinate::UTM.new(easting: 548894.0, northing: 5272748.0, altitude: 184.0, zone: 10, hemisphere: "N")
enu = Coordinate::ENU.new(e: 100.0, n: 200.0, u: 50.0)
ned = Coordinate::NED.new(n: 200.0, e: 100.0, d: -50.0)
```

### GCS Shorthand

For convenience, you can define a short alias in your application:

```ruby
require "geodetic"

GCS = Geodetic::Coordinate

seattle = Geodetic::Coordinate::LLA.new(lat: 47.6205, lng: -122.3493, alt: 184.0)
ecef = Geodetic::Coordinate::ECEF.new(x: -2304643.57, y: -3638650.07, z: 4688674.43)
```

### Discovering Coordinate Systems

List all available coordinate systems at runtime:

```ruby
Geodetic::Coordinate.systems
# => [Geodetic::Coordinate::LLA, Geodetic::Coordinate::ECEF, Geodetic::Coordinate::UTM, ...]

# Get short names
Geodetic::Coordinate.systems.map { |c| c.name.split('::').last }
# => ["LLA", "ECEF", "UTM", "ENU", "NED", "MGRS", "USNG", "WebMercator",
#     "UPS", "StatePlane", "BNG", "GH36", "GH", "HAM", "OLC", "GEOREF", "GARS", "H3"]
```

### Coordinate Conversions

Every coordinate system can convert to and from every other system:

```ruby
lla = Coordinate::LLA.new(lat: 47.6205, lng: -122.3493, alt: 184.0)

# LLA to other systems
ecef = lla.to_ecef
utm  = lla.to_utm
wm   = Coordinate::WebMercator.from_lla(lla)
mgrs = Coordinate::MGRS.from_lla(lla)

# Convert back
lla_roundtrip = ecef.to_lla

# Local coordinate systems require a reference point
reference = Coordinate::LLA.new(lat: 47.62, lng: -122.35, alt: 0.0)
enu = lla.to_enu(reference)
ned = lla.to_ned(reference)
```

### Serialization

All coordinate classes support `to_s`, `to_a`, `from_string`, and `from_array`. The `to_s` method accepts an optional precision parameter controlling the number of decimal places:

```ruby
lla = Coordinate::LLA.new(lat: 47.6205, lng: -122.3493, alt: 184.0)

lla.to_s                            # => "47.620500, -122.349300, 184.00"
lla.to_s(3)                         # => "47.620, -122.349, 184.00"
lla.to_s(0)                         # => "48, -122, 184"
lla.to_a                            # => [47.6205, -122.3493, 184.0]

Coordinate::LLA.from_string("47.6205, -122.3493, 184.0")
Coordinate::LLA.from_array([47.6205, -122.3493, 184.0])
```

Default precisions by class: LLA=6, Bearing=4, all others=2. Passing `0` returns integers.

### Validated Setters

All coordinate classes provide setter methods with type coercion and validation:

```ruby
lla = Coordinate::LLA.new(lat: 47.0, lng: -122.0, alt: 100.0)
lla.lat = 48.0                     # validates -90..90
lla.lng = -121.0                   # validates -180..180
lla.alt = 200.0                    # no range constraint
lla.lat = 91.0                     # => ArgumentError

utm = Coordinate::UTM.new(easting: 500000.0, northing: 5000000.0, zone: 10, hemisphere: 'N')
utm.zone = 15                      # validates 1..60
utm.hemisphere = 'S'               # validates 'N' or 'S'
utm.easting = -1.0                 # => ArgumentError

# UPS cross-validates hemisphere/zone combinations
ups = Coordinate::UPS.new(hemisphere: 'N', zone: 'Y')
ups.zone = 'Z'                     # valid for hemisphere 'N'
ups.zone = 'A'                     # => ArgumentError (rolls back)

# BNG auto-updates grid_ref when easting/northing change
bng = Coordinate::BNG.new(easting: 530000, northing: 180000)
bng.easting = 430000               # grid_ref automatically recalculated
```

ECEF, ENU, NED, and WebMercator setters coerce to float with no range constraints. MGRS, USNG, GH36, GH, HAM, OLC, Distance, and Bearing are immutable.

### DMS (Degrees, Minutes, Seconds)

```ruby
lla = Coordinate::LLA.new(lat: 37.7749, lng: -122.4192, alt: 15.0)
lla.to_dms    # => "37° 46' 29.64\" N, 122° 25' 9.12\" W, 15.00 m"

Coordinate::LLA.from_dms("37° 46' 29.64\" N, 122° 25' 9.12\" W, 15.00 m")
```

### String-Based Coordinate Systems

MGRS and USNG use string representations:

```ruby
mgrs = Coordinate::MGRS.new(mgrs_string: "18SUJ2337006519")
mgrs = Coordinate::MGRS.from_string("18SUJ2337006519")
mgrs.to_s    # => "18SUJ2337006519"

usng = Coordinate::USNG.new(usng_string: "18T WL 12345 67890")
usng = Coordinate::USNG.from_string("18T WL 12345 67890")
usng.to_s    # => "18T WL 12345 67890"
```

### Distance Calculations

Universal distance methods work across all coordinate types and return `Distance` objects with unit tracking and conversion.

**Instance method `distance_to`** — Vincenty great-circle distance:

```ruby
seattle = Geodetic::Coordinate::LLA.new(lat: 47.6205, lng: -122.3493, alt: 0.0)
portland = Geodetic::Coordinate::LLA.new(lat: 45.5152, lng: -122.6784, alt: 0.0)
sf = Geodetic::Coordinate::LLA.new(lat: 37.7749, lng: -122.4194, alt: 0.0)

d = seattle.distance_to(portland)         # => Distance (meters)
d.meters                                  # => 235385.71
d.to_km.to_f                             # => 235.39
d.to_mi.to_f                             # => 146.26

seattle.distance_to(portland, sf)         # => [Distance, Distance] (radial)
seattle.distance_to([portland, sf])       # => [Distance, Distance] (radial)
```

**Class method `distance_between`** — consecutive chain distances:

```ruby
Geodetic::Coordinate.distance_between(seattle, portland)        # => Distance
Geodetic::Coordinate.distance_between(seattle, portland, sf)    # => [Distance, Distance] (chain)
Geodetic::Coordinate.distance_between([seattle, portland, sf])  # => [Distance, Distance] (chain)
```

**Straight-line (ECEF Euclidean) versions:**

```ruby
seattle.straight_line_distance_to(portland)              # => Distance
Geodetic::Coordinate.straight_line_distance_between(seattle, portland)    # => Distance
```

**Cross-system distances** — works between any coordinate types:

```ruby
utm = seattle.to_utm
mgrs = Geodetic::Coordinate::MGRS.from_lla(portland)
utm.distance_to(mgrs)    # => Distance
```

> **Note:** ENU and NED are relative coordinate systems and must be converted to an absolute system before distance and bearing calculations. They retain `local_bearing_to`, `horizontal_distance_to`, and other local methods for tangent-plane operations.

### Bearing Calculations

Universal bearing methods work across all coordinate types and return `Bearing` objects.

**Instance method `bearing_to`** — great-circle forward azimuth:

```ruby
seattle = Geodetic::Coordinate::LLA.new(lat: 47.6205, lng: -122.3493, alt: 0.0)
portland = Geodetic::Coordinate::LLA.new(lat: 45.5152, lng: -122.6784, alt: 0.0)

b = seattle.bearing_to(portland)   # => Bearing
b.degrees                          # => 186.25
b.to_radians                      # => 3.25...
b.to_compass                      # => "S"
b.to_compass(points: 8)           # => "S"
b.reverse                         # => Bearing (back azimuth)
b.to_s                            # => "186.2539°"
```

**Instance method `elevation_to`** — vertical look angle:

```ruby
a = Geodetic::Coordinate::LLA.new(lat: 47.62, lng: -122.35, alt: 0.0)
b = Geodetic::Coordinate::LLA.new(lat: 47.62, lng: -122.35, alt: 5000.0)

a.elevation_to(b)   # => 89.9... (degrees, nearly straight up)
```

**Class method `bearing_between`** — consecutive chain bearings:

```ruby
Geodetic::Coordinate.bearing_between(seattle, portland)        # => Bearing
Geodetic::Coordinate.bearing_between(seattle, portland, sf)    # => [Bearing, Bearing] (chain)
```

**Cross-system bearings** — works between any coordinate types:

```ruby
utm = seattle.to_utm
mgrs = Geodetic::Coordinate::MGRS.from_lla(portland)
utm.bearing_to(mgrs)    # => Bearing
```

### Bearing Class

`Bearing` wraps an azimuth angle (0-360°) with compass and radian conversions.

```ruby
b = Geodetic::Bearing.new(225)
b.degrees                   # => 225.0
b.to_radians                # => 3.926...
b.reverse                   # => Bearing (45°)
b.to_compass(points: 4)     # => "W"
b.to_compass(points: 8)     # => "SW"
b.to_compass(points: 16)    # => "SW"
b.to_s                      # => "225.0000°"
b.to_s(1)                   # => "225.0°"
b.to_s(0)                   # => "225°"

# Arithmetic
b + 10                       # => Bearing (235°)
b - 10                       # => Bearing (215°)
Bearing.new(90) - Bearing.new(45)  # => 45.0 (Float, angular difference)
```

### Distance Class

`Distance` tracks values internally in meters with a configurable display unit. All distance methods return `Distance` objects.

**Construction:**

```ruby
d = Geodetic::Distance.new(1000)          # 1000 meters
d = Geodetic::Distance.km(5)             # 5 kilometers
d = Geodetic::Distance.mi(3)             # 3 miles
d = Geodetic::Distance.ft(5280)          # 5280 feet
d = Geodetic::Distance.nmi(1)            # 1 nautical mile
```

**Unit conversions** — return a new `Distance` with the same meters, different display unit:

```ruby
d = Geodetic::Distance.new(1609.344)
d.to_km.to_f     # => 1.609344
d.to_mi.to_f     # => 1.0
d.to_ft.to_f     # => 5280.0
d.to_nmi.to_f    # => 0.869...
d.meters          # => 1609.344 (always available)
```

**Display and formatting:**

```ruby
d = Geodetic::Distance.new(5000).to_km
d.to_f     # => 5.0 (in display unit)
d.to_i     # => 5
d.to_s     # => "5.00 km"
d.to_s(1)  # => "5.0 km"
d.to_s(0)  # => "5 km"
d.inspect  # => "#<Geodetic::Distance 5.00 km (5000.0 m)>"
```

**Arithmetic** — results always in meters:

```ruby
d1 = Geodetic::Distance.km(5)
d2 = Geodetic::Distance.mi(3)

(d1 + d2).meters      # => 9828.032 (5km + 3mi in meters)
(d1 - d2).meters      # => 171.968
(d1 * 2).meters       # => 10000.0
(d1 / 2).meters       # => 2500.0
d1 / d2               # => 1.034... (Float ratio)

# Numeric constants use the display unit
d = Geodetic::Distance.new(5000).to_km   # 5 km
(d + 3).meters        # => 8000.0 (3 km added)
```

**Comparison:**

```ruby
Geodetic::Distance.km(1) == Geodetic::Distance.new(1000)  # => true
Geodetic::Distance.km(5) > Geodetic::Distance.mi(2)       # => true
```

**Supported units:** meters (m), kilometers (km), centimeters (cm), millimeters (mm), miles (mi), yards (yd), feet (ft), inches (in), nautical_miles (nmi)

### Datums

```ruby
wgs84 = Datum.new(name: "WGS84")
wgs84.a     # => 6378137.0 (semi-major axis)
wgs84.e2    # => 0.00669437999014132 (eccentricity squared)

# Use a different datum for conversions
nad27 = Datum.new(name: "CLARKE_1866")
ecef = lla.to_ecef(nad27)

# List available datums
Datum.list
```

### Geoid Height

```ruby
geoid = GeoidHeight.new(geoid_model: "EGM2008")

# Get geoid height at a location
geoid.geoid_height_at(47.6205, -122.3493)

# Convert between height datums
geoid.ellipsoidal_to_orthometric(47.6205, -122.3493, 184.0)
geoid.orthometric_to_ellipsoidal(47.6205, -122.3493, 150.0)

# Convert between vertical datums
geoid.convert_vertical_datum(47.6205, -122.3493, 184.0, "HAE", "NAVD88")
```

The `GeoidHeightSupport` module is mixed into LLA for convenience:

```ruby
lla = Coordinate::LLA.new(lat: 47.6205, lng: -122.3493, alt: 184.0)
lla.geoid_height              # => geoid undulation in meters
lla.orthometric_height        # => height above mean sea level
```

### Geohash-36 (GH36)

A spatial hashing coordinate that encodes lat/lng into a compact, URL-friendly string:

```ruby
# From a geohash string
gh36 = Coordinate::GH36.new("bdrdC26BqH")

# From any coordinate
gh36 = Coordinate::GH36.new(lla)
gh36 = lla.to_gh36(precision: 8)

# Decode back to LLA
lla = gh36.to_lla

# Neighbor cells
gh36.neighbors  # => { N: GH36, S: GH36, E: GH36, W: GH36, NE: ..., NW: ..., SE: ..., SW: ... }

# Bounding rectangle of the geohash cell
area = gh36.to_area    # => Areas::BoundingBox
area.includes?(gh36.to_lla)  # => true

# Precision info
gh36.precision              # => 10
gh36.precision_in_meters    # => { lat: 0.31, lng: 0.62 }
```

### Geohash (GH)

The standard Geohash (base-32) algorithm by Gustavo Niemeyer, widely supported by Elasticsearch, Redis, PostGIS, and geocoding services:

```ruby
# From a geohash string
gh = Coordinate::GH.new("dr5ru7")

# From any coordinate
gh = Coordinate::GH.new(lla)
gh = lla.to_gh(precision: 8)

# Decode back to LLA
lla = gh.to_lla

# Neighbor cells
gh.neighbors  # => { N: GH, S: GH, E: GH, W: GH, NE: ..., NW: ..., SE: ..., SW: ... }

# Bounding rectangle of the geohash cell
area = gh.to_area    # => Areas::BoundingBox
area.includes?(gh.to_lla)  # => true

# Precision info
gh.precision              # => 6
gh.precision_in_meters    # => { lat: 610.98, lng: 1221.97 }
```

### Maidenhead Locator (HAM)

The Maidenhead Locator System used worldwide in amateur radio for grid square identification:

```ruby
# From a Maidenhead locator string
ham = Coordinate::HAM.new("FN31pr")

# From any coordinate
ham = Coordinate::HAM.new(lla)
ham = lla.to_ham(precision: 8)

# Decode back to LLA
lla = ham.to_lla

# Neighbor cells
ham.neighbors  # => { N: HAM, S: HAM, E: HAM, W: HAM, NE: ..., NW: ..., SE: ..., SW: ... }

# Bounding rectangle of the grid square
area = ham.to_area    # => Areas::BoundingBox
area.includes?(ham.to_lla)  # => true

# Precision info
ham.precision              # => 6
ham.precision_in_meters    # => { lat: 4631.0, lng: 9260.0 }
```

### Open Location Code / Plus Codes (OLC)

Google's open system for encoding locations into short, URL-friendly codes:

```ruby
# From a plus code string
olc = Coordinate::OLC.new("849VCWC8+R9")

# From any coordinate
olc = Coordinate::OLC.new(lla)
olc = lla.to_olc(precision: 11)

# Decode back to LLA
lla = olc.to_lla

# Neighbor cells
olc.neighbors  # => { N: OLC, S: OLC, E: OLC, W: OLC, NE: ..., NW: ..., SE: ..., SW: ... }

# Bounding rectangle of the plus code cell
area = olc.to_area    # => Areas::BoundingBox
area.includes?(olc.to_lla)  # => true

# Precision info
olc.precision              # => 10
olc.precision_in_meters    # => { lat: 13.9, lng: 13.9 }
```

### Geographic Areas

```ruby
# Circle area
center = Coordinate::LLA.new(lat: 47.6205, lng: -122.3493, alt: 0.0)
circle = Areas::Circle.new(centroid: center, radius: 1000.0)  # 1km radius

# Polygon area
points = [
  Coordinate::LLA.new(lat: 47.60, lng: -122.35, alt: 0.0),
  Coordinate::LLA.new(lat: 47.63, lng: -122.35, alt: 0.0),
  Coordinate::LLA.new(lat: 47.63, lng: -122.33, alt: 0.0),
  Coordinate::LLA.new(lat: 47.60, lng: -122.33, alt: 0.0),
]
polygon = Areas::Polygon.new(boundary: points)
polygon.centroid    # => computed centroid as LLA

# BoundingBox area (accepts any coordinate type)
nw = Coordinate::LLA.new(lat: 41.0, lng: -75.0)
se = Coordinate::LLA.new(lat: 40.0, lng: -74.0)
rect = Areas::BoundingBox.new(nw: nw, se: se)
rect.centroid       # => LLA at center
rect.ne             # => computed NE corner
rect.sw             # => computed SW corner
rect.includes?(point)  # => true/false
```

### Segments

`Segment` represents a directed line segment between two points. It provides the geometric primitives that `Path` and `Polygon` build on.

```ruby
a = Coordinate::LLA.new(lat: 40.7484, lng: -73.9857, alt: 0)
b = Coordinate::LLA.new(lat: 40.7580, lng: -73.9855, alt: 0)

seg = Segment.new(a, b)

# Properties (lazily computed, cached)
seg.length           # => Distance
seg.distance         # => Distance (alias for length)
seg.bearing          # => Bearing
seg.midpoint         # => LLA at halfway point

# Projection — closest point on segment to a target
foot, dist_m = seg.project(target_point)

# Interpolation — point at fraction along segment
seg.interpolate(0.25)  # => LLA at quarter-way

# Membership
seg.includes?(a)              # => true  (vertex check only)
seg.includes?(seg.midpoint)   # => false
seg.contains?(seg.midpoint)   # => true  (on-segment check)

# Intersection
seg.intersects?(other_seg)  # => true/false

# Conversion
seg.reverse    # => Segment with swapped endpoints
seg.to_path    # => two-point Path
seg.to_a       # => [start_point, end_point]
```

### Paths

`Path` is a directed, ordered sequence of unique coordinates representing routes, trails, or boundaries.

```ruby
route = Path.new(coordinates: [battery_park, wall_street, brooklyn_bridge, city_hall])

# Navigation
route.first                      # => starting waypoint
route.next(wall_street)          # => brooklyn_bridge
route.total_distance.to_km       # => "3.42 km"

# Build incrementally
trail = Path.new
trail << start << middle << finish
trail >> new_start               # prepend

# Combine paths
combined = downtown + uptown     # concatenate
trimmed  = combined - detour     # remove coordinates

# Closest approach (geometric projection, not just waypoints)
route.closest_coordinate_to(off_path_point)
route.distance_to(target)
route.closest_points_to(other_path)  # path-to-path

# Spatial operations
sub = route.between(a, b)        # extract subpath
left, right = route.split_at(c)  # split at waypoint
route.at_distance(Distance.km(2)) # interpolate along path
route.bounds                     # => Areas::BoundingBox
route.to_polygon                 # close into polygon
route.intersects?(other_path)    # crossing detection
route.contains?(point)           # on-segment check

# Enumerable
route.map { |c| c.lat }
route.select { |c| c.lat > 40.72 }
```

### Features

`Feature` wraps a geometry (any coordinate, area, or path) with a label and a metadata hash. It delegates `distance_to` and `bearing_to` to its geometry, using the centroid for area geometries.

```ruby
liberty = Feature.new(
  label:    "Statue of Liberty",
  geometry: Coordinate::LLA.new(lat: 40.6892, lng: -74.0445, alt: 0),
  metadata: { category: "monument", year: 1886 }
)

empire = Feature.new(
  label:    "Empire State Building",
  geometry: Coordinate::LLA.new(lat: 40.7484, lng: -73.9857, alt: 0),
  metadata: { category: "building", floors: 102 }
)

liberty.distance_to(empire).to_km   # => "8.24 km"
liberty.bearing_to(empire).degrees  # => 36.95

# Area geometries use the centroid for distance/bearing
park = Feature.new(
  label:    "Central Park",
  geometry: Areas::Polygon.new(boundary: [...])
)
park.distance_to(liberty).to_km     # => "12.47 km"
```

All three attributes (`label`, `geometry`, `metadata`) are mutable.

### Vectors

`Vector` pairs a `Distance` (magnitude) with a `Bearing` (direction) to represent a geodetic displacement. It solves the Vincenty direct problem to compute destination points.

```ruby
v = Geodetic::Vector.new(distance: 10_000, bearing: 90.0)
v = Geodetic::Vector.new(distance: Distance.km(10), bearing: Bearing.new(90))

v.north          # => north component in meters
v.east           # => east component in meters
v.magnitude      # => distance in meters
v.reverse        # => same distance, opposite bearing
v.normalize      # => unit vector (1 meter)
```

**Vector arithmetic:**

```ruby
v1 + v2          # => Vector (component-wise addition)
v1 - v2          # => Vector (component-wise subtraction)
v * 3            # => Vector (scale distance)
v / 2            # => Vector (scale distance)
-v               # => Vector (reverse bearing)
v.dot(v2)        # => Float (dot product)
v.cross(v2)      # => Float (2D cross product)
```

**Factory methods:**

```ruby
Vector.from_components(north: 1000, east: 500)
Vector.from_segment(segment)
segment.to_vector
```

### Geodetic Arithmetic

Operators build geometry from coordinates, vectors, and distances:

```ruby
# Building geometry with +
p1 + p2                    # => Segment
p1 + p2 + p3              # => Path
p1 + segment              # => Path
segment + p3              # => Path
segment + segment          # => Path
p1 + distance              # => Circle
p1 + vector                # => Segment (to destination)
segment + vector           # => Path (extend from endpoint)
vector + segment           # => Path (prepend via reverse)
path + vector              # => Path (extend from last point)
vector + coordinate        # => Segment
distance + coordinate      # => Circle

# Translation with * or .translate
p1 * vector                # => Coordinate (translated point)
segment * vector           # => Segment (translated endpoints)
path * vector              # => Path (translated waypoints)
circle * vector            # => Circle (translated centroid)
polygon * vector           # => Polygon (translated vertices)
```

### Corridors

Convert a path into a polygon corridor of a given width:

```ruby
route = seattle + portland + sf
corridor = route.to_corridor(width: 1000)        # 1km wide polygon
corridor = route.to_corridor(width: Distance.km(1))
```

### GeoJSON Export

`GeoJSON` builds a GeoJSON FeatureCollection from any mix of Geodetic objects and writes it to a file.

```ruby
gj = Geodetic::GeoJSON.new
gj << seattle
gj << [portland, sf, la]
gj << Feature.new(label: "Route", geometry: route, metadata: { mode: "driving" })
gj << Areas::Circle.new(centroid: seattle, radius: 10_000)

gj.size        # => 6
gj.to_h        # => {"type" => "FeatureCollection", "features" => [...]}
gj.to_json     # => compact JSON string
gj.save("map.geojson", pretty: true)
```

Every geometry type has a `to_geojson` method returning a GeoJSON-compatible Hash:

```ruby
seattle.to_geojson                        # => {"type" => "Point", ...}
Segment.new(seattle, portland).to_geojson # => {"type" => "LineString", ...}
route.to_geojson                          # => {"type" => "LineString", ...}
route.to_geojson(as: :polygon)            # => {"type" => "Polygon", ...}
polygon.to_geojson                        # => {"type" => "Polygon", ...}
circle.to_geojson(segments: 64)           # => {"type" => "Polygon", ...} (64-gon)
bbox.to_geojson                           # => {"type" => "Polygon", ...}
feature.to_geojson                        # => {"type" => "Feature", ...}
```

Features carry their `label` as `"name"` and `metadata` as `properties` in the GeoJSON output. Non-Feature objects added to the collection are auto-wrapped as Features with empty properties.

### Web Mercator Tile Coordinates

```ruby
wm = Coordinate::WebMercator.from_lla(lla)
wm.to_tile_coordinates(15)     # => [x_tile, y_tile, zoom]
wm.to_pixel_coordinates(15)    # => [x_pixel, y_pixel, zoom]

Coordinate::WebMercator.from_tile_coordinates(5241, 11438, 15)
```

## Available Datums

Airy 1830, Modified Airy, Australian National, Bessel 1841, Clarke 1866, Clarke 1880, Everest (India 1830), Everest (Brunei & E.Malaysia), Everest (W.Malaysia & Singapore), GRS 1980, Helmert 1906, Hough 1960, International 1924, South American 1969, WGS72, WGS84

## Documentation

Full documentation is available at **[madbomber.github.io/geodetic](https://madbomber.github.io/geodetic/)**.

## Examples

The [`examples/`](examples/) directory contains runnable demo scripts showing progressive usage:

| Script | Description |
|--------|-------------|
| [`01_basic_conversions.rb`](examples/01_basic_conversions.rb) | LLA, ECEF, UTM, ENU, NED conversions and roundtrips |
| [`02_all_coordinate_systems.rb`](examples/02_all_coordinate_systems.rb) | All 18 coordinate systems, cross-system chains, and areas |
| [`03_distance_calculations.rb`](examples/03_distance_calculations.rb) | Distance class features, unit conversions, and arithmetic |
| [`04_bearing_calculations.rb`](examples/04_bearing_calculations.rb) | Bearing class, compass directions, elevation angles, and chain bearings |
| [`05_map_rendering/`](examples/05_map_rendering/) | Render landmarks on a raster map with Feature objects, polygon areas, bearing arrows, and icons using [libgd-gis](https://rubygems.org/gems/libgd-gis) |
| [`06_path_operations.rb`](examples/06_path_operations.rb) | Path class: construction, navigation, mutation, path arithmetic, closest approach, containment, Enumerable, equality, subpaths, split, interpolation, bounding boxes, polygon conversion, intersection, path-to-path/area closest points, and Feature integration |
| [`07_segments_and_shapes.rb`](examples/07_segments_and_shapes.rb) | Segment and polygon subclasses: Triangle, Rectangle, Pentagon, Hexagon, Octagon with containment, edges, and bounding boxes |
| [`08_geodetic_arithmetic.rb`](examples/08_geodetic_arithmetic.rb) | Geodetic arithmetic: building geometry with + (Segments, Paths, Circles), Vector class (Vincenty direct, components, arithmetic, dot/cross products), translation with * (Coordinates, Segments, Paths, Circles, Polygons), and corridors |
| [`09_geojson_export.rb`](examples/09_geojson_export.rb) | GeoJSON export: `to_geojson` on all geometry types, `GeoJSON` class for building FeatureCollections with `<<`, delete/clear, Enumerable, and `save` to file |

Run any example with:

```bash
ruby -Ilib examples/01_basic_conversions.rb
```

## Development

For comprehensive guides and API documentation, visit **[https://madbomber.github.io/geodetic](https://madbomber.github.io/geodetic)**

```bash
bin/setup          # Install dependencies
rake test          # Run tests
bin/console        # Interactive console
```

## License

Available as open source under the [MIT License](https://opensource.org/licenses/MIT).
