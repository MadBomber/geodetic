# Geodetic Examples

Runnable demo scripts showing progressive usage of the Geodetic library. Run any single-file example from the project root:

```bash
ruby -Ilib examples/01_basic_conversions.rb
```

## 01 - Basic Conversions

Converts a single point between LLA, ECEF, UTM, ENU, and NED coordinate systems. Demonstrates roundtrip accuracy and local coordinate frames with a reference point.

## 02 - All Coordinate Systems

Walks through all 18 coordinate systems with cross-system conversion chains. Covers spatial hashes (GH, GH36, HAM, OLC, GEOREF, GARS, H3), areas, and neighbor lookups.

## 03 - Distance Calculations

Demonstrates the `Distance` class: great-circle and straight-line distances, unit conversions (km, mi, ft, nmi), arithmetic, comparison, and cross-system distance calculations.

## 04 - Bearing Calculations

Demonstrates the `Bearing` class: forward azimuth, back azimuth, compass directions (4/8/16-point), elevation angles, chain bearings, and cross-system bearing calculations.

## 05 - Map Rendering

Renders geodetic data on a raster map using the [libgd-gis](https://rubygems.org/gems/libgd-gis) gem. Showcases `Geodetic::Feature` for wrapping coordinates and areas with labels and metadata.

Features demonstrated:

- **Feature objects** with point and polygon geometries
- **Landmark icons** scaled and composited onto the map
- **Polygon rendering** of Central Park's boundary
- **Bearing arrows** with degree labels between landmarks
- **Distance and bearing delegation** through Feature objects
- **UTM conversion** output for each landmark
- **Light/dark theme** switching with macOS system detection

Prerequisites:

```bash
gem install libgd-gis
brew install gd   # macOS
```

Run from the project root:

```bash
ruby -Ilib examples/05_map_rendering/demo.rb
```

CLI flags:

```
--light / --dark       Select basemap theme (default: macOS system setting)
--central-park         Show Central Park polygon (default)
--no-central-park      Hide Central Park polygon
--icon-scale=N         Scale landmark icons (default: 0.5)
-h, --help             Show help
```

Output: `examples/05_map_rendering/nyc_landmarks.png`
