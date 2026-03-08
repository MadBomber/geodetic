# Datums Reference

## Geodetic::Datum

A datum defines the reference ellipsoid used for geodetic calculations. The `Geodetic::Datum` class provides access to 16 pre-defined geodetic datums.

### Constructor

```ruby
datum = Geodetic::Datum.new(name: 'WGS84')
```

The `name` parameter is case-insensitive and must match one of the 16 available datum names.

Raises `NameError` if the datum name is not recognized.

### Instance Attributes

| Attribute | Type | Description |
|-----------|------|-------------|
| `name`    | String | Uppercase datum name |
| `desc`    | String | Human-readable description |
| `a`       | Float  | Semi-major axis (equatorial radius) in meters |
| `b`       | Float  | Semi-minor axis (polar radius) in meters |
| `f`       | Float  | Flattening (computed as `1.0 / f_inv`) |
| `f_inv`   | Float  | Inverse flattening |
| `e`       | Float  | First eccentricity (computed as `sqrt(e2)`) |
| `e2`      | Float  | First eccentricity squared |

All attributes have both reader and writer accessors.

### WGS84 Constant

The most commonly used datum is available as a pre-built constant:

```ruby
Geodetic::WGS84
# => #<Geodetic::Datum name="WGS84", a=6378137.0, f_inv=298.257223563>
```

This constant is the default datum for all conversion methods throughout the gem.

### Class Methods

#### `Datum.list`

Returns an Array of strings describing each available datum.

```ruby
Geodetic::Datum.list
# => ["AIRY: Airy 1830", "MODIFIED_AIRY: Modified Airy", ..., "WGS84: World Geodetic System 1984"]
```

#### `Datum.get(name)`

Returns a `Datum` instance for the given name. The name is case-insensitive. Raises `NameError` if the datum is not found.

```ruby
datum = Geodetic::Datum.get('WGS84')
# => #<Geodetic::Datum name="WGS84", a=6378137.0, f_inv=298.257223563>
datum.name   # => "WGS84"
datum.desc   # => "World Geodetic System 1984"
datum.a      # => 6378137.0
datum.f_inv  # => 298.257223563
datum.e2     # => 0.00669437999014132
```

### Available Datums

| Name | Description | Semi-Major Axis (a) |
|------|-------------|---------------------|
| `AIRY` | Airy 1830 | 6,377,563.396 m |
| `MODIFIED_AIRY` | Modified Airy | 6,377,340.189 m |
| `AUSTRALIAN_NATIONAL` | Australian National | 6,378,160.0 m |
| `BESSEL_1841` | Bessel 1841 | 6,377,397.155 m |
| `CLARKE_1866` | Clarke 1866 | 6,378,206.4 m |
| `CLARKE_1880` | Clarke 1880 | 6,378,249.145 m |
| `EVEREST_INDIA_1830` | Everest (India 1830) | 6,377,276.345 m |
| `EVEREST_BRUNEI_E_MALAYSIA` | Everest (Brunei & E.Malaysia) | 6,377,298.556 m |
| `EVEREST_W_MALAYSIA_SINGAPORE` | Everest (W.Malaysia & Singapore) | 6,377,304.063 m |
| `GRS_1980` | Geodetic Reference System 1980 | 6,378,137.0 m |
| `HELMERT_1906` | Helmert 1906 | 6,378,200.0 m |
| `HOUGH_1960` | Hough 1960 | 6,378,270.0 m |
| `INTERNATIONAL_1924` | International 1924 | 6,378,388.0 m |
| `SOUTH_AMERICAN_1969` | South American 1969 | 6,378,160.0 m |
| `WGS72` | World Geodetic System 1972 | 6,378,135.0 m |
| `WGS84` | World Geodetic System 1984 | 6,378,137.0 m |

---

## Module Functions

The `Geodetic` module provides two conversion functions available as module methods:

```ruby
Geodetic.deg2rad(180.0)   # => 3.14159265...
Geodetic.rad2deg(Math::PI) # => 180.0
```

| Function | Description |
|----------|-------------|
| `deg2rad(deg)` | Converts degrees to radians. Multiplies by `RAD_PER_DEG`. |
| `rad2deg(rad)` | Converts radians to degrees. Multiplies by `DEG_PER_RAD`. |

---

## Module Constants

| Constant | Value | Description |
|----------|-------|-------------|
| `RAD_PER_DEG` | 0.0174532925199433 | Radians per degree |
| `DEG_PER_RAD` | 57.2957795130823 | Degrees per radian |
| `QUARTER_PI` | 0.785398163397448 | Pi / 4 |
| `HALF_PI` | 1.5707963267949 | Pi / 2 |
| `FEET_PER_METER` | 3.2808399 | International feet per meter |
| `FEET_PER_MILE` | 5280.0 | Feet per statute mile |
| `INCH_PER_FOOT` | 12.0 | Inches per foot |
| `KM_PER_MILE` | 1.609344 | Kilometers per statute mile |
| `MILE_PER_KM` | 0.621371192237334 | Statute miles per kilometer |
| `SM_PER_NM` | 0.868976242 | Statute miles per nautical mile |
| `NM_PER_SM` | 1.15077944789197 | Nautical miles per statute mile |
| `NM_PER_DEG` | 60.0 | Nautical miles per degree of latitude |
| `SM_PER_DEG` | 52.13857452 | Statute miles per degree of latitude |
| `MILES_PER_DEG` | 52.13857452 | Alias for `SM_PER_DEG` |
| `GRAVITY_MS2` | 9.80665 | Standard gravity in m/s^2 |
| `GRAVITY_FS2` | 32.174 | Standard gravity in ft/s^2 |
| `GRAVITY` | 9.80665 | Alias for `GRAVITY_MS2` |
