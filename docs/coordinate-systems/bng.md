# Geodetic::Coordinates::BNG

## British National Grid

The British National Grid (BNG) is the official coordinate system for Great Britain, based on the **OSGB36 datum** and the **Airy 1830 ellipsoid**. It uses a Transverse Mercator projection centered on 2°W longitude and 49°N latitude.

## Constructors

Create a BNG coordinate from numeric easting/northing values:

```ruby
point = Geodetic::Coordinates::BNG.new(easting: 530000.0, northing: 180000.0)
```

Alternatively, create from an alphanumeric grid reference string:

```ruby
point = Geodetic::Coordinates::BNG.new(grid_ref: "TQ 300000 800000")
```

## Grid References

Convert a BNG coordinate to an alphanumeric grid reference at a specified precision:

```ruby
grid_ref = point.to_grid_reference(precision)
```

The `precision` parameter controls the number of digits and therefore the resolution of the resulting grid reference.

## Ellipsoid and Datum

BNG uses the **Airy 1830 ellipsoid** internally as part of the OSGB36 datum. When converting between BNG and WGS84-based coordinate systems (such as GPS coordinates), an approximate **OSGB36 to WGS84 transformation** is applied. This transformation introduces small positional offsets (typically a few meters) due to the inherent differences between the two datums.

## Validation

The `valid?` method checks that the coordinates fall within the bounds of Great Britain:

| Axis | Valid Range |
|---|---|
| Easting | 0 to 700,000 meters |
| Northing | 0 to 1,300,000 meters |

```ruby
point.valid?  # => true if within Great Britain bounds
```

## Utility Methods

| Method | Description |
|---|---|
| `bearing_to(other)` | Computes the bearing (in degrees from grid north) to another `BNG` point |

### Universal Distance Methods

The universal `distance_to` method computes the Vincenty great-circle distance (in meters) to any other coordinate type. The `straight_line_distance_to` method computes the Euclidean distance in ECEF space. Both accept single or multiple targets.

```ruby
bng_a = Geodetic::Coordinates::BNG.new(easting: 530000.0, northing: 180000.0)
bng_b = Geodetic::Coordinates::BNG.new(easting: 540000.0, northing: 190000.0)
bng_a.distance_to(bng_b)                # => Distance (meters, great-circle)
bng_a.straight_line_distance_to(bng_b)  # => Distance (meters, Euclidean)
```
