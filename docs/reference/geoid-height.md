# Geoid Height Reference

## Geodetic::GeoidHeight

Provides conversion between ellipsoidal heights (height above the reference ellipsoid) and orthometric heights (height above the geoid / mean sea level). Supports multiple geoid models and vertical datums.

### Constructor

```ruby
geoid = Geodetic::GeoidHeight.new(
  geoid_model: 'EGM2008',            # default
  interpolation_method: 'bilinear'    # default
)
```

Raises a RuntimeError if the geoid model is not recognized.

### Attributes

| Attribute | Type | Description |
|-----------|------|-------------|
| `geoid_model` | String | The active geoid model name |
| `interpolation_method` | String | Interpolation method for grid lookups |

---

## Geoid Models

| Model | Full Name | Resolution (arc-min) | Accuracy (m) | Epoch | Region |
|-------|-----------|---------------------|---------------|-------|--------|
| `EGM96` | Earth Gravitational Model 1996 | 15.0 | 1.0 | 1996 | Global |
| `EGM2008` | Earth Gravitational Model 2008 | 2.5 | 0.5 | 2008 | Global |
| `GEOID18` | GEOID18 (CONUS) | 1.0 | 0.1 | 2018 | CONUS |
| `GEOID12B` | GEOID12B (CONUS) | 1.0 | 0.15 | 2012 | CONUS |

Regional models (GEOID18, GEOID12B) fall back to global models for positions outside their coverage area.

---

## Vertical Datums

| Datum | Full Name | Region | Type | Reference Geoid |
|-------|-----------|--------|------|-----------------|
| `NAVD88` | North American Vertical Datum of 1988 | North America | Orthometric | GEOID18 |
| `NGVD29` | National Geodetic Vertical Datum of 1929 | United States | Orthometric | GEOID12B |
| `MSL` | Mean Sea Level | Global | Orthometric | EGM2008 |
| `HAE` | Height Above Ellipsoid | Global | Ellipsoidal | (none) |

---

## Instance Methods

### `geoid_height_at(lat, lng)`

Returns the geoid undulation (separation between ellipsoid and geoid) at the given latitude and longitude, in meters.

```ruby
geoid = Geodetic::GeoidHeight.new(geoid_model: 'EGM2008')
height = geoid.geoid_height_at(38.8977, -77.0365)
```

### `ellipsoidal_to_orthometric(lat, lng, ellipsoidal_height)`

Converts an ellipsoidal height to an orthometric height by subtracting the geoid undulation.

```ruby
orthometric = geoid.ellipsoidal_to_orthometric(38.8977, -77.0365, 100.0)
```

### `orthometric_to_ellipsoidal(lat, lng, orthometric_height)`

Converts an orthometric height to an ellipsoidal height by adding the geoid undulation.

```ruby
ellipsoidal = geoid.orthometric_to_ellipsoidal(38.8977, -77.0365, 65.0)
```

### `convert_vertical_datum(lat, lng, height, from_datum, to_datum)`

Converts a height value between any two vertical datums. Handles the intermediate conversion through ellipsoidal height when both datums are orthometric.

```ruby
navd88_height = geoid.convert_vertical_datum(
  38.8977, -77.0365, 100.0,
  'HAE',     # from Height Above Ellipsoid
  'NAVD88'   # to NAVD88 orthometric
)
```

### `in_coverage?(lat, lng)`

Returns `true` if the given position falls within the coverage area of the current geoid model. Global models always return `true`. CONUS models check for approximate continental US bounds.

```ruby
geoid = Geodetic::GeoidHeight.new(geoid_model: 'GEOID18')
geoid.in_coverage?(40.0, -100.0)  # => true  (within CONUS)
geoid.in_coverage?(51.5, -0.1)    # => false (London, outside CONUS)
```

### `accuracy_estimate(lat, lng)`

Returns the estimated accuracy of the geoid model at the given position, in meters. Regional models return their base accuracy within coverage and 3x the base accuracy outside coverage.

```ruby
geoid.accuracy_estimate(40.0, -100.0)  # => 0.1 (GEOID18 within CONUS)
geoid.accuracy_estimate(51.5, -0.1)    # => 0.3 (GEOID18 outside CONUS)
```

### `model_info`

Returns the full information hash for the current geoid model.

```ruby
geoid.model_info
# => { name: "Earth Gravitational Model 2008", resolution: 2.5, accuracy: 0.5, epoch: 2008 }
```

---

## Class Methods

### `GeoidHeight.available_models`

Returns an array of available geoid model names.

```ruby
Geodetic::GeoidHeight.available_models
# => ["EGM96", "EGM2008", "GEOID18", "GEOID12B"]
```

### `GeoidHeight.available_vertical_datums`

Returns an array of available vertical datum names.

```ruby
Geodetic::GeoidHeight.available_vertical_datums
# => ["NAVD88", "NGVD29", "MSL", "HAE"]
```

---

## Geodetic::GeoidHeightSupport (Mixin)

The `GeoidHeightSupport` module is included in `Geodetic::Coordinate::LLA`, adding geoid-related methods directly to LLA instances.

### Mixin Methods

#### `geoid_height(geoid_model = 'EGM2008')`

Returns the geoid undulation at the LLA position.

```ruby
point = Geodetic::Coordinate::LLA.new(lat: 38.8977, lng: -77.0365, alt: 100.0)
point.geoid_height              # Uses EGM2008
point.geoid_height('GEOID18')   # Uses GEOID18
```

#### `orthometric_height(geoid_model = 'EGM2008')`

Returns the orthometric height (height above geoid) by subtracting the geoid undulation from the LLA altitude.

```ruby
point.orthometric_height  # alt minus geoid undulation
```

#### `convert_height_datum(from_datum, to_datum, geoid_model = 'EGM2008')`

Returns a new LLA with the altitude converted between vertical datums. The original object is not modified.

```ruby
wgs84_point = Geodetic::Coordinate::LLA.new(lat: 40.0, lng: -100.0, alt: 300.0)
navd88_point = wgs84_point.convert_height_datum('HAE', 'NAVD88')
```

### Class Extension

The mixin also extends the including class with a `with_geoid_height` class method and a `geoid_model` reader, though these are primarily for internal use:

```ruby
Geodetic::Coordinate::LLA.with_geoid_height('GEOID18')
Geodetic::Coordinate::LLA.geoid_model  # => 'GEOID18'
```
