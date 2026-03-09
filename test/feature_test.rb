# frozen_string_literal: true

require "test_helper"

class FeatureTest < Minitest::Test
  LLA     = Geodetic::Coordinate::LLA
  Feature = Geodetic::Feature
  Circle  = Geodetic::Areas::Circle
  Polygon = Geodetic::Areas::Polygon
  Distance = Geodetic::Distance

  # ── Construction ──────────────────────────────────────────────

  def test_new_with_coordinate
    pt = LLA.new(lat: 40.6892, lng: -74.0445, alt: 0)
    f  = Feature.new(label: "Statue of Liberty", geometry: pt)

    assert_equal "Statue of Liberty", f.label
    assert_equal pt, f.geometry
    assert_equal({}, f.metadata)
  end

  def test_new_with_area
    center = LLA.new(lat: 40.7829, lng: -73.9654, alt: 0)
    area   = Circle.new(centroid: center, radius: 500)
    f      = Feature.new(label: "Central Park", geometry: area)

    assert_equal "Central Park", f.label
    assert_equal area, f.geometry
  end

  def test_new_with_metadata
    pt = LLA.new(lat: 40.7484, lng: -73.9857, alt: 0)
    f  = Feature.new(label: "Empire State", geometry: pt, metadata: { category: "building", floors: 102 })

    assert_equal "building", f.metadata[:category]
    assert_equal 102, f.metadata[:floors]
  end

  # ── Mutability ───────────────────────────────────────────────

  def test_name_is_mutable
    pt = LLA.new(lat: 40.0, lng: -74.0, alt: 0)
    f  = Feature.new(label: "Old Name", geometry: pt)

    f.label = "New Name"
    assert_equal "New Name", f.label
  end

  def test_geometry_is_mutable
    pt1 = LLA.new(lat: 40.0, lng: -74.0, alt: 0)
    pt2 = LLA.new(lat: 41.0, lng: -73.0, alt: 0)
    f   = Feature.new(label: "Test", geometry: pt1)

    f.geometry = pt2
    assert_equal pt2, f.geometry
  end

  def test_metadata_is_mutable
    pt = LLA.new(lat: 40.0, lng: -74.0, alt: 0)
    f  = Feature.new(label: "Test", geometry: pt)

    f.metadata[:added_later] = true
    assert f.metadata[:added_later]
  end

  # ── Delegation: coordinate geometry ──────────────────────────

  def test_distance_to_between_coordinate_features
    liberty = Feature.new(label: "Statue of Liberty", geometry: LLA.new(lat: 40.6892, lng: -74.0445, alt: 0))
    empire  = Feature.new(label: "Empire State",      geometry: LLA.new(lat: 40.7484, lng: -73.9857, alt: 0))

    dist = liberty.distance_to(empire)
    assert_instance_of Distance, dist
    assert_in_delta 8.24, dist.to_km.to_f, 0.1
  end

  def test_bearing_to_between_coordinate_features
    liberty = Feature.new(label: "Statue of Liberty", geometry: LLA.new(lat: 40.6892, lng: -74.0445, alt: 0))
    empire  = Feature.new(label: "Empire State",      geometry: LLA.new(lat: 40.7484, lng: -73.9857, alt: 0))

    bearing = liberty.bearing_to(empire)
    assert_instance_of Geodetic::Bearing, bearing
    assert_in_delta 36.99, bearing.degrees, 0.1
  end

  def test_distance_to_raw_coordinate
    f  = Feature.new(label: "Test", geometry: LLA.new(lat: 40.6892, lng: -74.0445, alt: 0))
    pt = LLA.new(lat: 40.7484, lng: -73.9857, alt: 0)

    dist = f.distance_to(pt)
    assert_instance_of Distance, dist
    assert dist.meters > 0
  end

  # ── Delegation: area geometry (uses centroid) ────────────────

  def test_distance_to_with_area_geometry
    park_center = LLA.new(lat: 40.7829, lng: -73.9654, alt: 0)
    park_area   = Circle.new(centroid: park_center, radius: 500)
    park        = Feature.new(label: "Central Park", geometry: park_area)

    liberty = Feature.new(label: "Statue of Liberty", geometry: LLA.new(lat: 40.6892, lng: -74.0445, alt: 0))

    dist = park.distance_to(liberty)
    assert_instance_of Distance, dist

    # Should be approximately the same as centroid-to-point distance
    direct = park_center.distance_to(liberty.geometry)
    assert_in_delta direct.meters, dist.meters, 1.0
  end

  def test_distance_to_between_two_area_features
    center1 = LLA.new(lat: 40.7829, lng: -73.9654, alt: 0)
    center2 = LLA.new(lat: 40.6892, lng: -74.0445, alt: 0)
    area1   = Circle.new(centroid: center1, radius: 500)
    area2   = Circle.new(centroid: center2, radius: 300)

    f1 = Feature.new(label: "Area 1", geometry: area1)
    f2 = Feature.new(label: "Area 2", geometry: area2)

    dist = f1.distance_to(f2)
    direct = center1.distance_to(center2)
    assert_in_delta direct.meters, dist.meters, 1.0
  end

  def test_bearing_to_with_area_geometry
    park_center = LLA.new(lat: 40.7829, lng: -73.9654, alt: 0)
    park_area   = Circle.new(centroid: park_center, radius: 500)
    park        = Feature.new(label: "Central Park", geometry: park_area)

    liberty_pt = LLA.new(lat: 40.6892, lng: -74.0445, alt: 0)
    liberty    = Feature.new(label: "Statue of Liberty", geometry: liberty_pt)

    bearing = park.bearing_to(liberty)
    direct  = park_center.bearing_to(liberty_pt)
    assert_in_delta direct.degrees, bearing.degrees, 0.01
  end

  # ── to_s / inspect ──────────────────────────────────────────

  def test_to_s
    pt = LLA.new(lat: 40.6892, lng: -74.0445, alt: 0)
    f  = Feature.new(label: "Statue of Liberty", geometry: pt)

    assert_includes f.to_s, "Statue of Liberty"
  end

  def test_inspect
    pt = LLA.new(lat: 40.6892, lng: -74.0445, alt: 0)
    f  = Feature.new(label: "Statue of Liberty", geometry: pt)

    assert_includes f.inspect, "Geodetic::Feature"
    assert_includes f.inspect, "Statue of Liberty"
  end
end
