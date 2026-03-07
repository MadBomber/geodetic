# Geodetic::Coordinates::USNG - US National Grid

## Overview

USNG (US National Grid) is a coordinate system based on MGRS, adopted for use by US emergency services and civilian agencies. It provides a consistent, interoperable grid reference system across the United States.

## Constructor

### From a complete USNG string

```ruby
USNG.new(usng_string: "18T WL 12345 67890")
```

### From individual components

```ruby
USNG.new(
  grid_zone:  "18T",
  square_id:  "WL",
  easting:    12345,
  northing:   67890,
  precision:  5
)
```

## Format Differences from MGRS

USNG uses a **spaced format** for readability, whereas MGRS uses a compact (unspaced) format:

| System | Format                    |
|--------|---------------------------|
| USNG   | `18T WL 12345 67890`      |
| MGRS   | `18TWL1234567890`         |

## String Representation

| Method                   | Description                                         |
|--------------------------|-----------------------------------------------------|
| `from_string`            | Parses a USNG string into its components            |
| `to_s`                   | Returns the USNG string representation              |
| `to_full_format`         | Returns the full spaced USNG format                 |
| `to_abbreviated_format`  | Returns an abbreviated representation               |

## Validation

| Method   | Description                                                       |
|----------|-------------------------------------------------------------------|
| `valid?` | Checks that the zone designator falls within valid US zones       |

## Conversions

USNG converts through **MGRS** internally. All coordinate conversions follow the chain:

```
USNG <-> MGRS <-> UTM <-> LLA
```

## Example

```ruby
usng = Geodetic::Coordinates::USNG.new(usng_string: "18T WL 12345 67890")

usng.grid_zone  # => "18T"
usng.square_id  # => "WL"
usng.easting    # => 12345
usng.northing   # => 67890
usng.precision  # => 5

usng.to_s                  # => "18T WL 12345 67890"
usng.to_full_format        # => Full spaced format
usng.to_abbreviated_format # => Abbreviated format
usng.valid?                # => true (if within valid US zones)
```
