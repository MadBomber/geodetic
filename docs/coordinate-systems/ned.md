# Geodetic::Coordinates::NED - North, East, Down

## Overview

NED (North, East, Down) is a local tangent plane coordinate system commonly used in aviation and navigation. It defines positions relative to a local reference point on the Earth's surface, with axes pointing North, East, and Down.

## Constructor

```ruby
NED.new(n: 0.0, e: 0.0, d: 0.0)
```

All parameters are in **meters**.

## Attribute Aliases

| Primary | Alias   |
|---------|---------|
| `n`     | `north` |
| `e`     | `east`  |
| `d`     | `down`  |

## Reference Point

NED is a local coordinate system. Conversions to and from global coordinate systems (such as LLA or ECEF) require a **reference point** specified as an LLA coordinate. This reference point defines the origin of the local tangent plane.

The one exception is the conversion between NED and ENU, which does not require a reference point.

## Conversions

### Direct (no reference point needed)

- **NED <-> ENU** — A simple axis remap:
  ```
  NED(n, e, d) <-> ENU(e, n, -d)
  ```

### Via reference point

- **NED -> LLA** — Requires a reference LLA.
- **NED -> ECEF** — Requires a reference LLA.

## Methods

| Method                          | Description                                                              |
|---------------------------------|--------------------------------------------------------------------------|
| `horizontal_distance_to(other)` | Horizontal (N-E plane) distance to another NED point (meters)            |
| `local_bearing_to(other)`       | Bearing from this point to another NED point (degrees from north, 0-360) |
| `local_elevation_angle_to(other)` | Elevation angle from this point to another NED point (degrees)         |
| `distance_to_origin`            | Euclidean distance from this point to the origin (meters)                |
| `elevation_angle`               | Elevation angle from the origin to this point (degrees)                  |
| `bearing_from_origin`           | Bearing from the origin to this point (degrees from north, 0-360)        |
| `horizontal_distance_to_origin` | Horizontal distance from this point to the origin (meters)               |

### Universal Distance and Bearing Methods

NED is a relative coordinate system. The universal `distance_to`, `straight_line_distance_to`, `bearing_to`, and `elevation_to` methods raise `ArgumentError` because NED cannot be converted to an absolute system without a reference point. Convert to an absolute system first:

```ruby
ref = Geodetic::Coordinates::LLA.new(lat: 47.62, lng: -122.35, alt: 0.0)
lla = ned.to_lla(ref)
lla.distance_to(other_lla)   # Vincenty great-circle distance
lla.bearing_to(other_lla)    # Great-circle forward azimuth (Bearing object)
```

## Bearing Convention

Bearing is measured in **degrees from north**, clockwise, in the range **0-360**.

## Example

```ruby
point = Geodetic::Coordinates::NED.new(n: 200.0, e: 100.0, d: -50.0)

point.north  # => 200.0
point.east   # => 100.0
point.down   # => -50.0

point.distance_to_origin            # => Euclidean distance in meters
point.bearing_from_origin           # => Bearing in degrees from north
point.elevation_angle               # => Elevation angle in degrees
point.horizontal_distance_to_origin # => Horizontal distance in meters
```
