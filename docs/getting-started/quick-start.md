# Quick Start

This guide walks through the core features of Geodetic using the Seattle Space Needle as a reference point.

## 1. Create an LLA Coordinate

LLA (Latitude, Longitude, Altitude) is the most common starting point. All constructors use keyword arguments.

```ruby
require "geodetic"
require "geodetic/coordinate/lla"

space_needle = Geodetic::Coordinate::LLA.new(
  lat: 47.6205,
  lng: -122.3493,
  alt: 184.0
)

puts space_needle.lat       #=> 47.6205
puts space_needle.longitude #=> -122.3493 (alias for lng)
puts space_needle.alt       #=> 184.0
```

## 2. Convert to ECEF

ECEF (Earth-Centered, Earth-Fixed) represents a position as X, Y, Z coordinates in meters relative to the center of the Earth.

```ruby
ecef = space_needle.to_ecef

puts ecef.x  # X coordinate in meters
puts ecef.y  # Y coordinate in meters
puts ecef.z  # Z coordinate in meters

# Convert back to LLA
lla = ecef.to_lla
puts lla.to_s  #=> "47.6205, -122.3493, 184.0"
```

## 3. Convert to UTM

UTM (Universal Transverse Mercator) is widely used in mapping and surveying.

```ruby
utm = space_needle.to_utm

puts utm.easting     # easting in meters
puts utm.northing    # northing in meters
puts utm.altitude    # altitude in meters
puts utm.zone        # UTM zone number (e.g., 10)
puts utm.hemisphere  # "N" or "S"

# Convert back to LLA
lla = utm.to_lla
```

## 4. Convert to Local Coordinates (ENU and NED)

Local tangent plane coordinate systems require a reference point. ENU (East, North, Up) and NED (North, East, Down) are commonly used in navigation and aerospace.

```ruby
# Define a reference point (e.g., a nearby base station)
reference = Geodetic::Coordinate::LLA.new(
  lat: 47.6062,
  lng: -122.3321,
  alt: 0.0
)

# Convert to ENU relative to the reference
enu = space_needle.to_enu(reference)

puts enu.east   # meters east of reference (alias: e)
puts enu.north  # meters north of reference (alias: n)
puts enu.up     # meters above reference (alias: u)

# Convert to NED relative to the reference
ned = space_needle.to_ned(reference)

puts ned.north  # meters north of reference (alias: n)
puts ned.east   # meters east of reference (alias: e)
puts ned.down   # meters below reference (alias: d)

# ENU and NED convert directly to each other
ned_from_enu = enu.to_ned
enu_from_ned = ned.to_enu

# Convert back to LLA
lla = enu.to_lla(reference)
```

## 5. Use DMS Format

LLA coordinates can be displayed and parsed in Degrees, Minutes, Seconds format.

```ruby
# Convert to DMS string
dms = space_needle.to_dms
puts dms  #=> "47° 37' 13.80\" N, 122° 20' 57.48\" W, 184.00 m"

# Parse a DMS string back to LLA
lla = Geodetic::Coordinate::LLA.from_dms("47° 37' 13.80\" N, 122° 20' 57.48\" W, 184.00 m")
puts lla.lat  #=> 47.6205
```

## 6. Serialize and Deserialize

Every coordinate type supports `to_s`, `to_a`, `from_string`, and `from_array` for serialization.

```ruby
# Serialize to string and array
str = space_needle.to_s    #=> "47.6205, -122.3493, 184.0"
arr = space_needle.to_a    #=> [47.6205, -122.3493, 184.0]

# Deserialize
lla_from_str = Geodetic::Coordinate::LLA.from_string(str)
lla_from_arr = Geodetic::Coordinate::LLA.from_array(arr)

# Works the same for all coordinate types
ecef = space_needle.to_ecef
ecef_str = ecef.to_s
ecef_arr = ecef.to_a
ecef_restored = Geodetic::Coordinate::ECEF.from_string(ecef_str)
ecef_restored = Geodetic::Coordinate::ECEF.from_array(ecef_arr)
```

## 7. Work with Datums

Geodetic ships with 16 geodetic datums. All conversion methods default to WGS84 but accept an optional datum parameter.

```ruby
# List available datums
Geodetic::Datum.list

# Use a specific datum
clarke = Geodetic::Datum.new(name: "CLARKE_1866")

ecef_clarke = space_needle.to_ecef(clarke)
utm_clarke  = space_needle.to_utm(clarke)

# Inspect datum properties
puts clarke.name    #=> "CLARKE_1866"
puts clarke.desc    #=> "Clarke 1866"
puts clarke.a       #=> 6378206.4 (semi-major axis in meters)
puts clarke.b       #=> 6356583.7999989809 (semi-minor axis in meters)
puts clarke.f       #=> flattening
puts clarke.e2      #=> eccentricity squared

# Look up a datum by name
info = Geodetic::Datum.get("WGS84")
puts info.desc   #=> "World Geodetic System 1984"
```

Available datums include: WGS84, WGS72, GRS_1980, CLARKE_1866, CLARKE_1880, AIRY, MODIFIED_AIRY, AUSTRALIAN_NATIONAL, BESSEL_1841, EVEREST_INDIA_1830, EVEREST_BRUNEI_E_MALAYSIA, EVEREST_W_MALAYSIA_SINGAPORE, HELMERT_1906, HOUGH_1960, INTERNATIONAL_1924, and SOUTH_AMERICAN_1969.

## 8. Geoid Height

The `GeoidHeight` class converts between ellipsoidal heights (HAE) and orthometric heights (e.g., NAVD88, MSL). LLA coordinates include geoid height support directly.

```ruby
# Get the geoid undulation at a location
undulation = space_needle.geoid_height
puts undulation  # geoid height in meters (EGM2008 model)

# Get orthometric height (height above mean sea level)
ortho = space_needle.orthometric_height
puts ortho  # orthometric height in meters

# Convert between vertical datums
lla_navd88 = space_needle.convert_height_datum("HAE", "NAVD88")

# Use a different geoid model
undulation_egm96 = space_needle.geoid_height("EGM96")
```

Available geoid models: EGM96, EGM2008, GEOID18, GEOID12B.
