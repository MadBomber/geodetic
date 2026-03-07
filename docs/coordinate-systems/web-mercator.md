# Geodetic::Coordinates::WebMercator

## Web Mercator (EPSG:3857)

Web Mercator is the de facto standard projection used by major web mapping platforms including Google Maps, OpenStreetMap, and Bing Maps. It projects the Earth onto a square grid using a spherical Mercator projection, making it well-suited for tiled map rendering.

## Constructor

```ruby
point = Geodetic::Coordinates::WebMercator.new(x: 0.0, y: 0.0)
```

Parameters `x` and `y` are specified in **meters** from the projection origin (the intersection of the Equator and the Prime Meridian).

## Constants

| Constant | Description |
|---|---|
| `EARTH_RADIUS` | Radius of the Earth used for projection calculations |
| `ORIGIN_SHIFT` | Half the circumference of the Earth at the Equator; defines the extent of the projected coordinate space |
| `MAX_LATITUDE` | Maximum representable latitude (~85.051°); the projection is undefined beyond this limit |

## Tile Coordinate Methods

Convert between Web Mercator coordinates and map tile indices at a given zoom level.

```ruby
tile_x, tile_y = point.to_tile_coordinates(zoom)

point = Geodetic::Coordinates::WebMercator.from_tile_coordinates(x, y, zoom)
```

## Pixel Coordinate Methods

Convert between Web Mercator coordinates and pixel positions at a given zoom level and tile size.

```ruby
pixel_x, pixel_y = point.to_pixel_coordinates(zoom, tile_size)

point = Geodetic::Coordinates::WebMercator.from_pixel_coordinates(x, y, zoom, tile_size)
```

## Tile Bounds

Retrieve the bounding box of a specific tile.

```ruby
bounds = Geodetic::Coordinates::WebMercator.tile_bounds(tile_x, tile_y, zoom)
```

## Validation and Utility Methods

| Method | Description |
|---|---|
| `valid?` | Returns `true` if the coordinates fall within the valid Web Mercator extent |
| `clamp!` | Clamps coordinates to the valid range, modifying the object in place |
| `distance_to(other)` | Computes the distance in meters to another `WebMercator` point |
