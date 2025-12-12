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

> dbeaver, win 便携版

[点击下载](https://www.ghxi.com/dbeavercommunity.html)

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

- 计算面积 `ST_Area`

```sql
SELECT name, ST_Area(geom) FROM counties;
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

## 导入数据

### geojson

#### 用 sql

```sql
CREATE TABLE counties_raw(json jsonb);
INSERT INTO counties_raw VALUES (
  '...你的GeoJSON文本...'
);
CREATE TABLE counties AS
SELECT
  feature->'properties'->>'name' AS name,
  ST_SetSRID(
    ST_GeomFromGeoJSON(feature->'geometry'),
    4326
  ) AS geom
FROM jsonb_array_elements(
  (SELECT json->'features' FROM counties_raw)
) AS feature;

```
