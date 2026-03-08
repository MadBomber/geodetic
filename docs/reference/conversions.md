# Conversions Reference

Every coordinate class in the Geodetic gem can convert to every other coordinate class. Conversions are available as both instance methods (on the source object) and class methods (on the target class).

---

## Conversion Method Patterns

### Instance Methods (on the source)

```ruby
source.to_<target>(datum = WGS84)
```

Examples:

```ruby
lla.to_ecef                       # LLA -> ECEF
lla.to_utm                        # LLA -> UTM
ecef.to_lla                       # ECEF -> LLA
utm.to_lla                        # UTM -> LLA
web_mercator.to_lla               # WebMercator -> LLA
bng.to_utm                        # BNG -> UTM
ups.to_mgrs                       # UPS -> MGRS
state_plane.to_web_mercator       # StatePlane -> WebMercator
```

### Class Methods (on the target)

```ruby
TargetClass.from_<source>(source_object, datum = WGS84)
```

Examples:

```ruby
Geodetic::Coordinates::ECEF.from_lla(lla)
Geodetic::Coordinates::LLA.from_ecef(ecef)
Geodetic::Coordinates::UTM.from_lla(lla)
Geodetic::Coordinates::LLA.from_utm(utm)
Geodetic::Coordinates::WebMercator.from_ecef(ecef)
```

---

## Local Coordinate Systems (ENU, NED)

ENU and NED are local tangent plane systems that require a **reference LLA** point defining the origin of the local frame. All conversions to/from ENU and NED include a reference parameter.

### Instance Methods

```ruby
ref = Geodetic::Coordinates::LLA.new(lat: 38.8977, lng: -77.0365, alt: 0.0)

# LLA to local
lla.to_enu(ref)
lla.to_ned(ref)

# Local to LLA
enu.to_lla(ref)
ned.to_lla(ref)

# Local to UTM (requires reference)
enu.to_utm(ref)
ned.to_utm(ref)

# ENU <-> NED (direct, no reference needed)
enu.to_ned
ned.to_enu

# ECEF to local (reference_ecef required, reference_lla optional)
ecef.to_enu(reference_ecef, reference_lla)
ecef.to_ned(reference_ecef, reference_lla)

# Local to ECEF (reference_ecef required, reference_lla optional)
enu.to_ecef(reference_ecef, reference_lla)
ned.to_ecef(reference_ecef, reference_lla)
```

### Class Methods

```ruby
ref = Geodetic::Coordinates::LLA.new(lat: 38.8977, lng: -77.0365, alt: 0.0)

Geodetic::Coordinates::ENU.from_lla(lla, ref)
Geodetic::Coordinates::NED.from_lla(lla, ref)
Geodetic::Coordinates::LLA.from_enu(enu, ref)
Geodetic::Coordinates::LLA.from_ned(ned, ref)

# From other systems via reference
Geodetic::Coordinates::ENU.from_utm(utm, ref)
Geodetic::Coordinates::NED.from_utm(utm, ref)
Geodetic::Coordinates::UTM.from_enu(enu, ref)
Geodetic::Coordinates::UTM.from_ned(ned, ref)

# ECEF-based
Geodetic::Coordinates::ENU.from_ecef(ecef, ref_ecef, ref_lla)
Geodetic::Coordinates::NED.from_ecef(ecef, ref_ecef, ref_lla)
Geodetic::Coordinates::ECEF.from_enu(enu, ref_ecef, ref_lla)
Geodetic::Coordinates::ECEF.from_ned(ned, ref_ecef, ref_lla)
```

When `reference_lla` is omitted in ECEF-based conversions, it is computed automatically from `reference_ecef` via `reference_ecef.to_lla`.

---

## MGRS and USNG Conversions

MGRS and USNG accept an optional `precision` parameter (1-5, default 5) controlling the coordinate resolution:

| Precision | Resolution |
|-----------|-----------|
| 1 | 10 km |
| 2 | 1 km |
| 3 | 100 m |
| 4 | 10 m |
| 5 | 1 m |

```ruby
# LLA to MGRS with precision
Geodetic::Coordinates::MGRS.from_lla(lla, datum, precision)
lla_point.to_mgrs(datum, precision)      # available on UPS, WebMercator, BNG, StatePlane

# LLA to USNG with precision
Geodetic::Coordinates::USNG.from_lla(lla, datum, precision)

# MGRS <-> USNG (direct conversion)
mgrs.to_usng   # implicit via component transfer
Geodetic::Coordinates::USNG.from_mgrs(mgrs)
usng.to_mgrs
Geodetic::Coordinates::MGRS.from_usng(usng)  # implicit via string
```

---

## StatePlane Conversions

StatePlane requires a **zone code** when converting into the system:

```ruby
# To StatePlane (zone_code required)
Geodetic::Coordinates::StatePlane.from_lla(lla, 'CA_I')
Geodetic::Coordinates::StatePlane.from_ecef(ecef, 'CA_I')
Geodetic::Coordinates::StatePlane.from_utm(utm, 'CA_I')
Geodetic::Coordinates::StatePlane.from_enu(enu, ref_lla, 'CA_I')
Geodetic::Coordinates::StatePlane.from_ned(ned, ref_lla, 'CA_I')

# From StatePlane (zone is stored in the object)
state_plane.to_lla
state_plane.to_ecef
state_plane.to_utm
state_plane.to_enu(ref_lla)
state_plane.to_ned(ref_lla)
```

BNG also provides conversion to StatePlane with a zone code:

```ruby
bng.to_state_plane('CA_I')
```

---

## Datum Parameter

Most conversion methods accept an optional datum parameter that defaults to `Geodetic::WGS84`:

```ruby
# Using a different datum
clarke = Geodetic::Datum.new(name: 'CLARKE_1866')

lla.to_ecef(clarke)
ecef.to_lla(clarke)
lla.to_utm(clarke)
utm.to_lla(clarke)
```

StatePlane stores its datum internally and uses it when no datum argument is provided:

```ruby
sp = Geodetic::Coordinates::StatePlane.new(
  easting: 2000000.0, northing: 500000.0,
  zone_code: 'CA_I', datum: clarke
)
sp.to_lla          # uses the stored clarke datum
sp.to_lla(wgs84)   # overrides with wgs84
```

---

## Conversion Chains

Most conversions are not direct but route through intermediate systems. The gem handles this transparently. Here are the typical chains:

| Conversion | Chain |
|-----------|-------|
| LLA <-> ECEF | Direct mathematical transformation |
| LLA <-> UTM | Direct mathematical transformation |
| LLA <-> ENU | LLA -> ECEF -> ENU (and reverse) |
| LLA <-> NED | LLA -> ECEF -> ENU -> NED (and reverse) |
| ENU <-> NED | Direct axis swap: `NED(n, e, d) = ENU(e, n, -u)` |
| UTM <-> ECEF | UTM -> LLA -> ECEF (and reverse) |
| UTM <-> ENU | UTM -> LLA -> ENU (and reverse) |
| MGRS <-> LLA | MGRS -> UTM -> LLA (and reverse) |
| USNG <-> LLA | USNG -> MGRS -> UTM -> LLA (and reverse) |
| WebMercator <-> LLA | Direct mathematical transformation |
| UPS <-> LLA | Direct mathematical transformation |
| BNG <-> LLA | BNG -> OSGB36 LLA -> WGS84 LLA (with datum shift) |
| StatePlane <-> LLA | Direct projection (Lambert or Transverse Mercator) |
| GH36 <-> LLA | Encode/decode via 6x6 matrix subdivision |
| GH <-> LLA | Encode/decode via bit-interleaved base-32 |
| HAM <-> LLA | Encode/decode via hierarchical letter/digit pairs |
| Any <-> Any | Routes through LLA as the universal hub |

---

## Conversion Accuracy Notes

- **LLA <-> ECEF**: Full precision. Iterative algorithm converges to sub-millimeter accuracy (tolerance: 1e-12 radians for latitude, 1e-12 meters for altitude, max 100 iterations).
- **LLA <-> UTM**: Simplified series expansion. Accurate for typical use but may diverge at extreme latitudes or far from the central meridian.
- **ENU / NED**: Full precision when going through ECEF. The rotation matrices are exact.
- **MGRS / USNG**: Precision depends on the grid precision level (1-5). A 5-digit precision gives 1-meter resolution.
- **WebMercator**: Latitude is clamped to +/-85.0511 degrees. Altitude information is lost (always 0.0).
- **UPS**: Iterative refinement (5 iterations) for the inverse projection. Designed for polar regions.
- **BNG**: Uses a simplified datum transformation between OSGB36 and WGS84 (approximate offset). A full Helmert 7-parameter transformation would provide higher accuracy.
- **StatePlane**: Uses simplified projection formulas. Production applications may require the full NOAA/NGS projection equations for survey-grade accuracy.
- **GH36**: Precision depends on hash length. Default 10 characters gives sub-meter resolution. Altitude information is lost (always 0.0).
- **GH**: Precision depends on hash length. Default 12 characters gives sub-centimeter resolution. Altitude information is lost (always 0.0).
- **HAM**: Precision depends on locator length (2, 4, 6, or 8 characters). Default 6 characters gives ~5 km resolution. Altitude information is lost (always 0.0).
- **Equality comparisons**: All classes use tolerance-based equality. Coordinates (in meters) use 1e-6 m tolerance. LLA uses 1e-10 degrees for lat/lng and 1e-6 m for altitude. GH36, GH, and HAM use exact string comparison.

---

## Distance Calculations

Universal distance methods are available on all coordinate types and work across different coordinate systems.

### Great-Circle Distance (Vincenty)

- **`distance_to(other, *others)`** — Instance method. Computes the Vincenty great-circle distance from the receiver to one or more target coordinates. Returns a `Distance` for a single target, or an Array of `Distance` objects for multiple targets (radial distances from the receiver).
- **`GCS.distance_between(*coords)`** — Class method on `Geodetic::Coordinates` (aliased as `GCS`). Computes consecutive chain distances between an ordered sequence of coordinates. Returns a `Distance` for two coordinates, or an Array of `Distance` objects for three or more.

> **`Distance` objects** wrap a distance value and provide unit-aware access. Call `.meters` to get the raw Float value in meters, or `.to_f` to get the value in the current display unit.

```ruby
seattle = GCS::LLA.new(lat: 47.6205, lng: -122.3493, alt: 0.0)
portland = GCS::LLA.new(lat: 45.5152, lng: -122.6784, alt: 0.0)
sf = GCS::LLA.new(lat: 37.7749, lng: -122.4194, alt: 0.0)

# Radial distances from receiver
seattle.distance_to(portland)          # => Distance (235393.17 m)
seattle.distance_to(portland, sf)      # => [Distance, Distance] (Array)

# Consecutive chain distances
GCS.distance_between(seattle, portland, sf)  # => [Distance, Distance] (Array)
```

### Straight-Line Distance (ECEF Euclidean)

- **`straight_line_distance_to(other, *others)`** — Instance method. Computes the Euclidean distance in ECEF (3D Cartesian) space. Returns a `Distance` for a single target, or an Array of `Distance` objects for multiple targets.
- **`GCS.straight_line_distance_between(*coords)`** — Class method. Computes consecutive chain Euclidean distances.

```ruby
seattle.straight_line_distance_to(portland)              # => Distance
GCS.straight_line_distance_between(seattle, portland)    # => Distance
```

### Cross-System Distances

Both `distance_to` and `straight_line_distance_to` accept any coordinate type. Coordinates are converted to LLA (for Vincenty) or ECEF (for Euclidean) internally:

```ruby
utm = seattle.to_utm
mgrs = GCS::MGRS.from_lla(portland)
utm.distance_to(mgrs)    # => Distance (235393.17 m)
```

### ENU and NED (Relative Systems)

ENU and NED are relative coordinate systems and do not support `distance_to` or `straight_line_distance_to` directly. Convert to an absolute system first:

```ruby
ref = GCS::LLA.new(lat: 47.62, lng: -122.35, alt: 0.0)
lla = enu.to_lla(ref)
lla.distance_to(other_lla)
```

ENU and NED retain `horizontal_distance_to` and `local_bearing_to` for local Euclidean operations within the tangent plane.

---

## Bearing Calculations

Universal bearing methods are available on all coordinate types and work across different coordinate systems. All bearing methods return `Bearing` objects.

### Great-Circle Bearing (Forward Azimuth)

- **`bearing_to(other)`** — Instance method. Computes the great-circle forward azimuth from the receiver to the target coordinate. Returns a `Bearing` object.
- **`elevation_to(other)`** — Instance method. Computes the vertical look angle (elevation) from the receiver to the target. Returns a Float in degrees (-90 to +90).
- **`GCS.bearing_between(*coords)`** — Class method on `Geodetic::Coordinates` (aliased as `GCS`). Computes consecutive chain bearings between an ordered sequence of coordinates. Returns a `Bearing` for two coordinates, or an Array of `Bearing` objects for three or more.

```ruby
seattle = GCS::LLA.new(lat: 47.6205, lng: -122.3493, alt: 0.0)
portland = GCS::LLA.new(lat: 45.5152, lng: -122.6784, alt: 0.0)
sf = GCS::LLA.new(lat: 37.7749, lng: -122.4194, alt: 0.0)

# Forward azimuth
b = seattle.bearing_to(portland)       # => Bearing
b.degrees                              # => 188.2...
b.to_compass(points: 8)               # => "S"
b.reverse                             # => Bearing (back azimuth)

# Elevation angle
seattle.elevation_to(portland)         # => Float (degrees)

# Consecutive chain bearings
GCS.bearing_between(seattle, portland, sf)  # => [Bearing, Bearing]
```

### Cross-System Bearings

`bearing_to` and `elevation_to` accept any coordinate type. Coordinates are converted to LLA internally:

```ruby
utm = seattle.to_utm
mgrs = GCS::MGRS.from_lla(portland)
utm.bearing_to(mgrs)    # => Bearing
```

### ENU and NED (Relative Systems)

ENU and NED are relative coordinate systems and do not support `bearing_to` or `elevation_to` directly (these raise `ArgumentError`). Convert to an absolute system first, or use the local methods:

- **`local_bearing_to(other)`** — Local tangent plane bearing (degrees from north, 0-360)
- **`local_elevation_angle_to(other)`** — Local elevation angle (NED only, degrees)

### Bearing Class

`Bearing` wraps an azimuth angle (0-360) with compass and radian conversions:

```ruby
b = Geodetic::Bearing.new(225)
b.degrees                   # => 225.0
b.to_radians                # => 3.926...
b.reverse                   # => Bearing (45)
b.to_compass(points: 4)     # => "W"
b.to_compass(points: 8)     # => "SW"
b.to_compass(points: 16)    # => "SW"
b.to_s                      # => "225.0000°"

# Arithmetic
b + 10                       # => Bearing (235°)
b - 10                       # => Bearing (215°)
Bearing.new(90) - Bearing.new(45)  # => 45.0 (Float, angular difference)
```
