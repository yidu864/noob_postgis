# postgis

[手册地址](https://postgis.net/workshops/zh_Hans/postgis-intro/)

## 准备环境

> postgis, gdal, pgadmin4 参考 postgis_note.md 安装

## 下载数据

下载[数据包](https://postgis.net/workshops/zh_Hans/postgis-intro/#getting-started)

可选以下两种方式

## 导入数据

1. 打开 pgadmin, 创建数据库 `create database nyc;`
2. 在 nyc 数据库中启用 postgis 扩展 `CREATE EXTENSION postgis;`
3. 验证扩展是否启用 `SELECT postgis_full_version();`
4. 导入数据方式, 以下二选一

### pgadmin 数据备份恢复

下载的数据包中存在 `nyc_data.backup` 文件, 右键`nyc`数据库选还原,并上传对应数据包的所有数据

选中`nyc_data.backup`即可, 详见 [此](https://postgis.net/workshops/zh_Hans/postgis-intro/loading_data.html)

> 注意: 需要完整的上传所有的文件, 并且确保数据库还原前已经开启 postgis 扩展

### ogr2ogr 导入 shp 文件

```bash
ogr2ogr   -nln nyc_census_blocks_2000   -nlt PROMOTE_TO_MULTI   -lco GEOMETRY_NAME=geom   -lco FID=gid   -lco PRECISION=NO   Pg:"dbname=nyc host=localhost user=postgres port=8096 password=123456" -progress  E:\MineSoft\noob_postgis\.database\postgis-workshop\data\2000\nyc_census_blocks_2000.shp
```

## 数据说明

[详见](https://postgis.net/workshops/zh_Hans/postgis-intro/about_data.html)

## 几何 GEOMETRY

> 执行

```sql
CREATE TABLE geometries (name varchar, geom geometry);

INSERT INTO geometries VALUES
  ('Point', 'POINT(0 0)'),
  ('Linestring', 'LINESTRING(0 0, 1 1, 2 1, 2 2)'),
  ('Polygon', 'POLYGON((0 0, 1 0, 1 1, 0 1, 0 0))'),
  ('PolygonWithHole', 'POLYGON((0 0, 10 0, 10 10, 0 10, 0 0),(1 1, 1 2, 2 2, 2 1, 1 1))'),
  ('Collection', 'GEOMETRYCOLLECTION(POINT(2 0),POLYGON((0 0, 1 0, 1 1, 0 1, 0 0)))');

SELECT name, ST_AsText(geom) FROM geometries;
```

### 元数据

根据 Simple Features for SQL (SFSQL)规范，PostGIS 提供了两个表来跟踪和报告给定数据库中可用的几何类型。

- `spatial_ref_sys` 表定义了数据库中所有已知的空间参考系统
- 视图`geometry_columns`，提供了所有“要素”（定义为具有几何属性的对象）的列表，以及这些要素的基本详细信息。

```sql
-- 看看里面有啥
SELECT * FROM geometry_columns;
```

`f_table_catalog`、`f_table_schema`和`f_table_name`提供了包含给定几何图形的要素表的完全限定名称。因为 PostgreSQL 不使用目录，所以`f_table_catalog`通常为空。

`f_geometry_column`是包含几何图形的列的名称——对于具有多个几何列的要素表，每个列将有一条记录。

`coord_dimension`和`srid`分别定义了几何图形的维度（2、3 或 4 维）和引用`spatial_ref_sys`表的空间参考系统标识符。

`type`列定义了下面描述的几何类型；到目前为止，我们已经看到了 Point 和 Linestring 类型。

```sql
-- 你的``nyc``表中的一部分或全部是否没有``srid``为26918？通过更新表格可以轻松解决这个问题。
ALTER TABLE nyc_neighborhoods
  ALTER COLUMN geom
  TYPE Geometry(MultiPolygon, 26918)
  USING ST_SetSRID(geom, 26918);
```

> 查询 geometry 类型,维数,srid

```sql
SELECT name, ST_GeometryType(geom), ST_NDims(geom), ST_SRID(geom)
  FROM geometries;
```
