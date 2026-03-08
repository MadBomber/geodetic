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
require "geodetic/coordinates/lla"
require "geodetic/coordinates/ecef"
require "geodetic/coordinates/utm"
require "geodetic/coordinates/enu"
require "geodetic/coordinates/ned"
require "geodetic/coordinates/mgrs"
require "geodetic/coordinates/usng"
require "geodetic/coordinates/web_mercator"
require "geodetic/coordinates/ups"
require "geodetic/coordinates/state_plane"
require "geodetic/coordinates/bng"
require "geodetic/coordinates/gh36"
require "geodetic/coordinates/gh"
require "geodetic/coordinates/ham"
require "geodetic/coordinates/olc"
```

You only need to require the types you plan to construct directly. Conversion methods handle their own requires internally.

## Verify the Installation

```ruby
require "geodetic"
require "geodetic/coordinates/lla"

lla = Geodetic::Coordinates::LLA.new(lat: 47.6205, lng: -122.3493, alt: 184.0)
puts lla.to_s
#=> "47.6205, -122.3493, 184.0"
```
