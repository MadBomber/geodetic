# frozen_string_literal: true

module Geodetic
  RAD_PER_DEG = 0.0174532925199433
  DEG_PER_RAD = 57.2957795130823

  class Datum
    ELLIPSES = {
      'AIRY'                        => { desc: 'Airy 1830',                       a: 6377563.396, f_inv: 299.3249647,   b: 6356256.9092444032, e2: 0.00667053999776051 },
      'MODIFIED_AIRY'               => { desc: 'Modified Airy',                   a: 6377340.189, f_inv: 299.3249647,   b: 6356034.4479456525, e2: 0.00667053999776060 },
      'AUSTRALIAN_NATIONAL'         => { desc: 'Australian National',             a: 6378160.0,   f_inv: 298.25,        b: 6356774.7191953063, e2: 0.00669454185458760 },
      'BESSEL_1841'                 => { desc: 'Bessel 1841',                     a: 6377397.155, f_inv: 299.1528128,   b: 6356078.9628181886, e2: 0.00667437223180205 },
      'CLARKE_1866'                 => { desc: 'Clarke 1866',                     a: 6378206.4,   f_inv: 294.9786982,   b: 6356583.7999989809, e2: 0.00676865799760959 },
      'CLARKE_1880'                 => { desc: 'Clarke 1880',                     a: 6378249.145, f_inv: 293.465,       b: 6356514.8695497755, e2: 0.00680351128284912 },
      'EVEREST_INDIA_1830'          => { desc: 'Everest(India 1830)',             a: 6377276.345, f_inv: 300.8017,      b: 6356075.4131402392, e2: 0.00663784663019987 },
      'EVEREST_BRUNEI_E_MALAYSIA'   => { desc: 'Everest(Brunei & E.Malaysia)',    a: 6377298.556, f_inv: 300.8017,      b: 6356097.5503008962, e2: 0.00663784663019965 },
      'EVEREST_W_MALAYSIA_SINGAPORE'=> { desc: 'Everest(W.Malaysia & Singapore)', a: 6377304.063, f_inv: 300.8017,      b: 6356103.0389931547, e2: 0.00663784663019970 },
      'GRS_1980'                    => { desc: 'Geodetic Reference System 1980',  a: 6378137.0,   f_inv: 298.257222101, b: 6356752.3141403561, e2: 0.00669438002290069 },
      'HELMERT_1906'                => { desc: 'Helmert 1906',                    a: 6378200.0,   f_inv: 298.30,        b: 6356818.1696278909, e2: 0.00669342162296610 },
      'HOUGH_1960'                  => { desc: 'Hough 1960',                      a: 6378270.0,   f_inv: 297.00,        b: 6356794.3434343431, e2: 0.00672267002233347 },
      'INTERNATIONAL_1924'          => { desc: 'International 1924',              a: 6378388.0,   f_inv: 297.00,        b: 6356911.9461279465, e2: 0.00672267002233323 },
      'SOUTH_AMERICAN_1969'         => { desc: 'South American 1969',             a: 6378160.0,   f_inv: 298.25,        b: 6356774.7191953063, e2: 0.00669454185458760 },
      'WGS72'                       => { desc: 'World Geodetic System 1972',      a: 6378135.0,   f_inv: 298.26,        b: 6356750.5200160937, e2: 0.00669431777826668 },
      'WGS84'                       => { desc: 'World Geodetic System 1984',      a: 6378137.0,   f_inv: 298.257223563, b: 6356752.3142451793, e2: 0.00669437999014132 },
    }.freeze

    attr_reader :name, :desc, :a, :f, :f_inv, :b, :e, :e2

    def initialize(name:)
      @name = name.upcase
      raise NameError, "Unknown datum: #{@name}" unless ELLIPSES.key?(@name)
      data   = ELLIPSES[@name]
      @desc  = data[:desc]
      @a     = data[:a]
      @f_inv = data[:f_inv]
      @f     = 1.0 / @f_inv
      @b     = data[:b]
      @e2    = data[:e2]
      @e     = Math.sqrt(@e2)
    end

    def self.list
      ELLIPSES.map { |name, data| "#{name}: #{data[:desc]}" }
    end

    def self.get(datum_name)
      new(name: datum_name)
    end
  end

  WGS84 = Datum.new(name: 'WGS84')

  module_function

  def deg2rad(deg)
    deg * RAD_PER_DEG
  end

  def rad2deg(rad)
    rad * DEG_PER_RAD
  end
end
