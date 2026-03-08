# frozen_string_literal: true

# Geoid Height and Vertical Datum Support
# Provides conversion between ellipsoidal heights and orthometric heights
#
# NOTE: The geoid height calculations use simplified trigonometric
# approximations, not actual geoid model grid data. Values will differ
# from real EGM96/EGM2008/GEOID18/GEOID12B grids. Suitable for testing
# and demonstration; for production use, integrate real grid data files.

module Geodetic
  class GeoidHeight
    attr_reader :geoid_model, :interpolation_method

    GEOID_MODELS = {
      'EGM96' => {
        name: 'Earth Gravitational Model 1996',
        resolution: 15.0,
        accuracy: 1.0,
        epoch: 1996
      },
      'EGM2008' => {
        name: 'Earth Gravitational Model 2008',
        resolution: 2.5,
        accuracy: 0.5,
        epoch: 2008
      },
      'GEOID18' => {
        name: 'GEOID18 (CONUS)',
        resolution: 1.0,
        accuracy: 0.1,
        region: 'CONUS',
        epoch: 2018
      },
      'GEOID12B' => {
        name: 'GEOID12B (CONUS)',
        resolution: 1.0,
        accuracy: 0.15,
        region: 'CONUS',
        epoch: 2012
      }
    }

    VERTICAL_DATUMS = {
      'NAVD88' => {
        name: 'North American Vertical Datum of 1988',
        region: 'North America',
        type: 'orthometric',
        reference_geoid: 'GEOID18'
      },
      'NGVD29' => {
        name: 'National Geodetic Vertical Datum of 1929',
        region: 'United States',
        type: 'orthometric',
        reference_geoid: 'GEOID12B'
      },
      'MSL' => {
        name: 'Mean Sea Level',
        region: 'Global',
        type: 'orthometric',
        reference_geoid: 'EGM2008'
      },
      'HAE' => {
        name: 'Height Above Ellipsoid',
        region: 'Global',
        type: 'ellipsoidal',
        reference_geoid: nil
      }
    }

    def initialize(geoid_model: 'EGM2008', interpolation_method: 'bilinear')
      @geoid_model = geoid_model
      @interpolation_method = interpolation_method
      validate_model
    end

    def geoid_height_at(lat, lng)
      case @geoid_model
      when 'EGM96'
        calculate_egm96_height(lat, lng)
      when 'EGM2008'
        calculate_egm2008_height(lat, lng)
      when 'GEOID18'
        calculate_geoid18_height(lat, lng)
      when 'GEOID12B'
        calculate_geoid12b_height(lat, lng)
      else
        raise ArgumentError, "Unsupported geoid model: #{@geoid_model}"
      end
    end

    def ellipsoidal_to_orthometric(lat, lng, ellipsoidal_height)
      geoid_height = geoid_height_at(lat, lng)
      ellipsoidal_height - geoid_height
    end

    def orthometric_to_ellipsoidal(lat, lng, orthometric_height)
      geoid_height = geoid_height_at(lat, lng)
      orthometric_height + geoid_height
    end

    def convert_vertical_datum(lat, lng, height, from_datum, to_datum)
      from_info = VERTICAL_DATUMS[from_datum]
      to_info = VERTICAL_DATUMS[to_datum]

      raise ArgumentError, "Unknown vertical datum: #{from_datum}" unless from_info
      raise ArgumentError, "Unknown vertical datum: #{to_datum}" unless to_info

      if from_info[:type] == 'orthometric'
        geoid_model = GeoidHeight.new(geoid_model: from_info[:reference_geoid])
        ellipsoidal_height = geoid_model.orthometric_to_ellipsoidal(lat, lng, height)
      else
        ellipsoidal_height = height
      end

      if to_info[:type] == 'orthometric'
        geoid_model = GeoidHeight.new(geoid_model: to_info[:reference_geoid])
        geoid_model.ellipsoidal_to_orthometric(lat, lng, ellipsoidal_height)
      else
        ellipsoidal_height
      end
    end

    def interpolated_height(lat, lng, height_grid, lat_grid, lng_grid)
      lat_idx = find_grid_index(lat, lat_grid)
      lng_idx = find_grid_index(lng, lng_grid)

      lat1, lat2 = lat_grid[lat_idx], lat_grid[lat_idx + 1]
      lng1, lng2 = lng_grid[lng_idx], lng_grid[lng_idx + 1]

      h11 = height_grid[lat_idx][lng_idx]
      h12 = height_grid[lat_idx][lng_idx + 1]
      h21 = height_grid[lat_idx + 1][lng_idx]
      h22 = height_grid[lat_idx + 1][lng_idx + 1]

      t = (lng - lng1) / (lng2 - lng1)
      u = (lat - lat1) / (lat2 - lat1)

      (1 - t) * (1 - u) * h11 +
        t * (1 - u) * h12 +
        (1 - t) * u * h21 +
        t * u * h22
    end

    def undulation_correction(lat)
      lat_rad = lat * Math::PI / 180.0
      10.0 * Math.sin(2.0 * lat_rad) + 5.0 * Math.sin(4.0 * lat_rad)
    end

    def accuracy_estimate(lat, lng)
      model_info = GEOID_MODELS[@geoid_model]
      base_accuracy = model_info[:accuracy]

      if model_info[:region] == 'CONUS'
        if lat >= 24.0 && lat <= 50.0 && lng >= -125.0 && lng <= -66.0
          return base_accuracy
        else
          return base_accuracy * 3.0
        end
      end

      base_accuracy
    end

    def in_coverage?(lat, lng)
      model_info = GEOID_MODELS[@geoid_model]

      case model_info[:region]
      when 'CONUS'
        lat >= 20.0 && lat <= 55.0 && lng >= -130.0 && lng <= -60.0
      when 'North America'
        lat >= 10.0 && lat <= 85.0 && lng >= -180.0 && lng <= -40.0
      else
        true
      end
    end

    def self.available_models
      GEOID_MODELS.keys
    end

    def self.available_vertical_datums
      VERTICAL_DATUMS.keys
    end

    def model_info
      GEOID_MODELS[@geoid_model]
    end

    private

    def validate_model
      unless GEOID_MODELS.key?(@geoid_model)
        raise ArgumentError, "Unknown geoid model: #{@geoid_model}"
      end
    end

    def find_grid_index(value, grid)
      grid.each_with_index do |grid_val, i|
        if i == grid.length - 1 || value < grid[i + 1]
          return [i, grid.length - 2].min
        end
      end
      0
    end

    def calculate_egm96_height(lat, lng)
      lat_rad = lat * Math::PI / 180.0
      lng_rad = lng * Math::PI / 180.0

      30.0 * Math.sin(2.0 * lat_rad) * Math.cos(lng_rad) +
        15.0 * Math.sin(4.0 * lat_rad) * Math.sin(2.0 * lng_rad) +
        8.0 * Math.cos(3.0 * lat_rad)
    end

    def calculate_egm2008_height(lat, lng)
      base_height = calculate_egm96_height(lat, lng)

      lat_rad = lat * Math::PI / 180.0
      lng_rad = lng * Math::PI / 180.0

      correction = 3.0 * Math.sin(6.0 * lat_rad) * Math.cos(3.0 * lng_rad) +
                   2.0 * Math.cos(8.0 * lat_rad) * Math.sin(4.0 * lng_rad)

      base_height + correction
    end

    def calculate_geoid18_height(lat, lng)
      unless in_coverage?(lat, lng)
        return calculate_egm2008_height(lat, lng)
      end

      base_height = calculate_egm2008_height(lat, lng)

      conus_correction = -2.0 * Math.sin((lat - 40.0) * Math::PI / 20.0) *
                         Math.cos((lng + 95.0) * Math::PI / 30.0)

      base_height + conus_correction
    end

    def calculate_geoid12b_height(lat, lng)
      unless in_coverage?(lat, lng)
        return calculate_egm96_height(lat, lng)
      end

      base_height = calculate_egm96_height(lat, lng)

      conus_correction = -1.5 * Math.sin((lat - 39.0) * Math::PI / 20.0) *
                         Math.cos((lng + 96.0) * Math::PI / 32.0)

      base_height + conus_correction
    end
  end

  module GeoidHeightSupport
    def self.included(base)
      base.extend(ClassMethods)
    end

    module ClassMethods
      def with_geoid_height(geoid_model = 'EGM2008')
        @geoid_model = geoid_model
        self
      end

      def geoid_model
        @geoid_model || 'EGM2008'
      end
    end

    def convert_height_datum(from_datum, to_datum, geoid_model = 'EGM2008')
      return self unless respond_to?(:lat) && respond_to?(:lng) && respond_to?(:alt)

      geoid = GeoidHeight.new(geoid_model: geoid_model)
      new_height = geoid.convert_vertical_datum(self.lat, self.lng, self.alt, from_datum, to_datum)

      self.class.new(lat: self.lat, lng: self.lng, alt: new_height)
    end

    def geoid_height(geoid_model = 'EGM2008')
      return nil unless respond_to?(:lat) && respond_to?(:lng)

      geoid = GeoidHeight.new(geoid_model: geoid_model)
      geoid.geoid_height_at(self.lat, self.lng)
    end

    def orthometric_height(geoid_model = 'EGM2008')
      return nil unless respond_to?(:alt) && respond_to?(:lat) && respond_to?(:lng)

      geoid = GeoidHeight.new(geoid_model: geoid_model)
      geoid.ellipsoidal_to_orthometric(self.lat, self.lng, self.alt)
    end

    def self.from_orthometric_height(lat, lng, orthometric_height, geoid_model = 'EGM2008')
      geoid = GeoidHeight.new(geoid_model: geoid_model)
      geoid.orthometric_to_ellipsoidal(lat, lng, orthometric_height)
    end
  end
end
