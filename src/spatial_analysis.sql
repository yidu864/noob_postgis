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



