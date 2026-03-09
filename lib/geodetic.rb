# frozen_string_literal: true

require_relative "geodetic/version"
require_relative "geodetic/datum"
require_relative "geodetic/distance"
require_relative "geodetic/bearing"
require_relative "geodetic/geoid_height"
require_relative "geodetic/coordinate"
require_relative "geodetic/areas"
require_relative "geodetic/path"
require_relative "geodetic/feature"

module Geodetic
  class Error < StandardError; end
end
