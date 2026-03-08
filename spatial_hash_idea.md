# SpatialHash Base Class Refactoring

## Problem

GH36, GH, HAM, and OLC (plus future GEOREF and GARS) are all 2D rectangular-area coordinate systems that encode lat/lng into a string. They share ~30 identical conversion methods per class, totaling ~150 lines of boilerplate each. Adding a new spatial hash system requires copy-pasting all of this.

## Shared Pattern

All spatial hash classes:
- Are **immutable** (no setters)
- Store a **string code** as the primary value
- Encode/decode **lat/lng** to/from a string
- Represent a **rectangular cell** (bounding box) with the coordinate as the cell midpoint
- Have **no altitude** (always 0.0)
- Convert through **LLA** as the intermediary for all other coordinate systems
- Provide `neighbors`, `to_area`, `precision_in_meters`, `to_slug`, `valid?`, `==`
- Provide `to_a` → `[lat, lng]`, `from_array([lat, lng])`, `from_string(str)`

## 100% Duplicate Methods (identical across all 4 classes)

### Instance conversion methods (chain through `to_lla`)
- `to_ecef(datum = WGS84)` → `to_lla(datum).to_ecef(datum)`
- `to_utm(datum = WGS84)` → `to_lla(datum).to_utm(datum)`
- `to_enu(reference_lla, datum = WGS84)` → `to_lla(datum).to_enu(reference_lla)`
- `to_ned(reference_lla, datum = WGS84)` → `to_lla(datum).to_ned(reference_lla)`
- `to_mgrs(datum = WGS84, mgrs_precision = 5)` → `MGRS.from_lla(to_lla(datum), datum, mgrs_precision)`
- `to_usng(datum = WGS84, usng_precision = 5)` → `USNG.from_lla(to_lla(datum), datum, usng_precision)`
- `to_web_mercator(datum = WGS84)` → `WebMercator.from_lla(to_lla(datum), datum)`
- `to_ups(datum = WGS84)` → `UPS.from_lla(to_lla(datum), datum)`
- `to_state_plane(zone_code, datum = WGS84)` → `StatePlane.from_lla(to_lla(datum), zone_code, datum)`
- `to_bng(datum = WGS84)` → `BNG.from_lla(to_lla(datum), datum)`

### Class conversion methods (all follow `new(coord, precision: precision)`)
- `from_ecef`, `from_utm`, `from_enu`, `from_ned`, `from_mgrs`, `from_usng`
- `from_web_mercator`, `from_ups`, `from_state_plane`, `from_bng`

### Cross-hash conversions (each class converts to/from the other hash systems)
- `to_gh36` / `from_gh36`, `to_gh` / `from_gh`, `to_ham` / `from_ham`, `to_olc` / `from_olc`
- Pattern: `to_X(datum, x_precision:)` → `X.new(to_lla(datum), precision: x_precision)`
- Pattern: `from_X(x_coord, datum, precision)` → `new(x_coord, precision: precision)`

### Utility methods
- `from_lla(lla_coord, datum, precision)` → `new(lla_coord, precision: precision)`
- `from_array(array)` → `new(LLA.new(lat: array[0].to_f, lng: array[1].to_f))`
- `from_string(string)` → `new(string.strip)`
- `to_a` → `[decoded_lat, decoded_lng]`
- `to_slug` → alias for `to_s`
- `to_area` → `Areas::Rectangle` from `decode_bounds`
- `precision_in_meters` → `{ lat:, lng: }` from bounds + cosine correction (GH36 differs slightly)
- `neighbors` → 8 adjacent cells from bounds + re-encode (GH36 differs slightly)
- `==` → string comparison on internal code value

## What Stays Unique Per Subclass

| Concern | Why it can't be shared |
|---------|----------------------|
| `encode(lat, lng, precision)` | The actual encoding algorithm |
| `decode(code)` → `{lat:, lng:}` | The actual decoding algorithm |
| `decode_bounds(code)` → bounding box | Algorithm-specific bounds calculation |
| `validate_code!(string)` | Different rules (HAM: even length 2-8; OLC: `+` at position 8) |
| `normalize(string)` | GH36: none, GH: downcase, HAM: mixed case, OLC: upcase |
| `to_s(truncate_to)` | HAM rounds to even, OLC re-encodes, GH/GH36 just slice |
| `valid?` | Different validation logic per system |
| `precision` | Different meaning per system |
| Constants | Alphabet, directions, grid dimensions, default precision |

## Proposed Base Class

```ruby
module Geodetic
  module Coordinate
    class SpatialHash
      require_relative '../datum'

      # --- Subclass contract ---
      # MUST implement:
      #   encode(lat, lng, precision) → String
      #   decode(code_string)         → { lat:, lng: }
      #   decode_bounds(code_string)  → { min_lat:, max_lat:, min_lng:, max_lng: }
      #   validate_code!(string)      → raises ArgumentError or nil
      #   normalize(string)           → String (normalized code)
      #   code_value                  → String (the stored code: @geohash, @locator, @code)
      #   self.default_precision      → Integer
      #
      # MAY override:
      #   to_s(truncate_to)
      #   valid?
      #   neighbors
      #   precision_in_meters
      #   precision

      DIRECTIONS = {
        N:  [ 1,  0], S:  [-1,  0],
        E:  [ 0,  1], W:  [ 0, -1],
        NE: [ 1,  1], NW: [ 1, -1],
        SE: [-1,  1], SW: [-1, -1]
      }.freeze

      def initialize(source, precision: self.class.default_precision)
        case source
        when String
          normalized = normalize(source.strip)
          validate_code!(normalized)
          set_code(normalized)
        when LLA
          set_code(encode(source.lat, source.lng, precision))
        else
          if source.respond_to?(:to_lla)
            lla = source.to_lla
            set_code(encode(lla.lat, lla.lng, precision))
          else
            raise ArgumentError,
              "Expected a code String or coordinate object, got #{source.class}"
          end
        end
      end

      def to_lla(datum = WGS84)
        coords = decode(code_value)
        lat = coords[:lat].clamp(-90.0, 90.0)
        lng = coords[:lng].clamp(-180.0, 180.0)
        LLA.new(lat: lat, lng: lng, alt: 0.0)
      end

      def to_a
        coords = decode(code_value)
        [coords[:lat], coords[:lng]]
      end

      def self.from_lla(lla_coord, datum = WGS84, precision = default_precision)
        new(lla_coord, precision: precision)
      end

      def self.from_array(array)
        new(LLA.new(lat: array[0].to_f, lng: array[1].to_f))
      end

      def self.from_string(string)
        new(string.strip)
      end

      alias_method :to_slug, :to_s

      def ==(other)
        return false unless other.is_a?(self.class)
        code_value == other.code_value
      end

      def to_area
        bb = decode_bounds(code_value)
        nw = LLA.new(lat: bb[:max_lat], lng: bb[:min_lng], alt: 0.0)
        se = LLA.new(lat: bb[:min_lat], lng: bb[:max_lng], alt: 0.0)
        Areas::Rectangle.new(nw: nw, se: se)
      end

      def precision_in_meters
        bb = decode_bounds(code_value)
        lat_center = (bb[:min_lat] + bb[:max_lat]) / 2.0
        lat_meters_per_deg = 111_320.0
        lng_meters_per_deg = 111_320.0 * Math.cos(lat_center * Math::PI / 180.0)
        {
          lat: (bb[:max_lat] - bb[:min_lat]) * lat_meters_per_deg,
          lng: (bb[:max_lng] - bb[:min_lng]) * lng_meters_per_deg
        }
      end

      def neighbors
        bb = decode_bounds(code_value)
        lat_step = bb[:max_lat] - bb[:min_lat]
        lng_step = bb[:max_lng] - bb[:min_lng]
        center_lat = (bb[:min_lat] + bb[:max_lat]) / 2.0
        center_lng = (bb[:min_lng] + bb[:max_lng]) / 2.0
        len = precision

        DIRECTIONS.each_with_object({}) do |(dir, delta), result|
          nlat = (center_lat + delta[0] * lat_step).clamp(-89.99999999, 89.99999999)
          nlng = center_lng + delta[1] * lng_step
          nlng += 360.0 if nlng < -180.0
          nlng -= 360.0 if nlng > 180.0
          result[dir] = self.class.new(LLA.new(lat: nlat, lng: nlng), precision: len)
        end
      end

      # --- All conversion methods (provided by base) ---

      def to_ecef(datum = WGS84)        = to_lla(datum).to_ecef(datum)
      def to_utm(datum = WGS84)         = to_lla(datum).to_utm(datum)
      def to_enu(ref, datum = WGS84)    = to_lla(datum).to_enu(ref)
      def to_ned(ref, datum = WGS84)    = to_lla(datum).to_ned(ref)
      def to_web_mercator(datum = WGS84) = WebMercator.from_lla(to_lla(datum), datum)
      def to_ups(datum = WGS84)         = UPS.from_lla(to_lla(datum), datum)
      def to_bng(datum = WGS84)         = BNG.from_lla(to_lla(datum), datum)
      def to_mgrs(datum = WGS84, p = 5) = MGRS.from_lla(to_lla(datum), datum, p)
      def to_usng(datum = WGS84, p = 5) = USNG.from_lla(to_lla(datum), datum, p)
      def to_state_plane(zone, datum = WGS84) = StatePlane.from_lla(to_lla(datum), zone, datum)

      # Class-level from_* methods generated similarly...
      # Cross-hash to_*/from_* generated from a registry of SpatialHash subclasses...
    end
  end
end
```

## Cross-Hash Registry (auto-generates to_*/from_* between hash systems)

When a new SpatialHash subclass is defined, it registers itself:

```ruby
class SpatialHash
  @registry = {}  # { gh: GH, gh36: GH36, ham: HAM, olc: OLC, ... }

  def self.register(short_name, klass, default_precision:)
    @registry[short_name] = { klass: klass, precision: default_precision }
  end

  # Generates: to_gh, to_gh36, to_ham, to_olc, from_gh, from_gh36, etc.
  # Adding GEOREF = zero boilerplate in GH, GH36, HAM, OLC
end
```

## Impact

- **Current**: ~150 lines of boilerplate per spatial hash class
- **After**: Each subclass is ~80-100 lines (just encode/decode/validate/constants)
- **Adding GEOREF or GARS**: Implement encode/decode/validate only; conversions are free
- **No changes needed in existing spatial hash classes when adding a new one**

## Risks

- Slightly harder to read individual class files (must understand inheritance)
- GH36's `neighbors` uses a more efficient matrix-based algorithm (could keep as override)
- GH36's `precision_in_meters` uses a formula instead of bounds (could keep as override)
- Must ensure `attr_reader` for the code attribute still works (each class uses a different name: `geohash`, `locator`, `code`)

## Migration Path

1. Create `lib/geodetic/coordinate/spatial_hash.rb` base class
2. Migrate one class (e.g., OLC) to inherit from it — verify all 91 tests pass
3. Migrate GH, HAM, GH36 one at a time — verify full suite after each
4. Implement GEOREF and GARS as new subclasses
5. Consider unifying the attribute name to `code_value` (breaking change) or keep per-class `attr_reader` with `code_value` as the internal interface
