[toc]

## postgis 笔记

## 安装软件与环境

### docker 加速

[github 项目主页](https://github.com/DaoCloud/public-image-mirror)

```bash
# 增加前缀 (推荐方式)。比如：
docker.io/library/busybox
                 |
                 V
m.daocloud.io/docker.io/library/busybox

# 或者 支持的镜像仓库 的 前缀替换 就可以使用。比如：
           docker.io/library/busybox
             |
             V
docker.m.daocloud.io/library/busybox
```

### 安装 postgresql + postgis

> docker 部署, 超级管理员 postgres / 密码 123456

```bash
docker run --name postgis -e POSTGRES_PASSWORD=123456 -p 5432:5432 -d postgis/postgis
```

### 安装 pgadmin / dbeaver

二选一即可, 两者都是具备 GIS 数据可视化的数据库管理工具

> pgadmin4 docker, 账号test@123.com,密码 123456

```bash
docker run -d -p 5433:80 --name pgadmin4 -e PGADMIN_DEFAULT_EMAIL=test@123.com -e PGADMIN_DEFAULT_PASSWORD=123456 dpage/pgadmin4
```

> dbeaver, win 便携版 (社区版本没有 GIS 数据可视化功能, 需要企业版)

暂无

## 基本类型

- POINT
- LINESTRING
- POLYGON

### 数据类型

- GEOMETRY(Point, 4326)， epsg4326 坐标系的点数据

## 常用函数

- `ST_GeomFromText('POINT(121.5645 25.0330)', 4326)` 字符串转为 geom

```sql
-- 点线面
ST_GeomFromText('LINESTRING(121.5 25.0, 121.6 25.1)', 4326);
ST_GeomFromText('POLYGON((121.57 25.04, 121.58 25.04, 121.58 25.03, 121.57 25.03, 121.57 25.04))', 4326);
```

- `ST_AsText(geom)` 将 geom 转为 text

- ` ST_SRID(geom)` 获取 srid

```sql
-- 设置/转换srid
UPDATE places SET geom = ST_SetSRID(geom, 4326);
SELECT name, ST_AsText(ST_Transform(geom, 3857)) FROM places;
```

- 转为 geojson

```sql
SELECT name, ST_AsGeoJSON(geom) FROM places;
```

- 计算面积/长度/两点间球面距离 `ST_Area/ST_Length/ST_Distance`

**::geography 是临时将 geom_polygon(geometry(POLYGON, 4326)) 转为 geography 类型**

**转换后计算出的值单位是 平方米, 不做转换计算出的是 平方度(平面笛卡尔坐标系方格数量), 不能直接使用**

> 例外是 GEOMETRY 数据使用 以米未单位的投影坐标系(例如国内的 CGCS2000 / 3-degree Gauss-Kruger zone 40，EPSG:4547), 那么无需转换计算出的结果就是平方米/米

```sql
SELECT name, ST_Area(geom) FROM counties;
SELECT feature_name, st_area(geom_polygon::geography) from "public".learn_table;
SELECT feature_name, st_length(geom_linestring::geography) from "public".learn_table
SELECT feature_name, st_distance(geom_point::geography, st_geomfromtext('POINT(121.5645 25.0330)',4326)::geography) from "public".learn_table
```

- 获取几何类型

```sql
SELECT ST_GeometryType(geom), COUNT(*)
FROM counties
GROUP BY ST_GeometryType(geom);
```

- 面数据是否闭合

```sql
SELECT id
FROM counties
WHERE NOT ST_IsClosed(geom);
```

- 拓扑是否有效

```sql
-- 查询
SELECT name,ST_IsValid(geom)
FROM counties;
-- 修复
UPDATE counties
SET geom = ST_MakeValid(geom)
WHERE NOT ST_IsValid(geom);
```

- geojson 转 geom `ST_GeomFromGeoJSON`

```sql
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
```

- 面是否包含点/线/面`st_contains`

```sql
SELECT p.feature_name as "点", c.feature_name as "面"
FROM "public".learn_table p
JOIN "public".learn_table c ON c.feature_name = '台北市'
WHERE ST_Contains(c.geom_polygon, p.geom_point);
```

## 导入数据

### geojson

#### 用 sql

```sql
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
```
