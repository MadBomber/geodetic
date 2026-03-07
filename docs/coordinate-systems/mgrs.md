# Geodetic::Coordinates::MGRS - Military Grid Reference System

## Overview

MGRS (Military Grid Reference System) is a geocoordinate standard used by NATO militaries for locating points on Earth. It is based on the UTM coordinate system, augmented with a lettering scheme for grid zone designators and 100km square identifiers.

## Constructor

### From a complete MGRS string

```ruby
MGRS.new(mgrs_string: "18SUJ2337006519")
```

### From individual components

```ruby
MGRS.new(
  grid_zone:  "18S",
  square_id:  "UJ",
  easting:    23370,
  northing:   06519,
  precision:  5
)
```

## String Representation

| Method        | Description                                   |
|---------------|-----------------------------------------------|
| `from_string` | Parses an MGRS string into its components     |
| `to_s`        | Returns the compact MGRS string representation |

### Example

```ruby
mgrs = Geodetic::Coordinates::MGRS.new(mgrs_string: "18SUJ2337006519")
mgrs.to_s  # => "18SUJ2337006519"
```

## Precision Levels

MGRS supports five levels of precision, controlling the number of digits in the easting and northing components:

| Precision | Digits (per axis) | Resolution |
|-----------|--------------------|------------|
| 1         | 1                  | 10 km      |
| 2         | 2                  | 1 km       |
| 3         | 3                  | 100 m      |
| 4         | 4                  | 10 m       |
| 5         | 5                  | 1 m        |

## Components

| Component    | Description                                        | Example |
|--------------|----------------------------------------------------|---------|
| `grid_zone`  | UTM zone number + latitude band letter              | `18S`   |
| `square_id`  | 100km square identification (two-letter code)       | `UJ`    |
| `easting`    | Easting within the 100km square                     | `23370` |
| `northing`   | Northing within the 100km square                    | `06519` |
| `precision`  | Number of digits per coordinate (1-5)               | `5`     |

## Conversions

MGRS converts to other coordinate systems via **UTM** and **LLA**:

- **MGRS -> UTM** — Decomposes the grid zone and square ID back to UTM easting/northing.
- **MGRS -> LLA** — Converts through UTM to latitude/longitude.

## Example

```ruby
mgrs = Geodetic::Coordinates::MGRS.new(mgrs_string: "18SUJ2337006519")

mgrs.grid_zone  # => "18S"
mgrs.square_id  # => "UJ"
mgrs.easting    # => 23370
mgrs.northing   # => 06519
mgrs.precision  # => 5
mgrs.to_s       # => "18SUJ2337006519"
```
