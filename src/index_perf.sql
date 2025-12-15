-- 索引, 性能与优化

-- 1. 数据准备, 新建三张表
CREATE TABLE "public".counties as
SELECT
  feature->'properties'->>'name' AS feature_name,
  ST_SetSRID(
    ST_GeomFromGeoJSON(feature->'geometry'),  -- 关键修正：传入整个geometry对象
    4326
  ) AS geom
FROM jsonb_array_elements(
  '{
  "type": "FeatureCollection",
  "features": [
    {
      "type": "Feature",
      "properties": { "name": "台北市" },
      "geometry": {
        "type": "Polygon",
        "coordinates": [[[121.45,25.15],[121.65,25.15],[121.65,24.95],[121.45,24.95],[121.45,25.15]]]
      }
    },
    {
      "type": "Feature",
      "properties": { "name": "新北市" },
      "geometry": {
        "type": "Polygon",
        "coordinates": [[[121.3,25.3],[121.8,25.3],[121.8,24.8],[121.3,24.8],[121.3,25.3]]]
      }
    }
  ]
}'::jsonb->'features'
) AS feature;

CREATE TABLE "public".land_parcels as
SELECT
  CONCAT_WS('-', 'land_parcels', feature->'properties'->>'id') as feature_name,
  ST_SetSRID(
    ST_GeomFromGeoJSON(feature->'geometry'),  -- 关键修正：传入整个geometry对象
    4326
  ) AS geom
FROM jsonb_array_elements(
  '{
  "type": "FeatureCollection",
  "features": [
    {
      "type": "Feature",
      "properties": { "id": 1 },
      "geometry": {
        "type": "Polygon",
        "coordinates": [
          [
            [121.5, 25.06],
            [121.58, 25.06],
            [121.58, 25.0],
            [121.5, 25.0],
            [121.5, 25.06]
          ]
        ]
      }
    },
    {
      "type": "Feature",
      "properties": { "id": 2 },
      "geometry": {
        "type": "Polygon",
        "coordinates": [
          [
            [121.55, 25.04],
            [121.63, 25.04],
            [121.63, 24.98],
            [121.55, 24.98],
            [121.55, 25.04]
          ]
        ]
      }
    }
  ]
}
'::jsonb->'features'
) AS feature;

CREATE TABLE "public".pois as
SELECT
  CONCAT_WS('-', 'pois', feature->'properties'->>'name') as feature_name,
  ST_SetSRID(
    ST_GeomFromGeoJSON(feature->'geometry'),  -- 关键修正：传入整个geometry对象
    4326
  ) AS geom
FROM jsonb_array_elements(
  '{
  "type": "FeatureCollection",
  "features": [
    {
      "type": "Feature",
      "properties": { "name": "台北101" },
      "geometry": {
        "type": "Point",
        "coordinates": [121.5645, 25.033]
      }
    },
    {
      "type": "Feature",
      "properties": { "name": "高雄85大楼" },
      "geometry": {
        "type": "Point",
        "coordinates": [120.302, 22.612]
      }
    }
  ]
}
'::jsonb->'features'
) AS feature;

CREATE TABLE "public".roads AS
SELECT
  CONCAT_WS('-', 'roads', feature->'properties'->>'name') as feature_name,
  ST_SetSRID(
    ST_GeomFromGeoJSON(feature->'geometry'),  -- 关键修正：传入整个geometry对象
    4326
  ) AS geom
FROM jsonb_array_elements(
  '{
  "type": "FeatureCollection",
  "features": [
    {
      "type": "Feature",
      "properties": { "name": "中山高速公路" },
      "geometry": {
        "type": "LineString",
        "coordinates": [
          [121.3, 25.1],
          [121.55, 25.05],
          [121.7, 24.9]
        ]
      }
    }
  ]
}
'::jsonb->'features'
) AS feature;

-- 2. 添加索引
CREATE INDEX idx_counties_geom ON "public".counties USING GIST(geom);
CREATE INDEX idx_roads_geom ON "public".roads USING GIST (geom);
CREATE INDEX idx_pois_geom ON "public".pois USING GIST (geom);
CREATE INDEX idx_land_parcels_geom ON "public".land_parcels USING GIST (geom);

-- 查看索引
SELECT
  tablename,
  indexname
FROM pg_indexes
WHERE tablename IN ('counties','roads','pois','land_parcels');

-- 删除索引, 查看效果, 对比加上之后的效果
DROP INDEX idx_land_parcels_geom;

EXPLAIN ANALYZE
SELECT *
FROM land_parcels a
JOIN counties c
ON ST_Intersects(a.geom, c.geom);

CREATE INDEX idx_land_parcels_geom 
ON land_parcels 
USING GIST (geom);

EXPLAIN ANALYZE
SELECT *
FROM land_parcels a
JOIN counties c
ON ST_Intersects(a.geom, c.geom);

-- 接下来见笔记中的索引原理与失效分析

