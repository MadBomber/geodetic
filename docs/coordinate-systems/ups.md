# Geodetic::Coordinate::UPS

## Universal Polar Stereographic

The Universal Polar Stereographic (UPS) coordinate system covers the polar regions of the Earth that fall outside the UTM grid: latitudes north of 84°N and south of 80°S. It uses a stereographic projection centered on each pole.

## Constructor

```ruby
point = Geodetic::Coordinate::UPS.new(
  easting:    0.0,
  northing:   0.0,
  hemisphere: 'N',
  zone:       'Y'
)
```

- `easting` — Easting coordinate in meters
- `northing` — Northing coordinate in meters
- `hemisphere` — `'N'` for the North Pole region, `'S'` for the South Pole region
- `zone` — UPS zone letter

## Zones

UPS divides each polar region into two zones based on longitude:

| Hemisphere | Zones | Longitude Range |
|---|---|---|
| North | Y, Z | Y: 180°W to 0°; Z: 0° to 180°E |
| South | A, B | A: 180°W to 0°; B: 0° to 180°E |

## False Origin

Both easting and northing use a **false origin of 2,000,000 meters** to ensure all coordinate values remain positive within the projection.

## Methods

| Method | Description |
|---|---|
| `grid_convergence` | Returns the angular difference between grid north and true north at the point |
| `point_scale_factor` | Returns the scale distortion factor at the point's location |
| `valid?` | Returns `true` if the coordinates represent a valid UPS position |

### Universal Distance Methods

The universal `distance_to` method computes the Vincenty great-circle distance (in meters) to any other coordinate type. The `straight_line_distance_to` method computes the Euclidean distance in ECEF space. Both accept single or multiple targets.

```ruby
ups_a = Geodetic::Coordinate::UPS.new(easting: 2000000.0, northing: 2000000.0, hemisphere: 'N', zone: 'Z')
ups_b = Geodetic::Coordinate::UPS.new(easting: 2100000.0, northing: 2100000.0, hemisphere: 'N', zone: 'Z')
ups_a.distance_to(ups_b)                # => Distance (meters, great-circle)
ups_a.straight_line_distance_to(ups_b)  # => Distance (meters, Euclidean)
```
