-- 创建点
SELECT ST_GeomFromText('POINT(120.3 23.1)', 4326);

-- 创建多边形
SELECT ST_GeomFromText('POLYGON((0 0, 0 1, 1 1, 1 0, 0 0))', 4326);

-- 创建表

-- 连接数据库后执行
CREATE EXTENSION IF NOT EXISTS postgis; -- 核心扩展
CREATE EXTENSION IF NOT EXISTS postgis_topology; -- 用于topo_geom字段
-- CREATE EXTENSION IF NOT EXISTS postgis_raster; -- 如需栅格学习

CREATE TABLE learn_table (
    -- 基础信息
    id SERIAL PRIMARY KEY, -- 自增主键
    feature_name VARCHAR(255), -- 要素名称
    description TEXT, -- 描述
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP, -- 创建时间

    -- 核心几何类型（使用EPSG:4326，即WGS84经纬度）
    geom_point GEOMETRY(POINT, 4326), -- 点
    geom_linestring GEOMETRY(LINESTRING, 4326), -- 线
    geom_polygon GEOMETRY(POLYGON, 4326), -- 面（多边形）
    geom_multipoint GEOMETRY(MULTIPOINT, 4326), -- 多点
    geom_multilinestring GEOMETRY(MULTILINESTRING, 4326), -- 多线
    geom_multipolygon GEOMETRY(MULTIPOLYGON, 4326), -- 多面
    geom_collection GEOMETRY(GEOMETRYCOLLECTION, 4326), -- 几何集合（可混合类型）

    -- 地理类型（用于全球球面计算，对比用）
    geog_point GEOGRAPHY(POINT), -- 地理点
    geog_polygon GEOGRAPHY(POLYGON), -- 地理多边形

    -- 拓扑几何（需先启用PostGIS Topology扩展）
    topo_geom TOPOGEOMETRY, -- 拓扑几何，关联于一个拓扑结构

    -- 栅格数据（需先启用PostGIS Raster扩展）
    -- raster_data RASTER, -- 如需学习栅格可取消注释

    -- 元数据与验证
    srid INTEGER, -- 空间参考ID（可存储用于对比的不同坐标系）
    is_valid BOOLEAN, -- 几何是否有效（可通过ST_IsValid检查填充）
    area_m2 DOUBLE PRECISION, -- 面积（平方米，可通过ST_Area计算填充）
    length_m DOUBLE PRECISION -- 长度（米，可通过ST_Length计算填充）
);

-- 可选：为几何字段创建空间索引以加速查询
CREATE INDEX idx_geom_point ON learn_table USING GIST(geom_point);
CREATE INDEX idx_geom_polygon ON learn_table USING GIST(geom_polygon);
-- ... 可根据学习查询需要，为其他几何字段创建索引

-- 插入数据
INSERT INTO "public".learn_table (feature_name, geom_point) VALUES 
('台北101', ST_GeomFromText('POINT(121.5645 25.0330)', 4326)),
('高雄85大楼', ST_GeomFromText('POINT(120.3020 22.6120)', 4326));

INSERT INTO "public".learn_table (feature_name, geom_linestring) VALUES 
('道路1', ST_GeomFromText('LINESTRING(121.5 25.0, 121.6 25.1)', 4326));
INSERT INTO "public".learn_table (feature_name, geom_polygon) VALUES 
('地块1', ST_GeomFromText('POLYGON((121.57 25.04, 121.58 25.04, 121.58 25.03, 121.57 25.03, 121.57 25.04))', 4326));

-- 检查 srid
SELECT feature_name, ST_SRID(geom_point) FROM "public".learn_table;
-- 修正srid
UPDATE "public".learn_table SET geom_point = ST_SetSRID(geom_point, 4326);
-- 转换 srid
SELECT feature_name, ST_AsText(ST_Transform(geom_point, 3857)) FROM "public".learn_table;

-- 导入数据 countries
INSERT INTO "public".learn_table (feature_name, geom_polygon)
SELECT
  feature->'properties'->>'name' AS feature_name,
  ST_SetSRID(
    ST_GeomFromGeoJSON(feature->'geometry'),  -- 关键修正：传入整个geometry对象
    4326
  ) AS geom_polygon
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
-- 导入数据 land_parcels
INSERT INTO "public".learn_table (feature_name, geom_polygon)
SELECT
  CONCAT_WS('-', 'land_parcels', feature->'properties'->>'id') as feature_name,
  ST_SetSRID(
    ST_GeomFromGeoJSON(feature->'geometry'),  -- 关键修正：传入整个geometry对象
    4326
  ) AS geom_polygon
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
-- 导入数据 pois
INSERT INTO "public".learn_table (feature_name, geom_point)
SELECT
  CONCAT_WS('-', 'pois', feature->'properties'->>'name') as feature_name,
  ST_SetSRID(
    ST_GeomFromGeoJSON(feature->'geometry'),  -- 关键修正：传入整个geometry对象
    4326
  ) AS geom_polygon
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
-- 导入数据 reads
INSERT INTO "public".learn_table (feature_name, geom_linestring)
SELECT
  CONCAT_WS('-', 'pois', feature->'properties'->>'name') as feature_name,
  ST_SetSRID(
    ST_GeomFromGeoJSON(feature->'geometry'),  -- 关键修正：传入整个geometry对象
    4326
  ) AS geom_polygon
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

-- 检查问题, ST_MakeValid(geom_polygon) 修复拓扑有效性
SELECT feature_name, ST_GeometryType(geom_polygon), st_srid(geom_polygon),st_isclosed(geom_polygon), st_isvalid(geom_polygon)  FROM "public".learn_table;

-- 计算 面积 / 长度 / 两点之间距离
-- ::geography 是临时将 geom_polygon(geometry(POLYGON, 4326)) 转为 geography 类型
-- 转换后计算出的值单位是 平方米, 不做转换计算出的是 平方度, 不能直接使用
SELECT feature_name, st_area(geom_polygon::geography) from "public".learn_table;
SELECT feature_name, st_length(geom_linestring::geography) from "public".learn_table;
SELECT feature_name, st_distance(geom_point::geography, st_geomfromtext('POINT(121.5645 25.0330)',4326)::geography) from "public".learn_table;

-- 面是否包含点/线/面
SELECT p.feature_name as "点", c.feature_name as "面"
FROM "public".learn_table p
JOIN "public".learn_table c ON c.feature_name = '台北市'
WHERE ST_Contains(c.geom_polygon, p.geom_point);

-- 面积排序
SELECT feature_name, st_area(geom_polygon::geography) as area_m2 FROM "public".learn_table ORDER BY area_m2 DESC;
