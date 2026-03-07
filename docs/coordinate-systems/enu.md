# Geodetic::Coordinates::ENU - East, North, Up

## Overview

ENU (East, North, Up) is a local tangent plane coordinate system. It defines positions relative to a local reference point on the Earth's surface, with axes pointing East, North, and Up.

## Constructor

```ruby
ENU.new(e: 0.0, n: 0.0, u: 0.0)
```

All parameters are in **meters**.

## Attribute Aliases

| Primary | Alias   |
|---------|---------|
| `e`     | `east`  |
| `n`     | `north` |
| `u`     | `up`    |

## Reference Point

ENU is a local coordinate system. Conversions to and from global coordinate systems (such as LLA or ECEF) require a **reference point** specified as an LLA coordinate. This reference point defines the origin of the local tangent plane.

The one exception is the conversion between ENU and NED, which does not require a reference point.

## Conversions

### Direct (no reference point needed)

- **ENU <-> NED** — A simple axis remap: `ENU(e, n, u)` corresponds to `NED(n, e, -u)`.

### Via reference point

- **ENU -> LLA** — Requires a reference LLA.
- **ENU -> ECEF** — Requires a reference LLA.

## Methods

| Method                          | Description                                                        |
|---------------------------------|--------------------------------------------------------------------|
| `horizontal_distance_to(other)` | Horizontal (E-N plane) distance to another ENU point (meters)      |
| `local_bearing_to(other)`       | Bearing from this point to another ENU point (degrees from north, 0-360) |
| `distance_to_origin`            | Euclidean distance from this point to the origin (meters)          |
| `bearing_from_origin`           | Bearing from the origin to this point (degrees from north, 0-360)  |
| `horizontal_distance_to_origin` | Horizontal distance from this point to the origin (meters)         |

### Universal Distance and Bearing Methods

ENU is a relative coordinate system. The universal `distance_to`, `straight_line_distance_to`, `bearing_to`, and `elevation_to` methods raise `ArgumentError` because ENU cannot be converted to an absolute system without a reference point. Convert to an absolute system first:

```ruby
ref = Geodetic::Coordinates::LLA.new(lat: 47.62, lng: -122.35, alt: 0.0)
lla = enu.to_lla(ref)
lla.distance_to(other_lla)   # Vincenty great-circle distance
lla.bearing_to(other_lla)    # Great-circle forward azimuth (Bearing object)
```

## Bearing Convention

Bearing is measured in **degrees from north**, clockwise, in the range **0-360**.

## Example

```ruby
point = Geodetic::Coordinates::ENU.new(e: 100.0, n: 200.0, u: 50.0)

point.east   # => 100.0
point.north  # => 200.0
point.up     # => 50.0

point.distance_to_origin            # => Euclidean distance in meters
point.bearing_from_origin           # => Bearing in degrees from north
point.horizontal_distance_to_origin # => Horizontal distance in meters
```
