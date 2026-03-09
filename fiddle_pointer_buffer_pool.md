# H3 Fiddle Pointer Buffer Pool Optimization

## Problem

Every H3 C function call in `lib/geodetic/coordinate/h3.rb` allocates fresh `Fiddle::Pointer` objects that are immediately discarded after use. At high call volumes (1M+ conversions), this creates hundreds of thousands of short-lived heap objects and GC pressure.

## Affected Methods

| Method | Pointers Allocated | Sizes |
|--------|-------------------|-------|
| `lat_lng_to_cell` | 2 | `SIZEOF_LATLNG` (16B) + `SIZEOF_H3INDEX` (8B) |
| `cell_to_lat_lng` | 1 | `SIZEOF_LATLNG` (16B) |
| `cell_to_boundary` | 1 | `SIZEOF_CELL_BOUNDARY` (168B) |
| `grid_disk` | 2 | `SIZEOF_INT64` (8B) + variable |
| `cell_area_m2` | 1 | `SIZEOF_DOUBLE` (8B) |
| `cell_to_parent` | 1 | `SIZEOF_H3INDEX` (8B) |
| `cell_to_children` | 2 | `SIZEOF_INT64` (8B) + variable |

## Proposed Solution

Pre-allocate thread-local reusable buffers for fixed-size structs. Variable-size buffers (`grid_disk` output, `cell_to_children` output) cannot be pre-allocated since their size depends on input.

### Thread-Local Buffer Helper

```ruby
module LibH3
  def self.thread_buffer(name, size)
    key = :"geodetic_h3_#{name}"
    Thread.current[key] ||= Fiddle::Pointer.malloc(size)
  end
end
```

### Before (current code)

```ruby
def self.lat_lng_to_cell(lat_rad, lng_rad, resolution)
  require_library!
  latlng = Fiddle::Pointer.malloc(SIZEOF_LATLNG, Fiddle::RUBY_FREE)
  latlng[0, SIZEOF_LATLNG] = [lat_rad, lng_rad].pack('d2')
  out = Fiddle::Pointer.malloc(SIZEOF_H3INDEX, Fiddle::RUBY_FREE)
  err = F_LAT_LNG_TO_CELL.call(latlng, resolution, out)
  raise ArgumentError, "H3 latLngToCell error (code #{err})" unless err == 0
  out[0, SIZEOF_H3INDEX].unpack1('Q')
end
```

### After (with buffer reuse)

```ruby
def self.lat_lng_to_cell(lat_rad, lng_rad, resolution)
  require_library!
  latlng = thread_buffer(:latlng, SIZEOF_LATLNG)
  latlng[0, SIZEOF_LATLNG] = [lat_rad, lng_rad].pack('d2')
  out = thread_buffer(:h3index, SIZEOF_H3INDEX)
  err = F_LAT_LNG_TO_CELL.call(latlng, resolution, out)
  raise ArgumentError, "H3 latLngToCell error (code #{err})" unless err == 0
  out[0, SIZEOF_H3INDEX].unpack1('Q')
end

def self.cell_to_lat_lng(h3_index)
  require_library!
  latlng = thread_buffer(:latlng, SIZEOF_LATLNG)
  err = F_CELL_TO_LAT_LNG.call(h3_index, latlng)
  raise ArgumentError, "H3 cellToLatLng error (code #{err})" unless err == 0
  lat_rad, lng_rad = latlng[0, SIZEOF_LATLNG].unpack('d2')
  { lat: lat_rad * DEG_PER_RAD, lng: lng_rad * DEG_PER_RAD }
end

def self.cell_to_boundary(h3_index)
  require_library!
  cb = thread_buffer(:cell_boundary, SIZEOF_CELL_BOUNDARY)
  err = F_CELL_TO_BOUNDARY.call(h3_index, cb)
  raise ArgumentError, "H3 cellToBoundary error (code #{err})" unless err == 0
  num_verts = cb[0, 4].unpack1('i')
  verts = cb[8, num_verts * SIZEOF_LATLNG].unpack("d#{num_verts * 2}")
  (0...num_verts).map do |i|
    { lat: verts[i * 2] * DEG_PER_RAD, lng: verts[i * 2 + 1] * DEG_PER_RAD }
  end
end

def self.cell_area_m2(h3_index)
  require_library!
  out = thread_buffer(:double, Fiddle::SIZEOF_DOUBLE)
  err = F_CELL_AREA_M2.call(h3_index, out)
  raise ArgumentError, "H3 cellAreaM2 error (code #{err})" unless err == 0
  out[0, Fiddle::SIZEOF_DOUBLE].unpack1('d')
end

def self.cell_to_parent(h3_index, parent_res)
  require_library!
  out = thread_buffer(:h3index, SIZEOF_H3INDEX)
  err = F_CELL_TO_PARENT.call(h3_index, parent_res, out)
  raise ArgumentError, "H3 cellToParent error (code #{err})" unless err == 0
  out[0, SIZEOF_H3INDEX].unpack1('Q')
end
```

### Reusable Fixed-Size Buffers

| Buffer Name | Size | Used By |
|-------------|------|---------|
| `:latlng` | 16 bytes | `lat_lng_to_cell`, `cell_to_lat_lng` |
| `:h3index` | 8 bytes | `lat_lng_to_cell`, `cell_to_parent` |
| `:cell_boundary` | 168 bytes | `cell_to_boundary` |
| `:int64` | 8 bytes | `grid_disk`, `cell_to_children` |
| `:double` | 8 bytes | `cell_area_m2` |

## Thread Safety

Using `Thread.current` ensures each thread gets its own buffer. No mutex needed. Buffers are overwritten on each call, so stale data is not a concern — the C function fills the buffer before Ruby reads it.

## When to Implement

This optimization is only worthwhile for high-volume batch processing (1M+ H3 conversions). For typical usage the current per-call allocation is fine and simpler to reason about.

## Not Optimizable

The `grid_disk` and `cell_to_children` output buffers are variable-sized (depends on `k` ring size or child resolution) and must be allocated per call.
