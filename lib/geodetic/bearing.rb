# frozen_string_literal: true

module Geodetic
  class Bearing
    include Comparable

    COMPASS_16 = %w[N NNE NE ENE E ESE SE SSE S SSW SW WSW W WNW NW NNW].freeze
    COMPASS_8  = %w[N NE E SE S SW W NW].freeze
    COMPASS_4  = %w[N E S W].freeze

    attr_reader :degrees

    def initialize(degrees)
      @degrees = degrees.to_f % 360.0
    end

    def to_f
      @degrees
    end

    def to_i
      @degrees.to_i
    end

    def to_radians
      @degrees * RAD_PER_DEG
    end

    # Back azimuth (reverse bearing)
    def reverse
      Bearing.new(@degrees + 180.0)
    end

    # Compass direction string.
    # points: 4 (N/E/S/W), 8 (N/NE/E/...), or 16 (N/NNE/NE/ENE/...)
    def to_compass(points: 16)
      case points
      when 4  then COMPASS_4[(((@degrees + 45.0) % 360.0) / 90.0).to_i]
      when 8  then COMPASS_8[(((@degrees + 22.5) % 360.0) / 45.0).to_i]
      when 16 then COMPASS_16[(((@degrees + 11.25) % 360.0) / 22.5).to_i]
      else raise ArgumentError, "points must be 4, 8, or 16"
      end
    end

    def to_s(precision = 4)
      precision = precision.to_i
      if precision == 0
        "#{@degrees.round}°"
      else
        format("%.#{precision}f°", @degrees)
      end
    end

    def inspect
      "#<Geodetic::Bearing #{to_s} (#{to_compass})>"
    end

    def <=>(other)
      case other
      when Bearing then @degrees <=> other.degrees
      when Numeric then @degrees <=> other.to_f
      end
    end

    # Bearing - Bearing => Float (angular difference)
    # Bearing - Numeric => Bearing (subtract degrees)
    def -(other)
      case other
      when Bearing then @degrees - other.degrees
      when Numeric then Bearing.new(@degrees - other)
      else raise ArgumentError, "Cannot subtract #{other.class} from Bearing"
      end
    end

    # Bearing + Numeric => Bearing
    def +(other)
      case other
      when Numeric then Bearing.new(@degrees + other)
      else raise ArgumentError, "Cannot add #{other.class} to Bearing"
      end
    end

    def coerce(other)
      case other
      when Numeric then [other, @degrees]
      else raise TypeError, "#{other.class} can't be coerced into Bearing"
      end
    end

    def zero?
      @degrees == 0.0
    end
  end
end
