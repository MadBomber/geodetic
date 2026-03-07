# frozen_string_literal: true

module Geodetic
  class Distance
    include Comparable

    UNITS = {
      meters:         { factor: 1.0,          abbr: "m"   },
      kilometers:     { factor: 1000.0,       abbr: "km"  },
      centimeters:    { factor: 0.01,         abbr: "cm"  },
      millimeters:    { factor: 0.001,        abbr: "mm"  },
      miles:          { factor: 1609.344,     abbr: "mi"  },
      yards:          { factor: 0.9144,       abbr: "yd"  },
      feet:           { factor: 0.3048,       abbr: "ft"  },
      inches:         { factor: 0.0254,       abbr: "in"  },
      nautical_miles: { factor: 1852.0,       abbr: "nmi" },
    }.freeze

    attr_reader :meters, :unit

    def initialize(meters, unit: :meters)
      @meters = meters.to_f
      @unit = unit
    end

    # Display value in current unit
    def to_f
      @meters / UNITS[@unit][:factor]
    end

    def to_i
      to_f.to_i
    end

    def to_s
      "#{to_f} #{UNITS[@unit][:abbr]}"
    end

    def inspect
      "#<Geodetic::Distance #{to_s} (#{@meters} m)>"
    end

    # Comparison uses meters internally
    def <=>(other)
      case other
      when Distance then @meters <=> other.meters
      when Numeric  then @meters <=> (other * UNITS[@unit][:factor])
      end
    end

    # Arithmetic: preserves the receiver's display unit.
    #             Distance op Numeric  => numeric is in the receiver's display unit.
    def +(other)
      Distance.new(@meters + other_to_meters(other), unit: @unit)
    end

    def -(other)
      Distance.new(@meters - other_to_meters(other), unit: @unit)
    end

    def *(other)
      case other
      when Numeric then Distance.new(@meters * other, unit: @unit)
      else raise ArgumentError, "Cannot multiply Distance by #{other.class}"
      end
    end

    def /(other)
      case other
      when Distance then @meters / other.meters  # ratio, returns Float
      when Numeric  then Distance.new(@meters / other, unit: @unit)
      else raise ArgumentError, "Cannot divide Distance by #{other.class}"
      end
    end

    def -@
      Distance.new(-@meters, unit: @unit)
    end

    def abs
      Distance.new(@meters.abs, unit: @unit)
    end

    def zero?
      @meters == 0.0
    end

    # Allow Numeric * Distance
    def coerce(other)
      case other
      when Numeric then [other, @meters]
      else raise TypeError, "#{other.class} can't be coerced into Distance"
      end
    end

    # Unit conversion methods — each returns a new Distance with that display unit
    UNITS.each_key do |unit_name|
      define_method("to_#{unit_name}") do
        Distance.new(@meters, unit: unit_name)
      end
    end

    # Construction from any unit
    UNITS.each do |unit_name, config|
      define_singleton_method(unit_name) do |value|
        new(value.to_f * config[:factor], unit: unit_name)
      end
    end

    # Convenience aliases
    class << self
      alias_method :m,   :meters
      alias_method :km,  :kilometers
      alias_method :cm,  :centimeters
      alias_method :mm,  :millimeters
      alias_method :mi,  :miles
      alias_method :yd,  :yards
      alias_method :ft,  :feet
      alias_method :nmi, :nautical_miles
    end

    alias_method :to_m,   :to_meters
    alias_method :to_km,  :to_kilometers
    alias_method :to_cm,  :to_centimeters
    alias_method :to_mm,  :to_millimeters
    alias_method :to_mi,  :to_miles
    alias_method :to_yd,  :to_yards
    alias_method :to_ft,  :to_feet
    alias_method :to_nmi, :to_nautical_miles

    private

    def other_to_meters(other)
      case other
      when Distance then other.meters
      when Numeric  then other.to_f * UNITS[@unit][:factor]
      else raise ArgumentError, "Cannot convert #{other.class} to Distance"
      end
    end
  end
end
