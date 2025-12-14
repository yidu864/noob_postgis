-- 第四天 空间分析

-- 先生成一个表，在 init.sql 中能找到

-- 插入
INSERT INTO "public".learn_table (feature_name, geom_polygon) VALUES
('t_poly_1', ST_GeomFromText(
    'POLYGON((118 32,119 32,119 33,118 33,118 32))', 4326
));

-- 生成缓冲区并比较
SELECT feature_name, geom_polygon AS poly FROM "public".learn_table WHERE feature_name = 't_poly_1'
UNION ALL
SELECT feature_name, ST_Buffer(geom_polygon::geography, 1000)::geometry AS poly FROM "public".learn_table WHERE feature_name = 't_poly_1';

-- 插入
INSERT INTO "public".learn_table (feature_name, geom_polygon) VALUES
('t_poly_2', ST_GeomFromText(
    'POLYGON((118.5 32.5,119.5 32.5,119.5 33.5,118.5 33.5,118.5 32.5))', 4326
));

-- 相交分析, 求相交
SELECT  feature_name, geom_polygon as geom from "public".learn_table WHERE feature_name LIKE 't_poly%'
UNION ALL
SELECT 'intersection' as feature_name,ST_Intersection(a.geom_polygon::geography, b.geom_polygon::geography)::geometry as geom
FROM "public".learn_table a, "public".learn_table b
WHERE a.feature_name='t_poly_1' AND b.feature_name='t_poly_2';

-- 差异分析, 求差异, 实际上就是 a图形减去与b图形相交部分
SELECT  feature_name, geom_polygon as geom from "public".learn_table WHERE feature_name LIKE 't_poly%'
UNION ALL
SELECT 'ST_Difference' as feature_name,ST_Difference(a.geom_polygon::geography, b.geom_polygon::geography)::geometry as geom
FROM "public".learn_table a, "public".learn_table b
WHERE a.feature_name='t_poly_1' AND b.feature_name='t_poly_2';

-- 是否接触, 边擦到也算
SELECT 'ST_Intersects' as feature_name,ST_Intersects(a.geom_polygon::geography, b.geom_polygon::geography)
FROM "public".learn_table a, "public".learn_table b
WHERE a.feature_name='t_poly_1' AND b.feature_name='t_poly_2';

-- 包含, a 完全包含 b？ 
SELECT feature_name, ST_Contains(ST_Buffer(geom_polygon::geography, 1000)::geometry, geom_polygon) FROM "public".learn_table WHERE feature_name = 't_poly_1';

-- 包含, ST_Within(a, b) -- a 是否在 b 内？
SELECT feature_name, ST_Contains(ST_Buffer(geom_polygon::geography, 0)::geometry, geom_polygon) FROM "public".learn_table WHERE feature_name = 't_poly_1';

-- 同纬度非完全覆盖的相交
SELECT feature_name, ST_Overlaps(ST_Buffer(geom_polygon::geography, 0)::geometry, geom_polygon) FROM "public".learn_table WHERE feature_name = 't_poly_1';


-- 作业
-- 1. 导入两个 polygon 数据
INSERT INTO "public"."learn_table" ("id", "feature_name", "geom_polygon") VALUES ('polygon_福州周边',ST_GeomFromText('POLYGON((119.286 25.935, 119.352 25.872, 119.418 25.912, 119.394 25.978, 119.316 26.004, 119.274 25.962, 119.286 25.935))', 4326));
INSERT INTO "public"."learn_table" ("id", "feature_name", "geom_polygon") VALUES ('polygon_泉厦交界',ST_GeomFromText('POLYGON((118.564 24.872, 118.623 24.845, 118.712 24.886, 118.726 24.953, 118.638 24.982, 118.581 24.926, 118.564 24.872))', 4326));
-- 2. 50km buffer
SELECT
  feature_name,
  st_difference (st_buffer (geom_polygon :: geography, 50000) :: geometry, geom_polygon)
FROM
  "public".learn_table
WHERE
  feature_name IN ('polygon_福州周边', 'polygon_泉厦交界');

-- 右移动10km
-- 转换为UTM投影进行平移，再转回WGS84
INSERT INTO "public".learn_table (feature_name, geom_polygon) SELECT
  CONCAT (feature_name, '-r10t5'),
  st_transform (st_translate (st_transform (geom_polygon, 32650), 10000, 5000), 4326)
FROM
  "public".learn_table
WHERE
  feature_name = 'polygon_福州周边';
  
-- 自己写_完整
SELECT
  -- 3. 计算相交面积
  st_area (ST_Intersection (a.geom_polygon :: geography, b.geom_polygon :: geography)) as area_2,
  -- 相交
  ST_Intersection (a.geom_polygon :: geography, b.geom_polygon :: geography),
  -- 4. 包含
  st_contains(a.geom_polygon, b.geom_polygon) as is_a_contains_b,
  -- 5. 差异 a-b
  st_difference(a.geom_polygon, b.geom_polygon) as a_diff_b,
  -- 6.area_m2
  st_area(st_difference(a.geom_polygon, b.geom_polygon)::geography) as a_diff_b_aream2,
  a.feature_name as a_name,
  b.feature_name as b_name
FROM
  "public".learn_table a,
  "public".learn_table b
WHERE
  a.feature_name = 'polygon_福州周边'
  AND b.feature_name = 'polygon_福州周边-r10t5';


-- 完整
SELECT
  a.feature_name AS name_a,
  b.feature_name AS name_b,
  ST_Intersects(a.geom_polygon, b.geom_polygon) AS intersects,      -- 是否相交
  ST_Disjoint(a.geom_polygon, b.geom_polygon) AS disjoint,          -- 是否分离
  ST_Distance(a.geom_polygon::geography, b.geom_polygon::geography) AS distance_meters, -- 距离（米）
  ST_Area(ST_Difference(a.geom_polygon, b.geom_polygon)::geography) AS diff_area_sq_m  -- 差集面积
FROM
  "public".learn_table a,
  "public".learn_table b
WHERE
  a.feature_name = 'polygon_福州周边'
  AND b.feature_name = 'polygon_福州周边-r10t5';


  
