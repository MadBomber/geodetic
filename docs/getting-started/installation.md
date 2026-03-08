# Installation

## Requirements

Geodetic is tested with **Ruby 4.0.1**. It has no runtime dependencies beyond the Ruby standard library.

## Add to Your Gemfile

```ruby
gem "geodetic"
```

Then run:

```sh
bundle install
```

## Or Install Directly

```sh
gem install geodetic
```

## Require the Gem

The simplest way to load Geodetic is to require the top-level module:

```ruby
require "geodetic"
```

This loads all modules, coordinate classes, and support classes eagerly.

## Requiring Specific Coordinate Types

If you want to use a coordinate class directly without going through a conversion, require it explicitly:

```ruby
require "geodetic"
require "geodetic/coordinate/lla"
require "geodetic/coordinate/ecef"
require "geodetic/coordinate/utm"
require "geodetic/coordinate/enu"
require "geodetic/coordinate/ned"
require "geodetic/coordinate/mgrs"
require "geodetic/coordinate/usng"
require "geodetic/coordinate/web_mercator"
require "geodetic/coordinate/ups"
require "geodetic/coordinate/state_plane"
require "geodetic/coordinate/bng"
require "geodetic/coordinate/gh36"
require "geodetic/coordinate/gh"
require "geodetic/coordinate/ham"
require "geodetic/coordinate/olc"
```

You only need to require the types you plan to construct directly. Conversion methods handle their own requires internally.

## Verify the Installation

```ruby
require "geodetic"
require "geodetic/coordinate/lla"

lla = Geodetic::Coordinate::LLA.new(lat: 47.6205, lng: -122.3493, alt: 184.0)
puts lla.to_s
#=> "47.6205, -122.3493, 184.0"
```
