# Geodetic::Coordinates::StatePlane

## US State Plane Coordinate System

The State Plane Coordinate System (SPCS) is a set of 124 geographic zones used across the United States. Each zone uses either a Lambert Conformal Conic or Transverse Mercator projection, chosen to minimize distortion within that zone. Units are typically expressed in **US Survey Feet**.

## Constructor

```ruby
point = Geodetic::Coordinates::StatePlane.new(
  easting:   0.0,
  northing:  0.0,
  zone_code: 'CA_I',
  datum:     Geodetic::Datum::WGS84
)
```

- `easting` — Easting coordinate (typically in US Survey Feet)
- `northing` — Northing coordinate (typically in US Survey Feet)
- `zone_code` — Identifier for the State Plane zone
- `datum` — The geodetic datum; stored internally on the coordinate object

## Available Zones

The following zone codes are currently supported:

| Zone Code | State / Region |
|---|---|
| `CA_I` | California, Zone I |
| `CA_II` | California, Zone II |
| `TX_NORTH` | Texas, North |
| `FL_EAST` | Florida, East |
| `NY_LONG_ISLAND` | New York, Long Island |

## Projections

Each zone uses one of two map projections depending on its geographic shape:

- **Lambert Conformal Conic** — Used for zones that are wider east-to-west
- **Transverse Mercator** — Used for zones that are longer north-to-south

## Unit Conversion

```ruby
meters_point    = point.to_meters
feet_point      = point.to_us_survey_feet
```

## Methods

| Method | Description |
|---|---|
| `zone_info` | Returns metadata about the current zone (projection type, parameters, bounds) |
| `valid?` | Returns `true` if the coordinates fall within the defined zone bounds |
| `zones_for_state(state)` | Class method. Returns available zone codes for a given US state |
| `find_zone_for_lla(lla)` | Class method. Determines the appropriate State Plane zone for a given LLA coordinate |

## Datum

The `StatePlane` coordinate object stores its associated datum internally, accessible for reference during conversions and transformations.
