# Magnetic Declination

## True North vs Magnetic North

All bearings in the Geodetic library are referenced to **true north** (the geographic north pole). This is the standard for GPS-based navigation, GIS systems, and geodetic calculations.

**Magnetic north** is the direction a magnetic compass needle points. It differs from true north by an angle called **magnetic declination** (or magnetic variation). This angle changes with location, altitude, and time.

Geodetic does not currently implement magnetic declination calculations. This document provides practical rules of thumb for users who need to convert between true and magnetic bearings manually.

## Who Needs Magnetic Declination?

Most modern navigation is GPS-based and works entirely in true north. Magnetic declination matters primarily in:

- **Aviation** — runway numbers, VOR navigation, and ATC headings use magnetic bearings
- **Marine navigation** — ship compasses are magnetic; chart courses require declination correction
- **Military land navigation** — magnetic compass backup when GPS is denied or jammed
- **Surveying and land records** — historical property deeds describe boundaries in magnetic bearings of their era
- **Directional drilling** — oil/gas wellbore orientation uses magnetic reference frames

If you are working with GPS coordinates, smartphone apps, or standard GIS workflows, you are already working in true north and do not need declination correction.

## The Conversion

```
Magnetic Bearing = True Bearing - Declination
True Bearing     = Magnetic Bearing + Declination
```

**Convention:** Declination is positive when magnetic north is east of true north, negative when west.

The traditional mnemonic: "East is least, west is best" — subtract east declination, add west declination (when converting true to magnetic). Or just use the sign convention above and it works both ways.

**Example:** Seattle has a declination of approximately +15° (east). A true bearing of 90° (due east) corresponds to a magnetic bearing of 75°.

## Regional Rules of Thumb

These values are approximate as of 2025 and change over time. They are intended for rough manual estimates only.

### North America

| Region | Declination | Direction | Notes |
|--------|------------|-----------|-------|
| Pacific Northwest (Seattle, Portland, Vancouver) | +14° to +16° | East | Compass points east of true north |
| US West Coast (San Francisco, Los Angeles) | +11° to +13° | East | |
| Rocky Mountains (Denver, Salt Lake City) | +7° to +9° | East | |
| Central US (Kansas City, Dallas, Chicago) | +1° to +4° | East | Near the agonic line |
| Agonic line (runs roughly through central US) | 0° | — | True and magnetic north coincide |
| US East Coast (New York, Washington DC) | -10° to -13° | West | Compass points west of true north |
| New England (Boston, Maine) | -14° to -15° | West | |
| Florida | -6° to -7° | West | |
| Alaska (Anchorage) | +14° to +16° | East | Varies significantly across the state |
| Northern Canada | +15° to +30° | East | Increases toward the magnetic pole |
| Eastern Canada (Montreal, Toronto) | -10° to -14° | West | |

### Europe

| Region | Declination | Direction | Notes |
|--------|------------|-----------|-------|
| United Kingdom | -1° to +1° | Near zero | Close to agonic line |
| Western Europe (Paris, Amsterdam, Berlin) | +1° to +4° | East | |
| Scandinavia (Oslo, Stockholm) | +4° to +8° | East | |
| Spain, Portugal | -1° to -3° | West | |
| Eastern Europe (Warsaw, Bucharest) | +6° to +8° | East | |
| Iceland | -12° to -15° | West | Near the magnetic pole path |

### Asia-Pacific

| Region | Declination | Direction | Notes |
|--------|------------|-----------|-------|
| Japan (Tokyo) | -7° to -8° | West | |
| China (Beijing) | -6° to -7° | West | |
| China (Shanghai) | -5° to -6° | West | |
| India (New Delhi) | +1° to +2° | East | Near agonic line |
| Southeast Asia (Singapore, Bangkok) | 0° to +1° | Near zero | |
| Australia (Sydney) | +12° to +13° | East | |
| Australia (Perth) | -1° to -2° | West | |
| New Zealand | +20° to +23° | East | Significant easterly declination |

### South America

| Region | Declination | Direction | Notes |
|--------|------------|-----------|-------|
| Brazil (São Paulo, Rio) | -21° to -23° | West | Among the largest declinations globally |
| Argentina (Buenos Aires) | -8° to -10° | West | |
| Chile (Santiago) | -4° to -5° | West | |
| Colombia (Bogotá) | -6° to -7° | West | |
| Peru (Lima) | -3° to -4° | West | |

### Africa and Middle East

| Region | Declination | Direction | Notes |
|--------|------------|-----------|-------|
| South Africa (Cape Town) | -25° to -27° | West | Very large westerly declination |
| South Africa (Johannesburg) | -18° to -20° | West | |
| East Africa (Nairobi) | +1° to +2° | East | Near agonic line |
| North Africa (Cairo) | +4° to +5° | East | |
| West Africa (Lagos) | -2° to -3° | West | |
| Middle East (Dubai, Riyadh) | +2° to +3° | East | |

## How Fast Does Declination Change?

- The magnetic north pole currently moves approximately **55 km/year**, heading from the Canadian Arctic toward Siberia
- At most locations, declination changes **0.1° to 0.2° per year**
- The rate accelerated around 2000 — prior to that, drift was roughly 15 km/year
- The World Magnetic Model (WMM) is updated every 5 years by NOAA and the British Geological Survey (current: WMM2025, valid 2025-2030)

**Practical consequence:** rules of thumb stay usable for 5-10 years at mid-latitudes. Near the magnetic poles (northern Canada, Antarctica), values can shift significantly faster.

## Authoritative Sources

For precise declination values at a specific location and date:

- **NOAA Magnetic Declination Calculator**: https://www.ngdc.noaa.gov/geomag/calculators/magcalc.shtml
- **World Magnetic Model (WMM2025)**: https://www.ncei.noaa.gov/products/world-magnetic-model
- **International Geomagnetic Reference Field (IGRF)**: provides historical declination data back to 1900
- **Canadian Magnetic Declination Calculator**: https://geomag.nrcan.gc.ca/calc/mdcal-en.php

## Using Declination with Geodetic Bearings

Geodetic's `Bearing` class always returns true north bearings:

```ruby
seattle = Geodetic::Coordinate::LLA.new(lat: 47.6062, lng: -122.3321)
portland = Geodetic::Coordinate::LLA.new(lat: 45.5152, lng: -122.6784)

true_bearing = seattle.bearing_to(portland)
# => Bearing (186.25° true)

# Manual magnetic conversion for Seattle area (~+15° east declination)
magnetic_bearing = true_bearing.degrees - 15.0
# => ~171.25° magnetic
```

## Future: Library Support

Geodetic does not currently compute magnetic declination programmatically. The World Magnetic Model (WMM) could be implemented as a pure Ruby module using NOAA's published spherical harmonic coefficients — no external library required.

A potential API might look like:

```ruby
# Declination at a location and date
Geodetic::MagneticDeclination.at(lat: 47.6, lng: -122.3, date: Date.today)
# => 15.2 (degrees east)

# Convert a Bearing
bearing = seattle.bearing_to(portland)
bearing.to_magnetic(lat: 47.6, lng: -122.3, date: Date.today)
# => Bearing (171.05° magnetic)
```

If this would be useful for your application, please open an issue at https://github.com/madbomber/geodetic/issues describing your use case. Knowing the real-world requirements helps prioritize the right API design.
