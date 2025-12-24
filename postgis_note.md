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

### 安装 pgadmin / dbeaver / ogr2ogr

二选一即可, 两者都是具备 GIS 数据可视化的数据库管理工具

> pgadmin4 docker, 账号test@123.com,密码 123456

```bash
docker run -d -p 5433:80 --name pgadmin4 -e PGADMIN_DEFAULT_EMAIL=test@123.com -e PGADMIN_DEFAULT_PASSWORD=123456 dpage/pgadmin4
```

> dbeaver, win 便携版 (社区版本没有 GIS 数据可视化功能, 需要企业版)

暂无

#### 安装 ogr2ogr

> 需要安装 gdal, 推荐 docker 或者 miniconda 安装

使用 docker 安装最简单, 但是要做目录映射, 在 win 环境不友好

```bash
docker run --rm -it \
  -v /本地/数据目录:/data \
  --network="host" \
  osgeo/gdal:ubuntu-full-latest \
  ogr2ogr -f "PostgreSQL" PG:"host=host.docker.internal dbname=你的数据库 user=你的用户 password=你的密码" /data/your_shapefile.shp -nln 新表名
```

conda 安装, 需要至少 py3.11 环境

```bash
conda create -n 虚拟环境名 python=3.11
conda activate 虚拟环境名
conda install conda-forge::gdal
gdal --version
ogr2ogr --version
# gdal 的 pg 驱动
conda install libgdal-pg
```

不安装 gdal, 只安装 ogr2ogr 相关包 [前往 gisinternals](https://www.gisinternals.com/development.php)

> 注意, 如果用的是构建好的工具包, 需要先运行 sdk_install.cmd, 准备好环境<br />
> 理论上是不会污染系统变量, 但是实践中似乎会导致 navicat 闪退?

### QGIS

开源地理数据分析工具, [下载](https://qgis.org/download/)

## 导入数据

### 用 sql

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

### shp 类型的文件

SHP 文件（Shapefile）是一种常见的地理空间矢量数据格式，它实际上由**至少三个必需文件**组成，有时还会有更多辅助文件。

#### 📁 核心文件结构（必需）

| 文件扩展名 | 用途             | 重要性                                                              |
| :--------- | :--------------- | :------------------------------------------------------------------ |
| **`.shp`** | **主体图形文件** | **必需**。存储几何图形本身（点、线、面等的坐标）。                  |
| **`.shx`** | **图形索引文件** | **必需**。存储`.shp`中几何体的位置索引，用于快速访问。              |
| **`.dbf`** | **属性数据文件** | **必需**。以 dBase 格式存储几何体对应的属性信息（如名称、面积等）。 |

这三个文件必须**同名且在同一目录下**。如果缺少任何一个，大部分 GIS 软件都无法正确读取数据。例如，一个名为`fujian_roads`的 Shapefile，其文件夹内必须包含：

- `fujian_roads.shp`
- `fujian_roads.shx`
- `fujian_roads.dbf`

#### 🔧 常见辅助文件

除了上述三个核心文件，还可能存在以下文件，它们为数据提供额外信息：

| 文件扩展名          | 用途                                                                                                                                |
| :------------------ | :---------------------------------------------------------------------------------------------------------------------------------- |
| **`.prj`**          | **坐标系统文件**。非常重要，它以文本形式定义了数据的坐标系（如 WGS84、GCJ-02 等）。没有它，GIS 软件无法将数据定位到正确的地理位置。 |
| **`.cpg`**          | **字符编码说明文件**。用于指定`.dbf`文件的编码（如 UTF-8、GBK），防止中文字段乱码。                                                 |
| **`.sbn` / `.sbx`** | 空间索引文件，用于加快空间查询速度。由某些 GIS 软件（如 ArcGIS）自动生成。                                                          |
| **`.shp.xml`**      | 元数据文件，以 XML 格式描述数据集的来源、精度等信息。                                                                               |

#### 📄 内部结构示例

以“福建省行政区划”数据为例，它的 `.dbf` 文件（属性表）可能包含如下字段：

| OBJECTID | NAME   | CODE   | AREA     | ... |
| :------- | :----- | :----- | :------- | :-- |
| 1        | 福州市 | 350100 | 12109.47 | ... |
| 2        | 厦门市 | 350200 | 1699.39  | ... |
| 3        | 莆田市 | 350300 | 4119.02  | ... |

而这个 `.dbf` 表中的每一行，都通过内部 ID 与 `.shp` 文件中对应的一条几何图形（如福州市的多边形边界）**严格关联**。`.shx` 文件则记录了这条多边形在 `.shp` 文件中的具体存储位置，以便快速读取。

#### 🛠️ 如何处理 SHP 文件？

理解了结构，操作就很简单了：

1.  **永远以“文件包”形式处理**：在复制、移动或分享时，务必确保所有相关文件（至少 `.shp`, `.shx`, `.dbf`）一起操作。
2.  **导入 PostGIS**：
    - **使用`shp2pgsql`工具**（PostGIS 自带命令行工具）：
      ```bash
      shp2pgsql -s 4326 -W GBK /path/to/fujian_roads.shp fujian_roads | psql -d your_database
      ```
      - `-s 4326`：指定目标 SRID（如果 `.prj` 存在，可以先用 `-D` 参数自动探测）
      - `-W GBK`：如果属性表含中文，通常需指定 GBK 编码
    - **使用 QGIS**：在 QGIS 中加载 SHP 图层后，通过右键菜单“导出” -> “要素存储为”，选择 PostgreSQL 连接，即可直观导入。
    - **ogr2ogr**: 详见下一个小节

### 用 ogr2ogr

> 导入 shp

参数解析:

1. `-nln` 表名
2. `-nlt` 选项代表“新图层类型”。特别是对于 shape 文件输入，新图层类型通常是“多部分几何”，因此系统需要事先告知使用“MultiPolygon”而不是“Polygon”作为几何类型。
3. `-lco` 选项代表“图层创建选项”。不同的驱动程序具有不同的创建选项，我们在这里使用了 PostgreSQL 驱动程序 的三个选项。

   **GEOMETRY_NAME**设置几何列的列名。我们倾向于使用"geom"而不是默认值，以使我们的表与研讨会中的标准列名匹配。

   **FID**设置主键列名。同样，我们更喜欢使用"gid"，这是研讨会中使用的标准。

   **PRECISION**控制数字字段在数据库中的表示方式。在加载 shape 文件时，默认情况下使用数据库的“numeric”类型，这更精确，但有时比“integer”和“double precision”等简单数值类型更难处理。我们使用"NO"来关闭"numeric"类型。

4. `-progress` 展示进度
5. `-t_srs EPSG:4326` 转换 shp 文件中默认的坐标系
6. `Pg:"dbname=nyc host=localhost user=postgres port=8096 password=123456` postgre 连接串
7. `nyc_census_blocks_2000.shp` shp 文件

8. `-skipfailures` 遇到错误要素时跳过，继续执行，防止单个错误导致整个任务失败。
9. `-append` 追加而不是新建表
10. `-update` 会尝试根据关键字更新
11. `-where "POPULATION > 1000"` 条件导入

```sql
-- 要给对应的数据库开启 postgis 扩展, 否则无法导入
CREATE EXTENSION postgis;
SELECT postgis_full_version();
```

```bash
ogr2ogr   -nln nyc_census_blocks_2000   -nlt PROMOTE_TO_MULTI   -lco GEOMETRY_NAME=geom   -lco FID=gid   -lco PRECISION=NO   Pg:"dbname=nyc host=localhost user=postgres port=8096 password=123456" -progress -t_srs EPSG:4326  E:\MineSoft\noob_postgis\.database\postgis-workshop\data\2000\nyc_census_blocks_2000.shp
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

## 几何类型

以下使用的数据来自于[手册](./src/postgis_manual.md#下载数据)

### 点

`POINT(0 0)` 就是一个二维点,

```sql
-- geom, x坐标, y坐标
SELECT long_name, ST_Transform(geom,4326), ST_X(geom),ST_Y(geom)
  FROM nyc_subway_stations
  LIMIT 100;
```

### 线

`LINESTRING(0 0, 1 1, 2 1, 2 2)` 线串

```sql
SELECT ST_AsText(geom)
  FROM geometries
  WHERE name = 'Linestring';
```

一些用于处理 Linestring 的特定空间函数包括:

- `ST_Length(geometry)` 返回 Linestring 的长度
- `ST_StartPoint(geometry)` 返回第一个坐标作为一个点
- `ST_EndPoint(geometry)` 返回最后一个坐标作为一个点
- `ST_NPoints(geometry)` 返回 Linestring 中坐标的数量

```sql
SELECT name, st_transform(geom,4326), st_length(geom), st_startpoint(geom), st_endpoint(geom),st_npoints(geom)
  FROM "public".nyc_streets
  LIMIT 100;
```

### 多边形

`POLYGON((0 0, 1 0, 1 1, 0 1, 0 0)),  POLYGON((0 0, 10 0, 10 10, 0 10, 0 0),(1 1, 1 2, 2 2, 2 1, 1 1))`

一些用于处理多边形的特定空间函数包括:

- `ST_Area(geometry)` 返回多边形的面积, 带有孔的多边形的面积是外壳的面积（一个 10x10 的正方形）减去孔的面积（一个 1x1 的正方形）。
- `ST_NRings(geometry)` 返回环的数量（通常为 1，如果有孔则更多）
- `ST_ExteriorRing(geometry)` 返回外环作为一个 Linestring
- `ST_InteriorRingN(geometry,n)` 返回指定的内部环作为一个 Linestring
- `ST_Perimeter(geometry)` 返回所有环的长度

```sql
SELECT name,ST_AsText(geom)
  FROM geometries
  WHERE name LIKE 'Polygon%';

SELECT name,st_area(geom),st_nrings(geom),st_exteriorring(geom),st_interiorringn(geom, 1),st_perimeter(geom)
  FROM geometries
  WHERE name LIKE 'Polygon%';
```

### 集合 MULTI-XXX

有四种集合类型，它们将多个简单几何图形分组成集合。

- MultiPoint，一组点
- MultiLineString，一组线串
- MultiPolygon，一组多边形
- GeometryCollection，任何几何图形的异构集合（包括其他集合）

一些用于处理集合的特定空间函数包括:

- `ST_NumGeometries(geometry)` 返回集合中的部分数量
- `ST_GeometryN(geometry,n)` 返回指定的部分, 索引从 0 开始
- `ST_Area(geometry)` 返回所有多边形部分的总面积
- `ST_Length(geometry)` 返回所有线性部分的总长度

```sql
SELECT name, (geom), st_numgeometries(geom), st_geometryn(geom, 1), st_length(geom)
  FROM geometries
  WHERE name = 'Collection';
```

### 几何的输入输出

在数据库中，几何图形以一种仅由 PostGIS 程序使用的格式存储在磁盘上。为了让外部程序插入和检索有用的几何图形，它们需要转换成其他应用程序能够理解的格式。幸运的是，PostGIS 支持在大量格式中发出和消耗几何图形:

- Well-known text (WKT)
  - `st_GeomFromText(text, srid)` 返回 geometry
  - `st_AsText(geometry)` 返回 text
  - `st_AsEWKT(geometry)` 返回 text
- Well-known binary (WKB)
  - `st_GeomFromWKB(bytea)` 返回 geometry
  - `st_AsBinary(geometry)` 返回 bytea
  - `st_AsEWKB(geometry)` 返回 bytea
- Geographic Mark-up Language (GML)
  - `st_GeomFromGML(text)` 返回 geometry
  - `st_AsGML(geometry)` 返回 text
- Keyhole Mark-up Language (KML)
  - `st_GeomFromKML(text)` 返回 geometry
  - `st_AsKML(geometry)` 返回 text
- GeoJSON
  - `st_AsGeoJSON(geometry)` 返回 text
- 可伸缩矢量图形 (SVG)
  - `st_AsSVG(geometry)` 返回 text

构造函数最常见的用途是将几何图形的文本表示转换为内部表示, 如需展示, 必须设置 srid

```sql
SELECT encode(
  ST_AsBinary(ST_GeometryFromText('LINESTRING(0 0,1 0)')),
  'hex');
SELECT ST_AsText(ST_GeometryFromText('LINESTRING(0 0 0,1 0 0,1 1 2)'));

-- 除了ST_GeometryFromText 函数之外，还有许多其他方法可以从常用文本或类似格式的输入创建几何图形:
-- Using ST_GeomFromText with the SRID parameter
SELECT ST_GeomFromText('POINT(2 2)',4326);

-- Using ST_GeomFromText without the SRID parameter
SELECT ST_SetSRID(ST_GeomFromText('POINT(2 2)'),4326);

-- Using a ST_Make* function
SELECT ST_SetSRID(ST_MakePoint(2, 2), 4326);

-- Using PostgreSQL casting syntax and ISO WKT
SELECT ST_SetSRID('POINT(2 2)'::geometry, 4326);

-- Using PostgreSQL casting syntax and extended WKT
SELECT 'SRID=4326;POINT(2 2)'::geometry;
```

> 除了各种形式的发射器（WKT、WKB、GML、KML、JSON、SVG）之外，PostGIS 还具有四个消费者（WKT、WKB、GML、KML）。大多数应用程序使用 WKT 或 WKB 几何创建函数，但其他函数也可用。下面是一个消费 GML 并输出 JSON 的示例

```sql
SELECT ST_AsGeoJSON(ST_GeomFromGML('<gml:Point><gml:coordinates>1,1</gml:coordinates></gml:Point>'));
```

### 从文本中解析

postgre 可以用 `old::new` 的方式直接转换类型 , 如

```sql
SELECT 0.9::text;
SELECT 'POINT(0 0)'::geometry;
SELECT 'SRID=4326;POINT(0 0)'::geometry;
```

### 实践操作

```sql
-- “West Village”社区的面积是多少？
SELECT gid, "name", st_area(geom) FROM nyc_neighborhoods nnb WHERE nnb."name" = 'West Village';

-- Pelham St "佩勒姆街"的几何类型是什么？长度是多少？
SELECT gid, st_geometrytype(geom), st_length(geom) from nyc_streets ns WHERE ns."name" = 'Pelham St'

-- "Broad St"地铁站的GeoJSON表示是什么？
SELECT gid, "name", st_asgeojson(geom) FROM nyc_subway_stations nss WHERE nss."name" = 'Broad St' LIMIT 100;

-- 纽约市的街道总长度（公里）是多少？（提示：空间数据的测量单位是米，一公里有1000米。）
SELECT sum(st_length(geom))/1000 from nyc_streets;

-- Manhattan 的面积是多少英亩？ （提示：nyc_census_blocks 和 nyc_neighborhoods``中都有一个 ``boroname。）
SELECT sum(st_area(geom))/4047 FROM nyc_neighborhoods WHERE boroname = 'Manhattan';

-- 最西的地铁站是哪个？
SELECT gid, "name", st_x(geom) FROM nyc_subway_stations ORDER BY st_x(geom) LIMIT 1;

-- “Columbus Cir” 有多长？
SELECT st_length(geom) FROM nyc_streets WHERE name = 'Columbus Cir';

-- 按类型总结，纽约市的街道长度是多少？
SELECT "type", sum(st_length(geom)) as length from nyc_streets GROUP BY "type" ORDER BY length asc;
```

## 空间类型

### ST_Equals

`ST_Equals(geometry A, geometry B)` 用于检测两个几何图形的拓扑相等性。必须坐标完全一致, 才能判定拓扑相等(位置与形状完全重合)

```sql
SELECT name
FROM nyc_subway_stations
WHERE ST_Equals(
  geom,
  '0101000020266900000EEBD4CF27CF2141BC17D69516315141');
-- Broad St
```

### 相交/相离

ST_Intersects, ST_Disjoint, ST_Crosses, ST_Overlaps

- **判断相交**: `ST_Intersects`、`ST_Crosses`和 `ST_Overlaps` 用于检测几何图形内部区域是否发生相交。
- **不相交**: `ST_Disjoint` 不相交

`ST_Intersects(geometry A, geometry B)` 当两个图形存在任意空间交集时返回 t（TRUE），即边界或内部发生相交即视为满足条件。

`ST_Disjoint(geometry A , geometry B)`。两个几何图形互不相交，则返回 t(True)

> 实际上，测试"不相交"(not intersects)通常比直接测试"相离"(disjoint)更高效<br>
> ——因为相交测试可利用空间索引优化，而相离测试则无法利用索引。

`ST_Crosses(geometry A, geometry B)` 满足以下

1.  交集结果的几何维度比两个源几何的最大维度小
1.  该交集同时位于两个源几何内部时，函数返回 TRUE。

`ST_Overlaps(geometry A, geometry B)` 用于比对两个同维度几何图形，当满足以下条件时返回 TRUE

以下是通过 `ST_Intersects`函数确定「Broad Street」地铁站所属行政辖区的示例：

```sql
-- 「Broad St」地铁站所属行政辖区 ?
SELECT nn."name", nn.boroname FROM "public".nyc_subway_stations nss INNER JOIN "public".nyc_neighborhoods nn ON st_intersects(nn.geom, nss.geom) WHERE nss.name = 'Broad St';
-- name | boroname
-- Financial District | Manhattan
```

### 边界接触

`ST_Touches(geometry A, geometry B) `检测两个几何图形是否边界接触但内部无交集

```sql
-- 共享右上角点(1,1)
SELECT st_touches(st_geomfromtext('POLYGON((0 0,1 0,1 1,0 1,0 0))'), st_geomfromtext('POLYGON((1 1, 2 1, 2 2, 1 2, 1 1))'));
```

### 完全包含

`ST_Within` 与 `ST_Contains` 用于检测两个几何图形之间的完全包含关系。

`ST_Within(geometry A , geometry B)` 检查几何图形 A 是否完全在 B 的内部（不包括边界）。该函数与 ST_Contains 的检测结果互为逆反关系。

`ST_Contains(geometry A, geometry B)` 检查几何图形 A 是否完全包含 B（B 在 A 的内部）

```sql
-- 更复杂的示例：多个几何图形的包含关系
SELECT
    -- 小矩形在大矩形内（ST_Within）
    ST_Within(
        ST_GeomFromText('POLYGON((1 1, 3 1, 3 3, 1 3, 1 1))'),
        ST_GeomFromText('POLYGON((0 0, 5 0, 5 5, 0 5, 0 0))')
    ) AS small_in_large,

    -- 大矩形包含小矩形（ST_Contains）
    ST_Contains(
        ST_GeomFromText('POLYGON((0 0, 5 0, 5 5, 0 5, 0 0))'),
        ST_GeomFromText('POLYGON((1 1, 3 1, 3 3, 1 3, 1 1))')
    ) AS large_contains_small,

    -- 边界上的点（注意：在边界上不算 within）
    ST_Within(
        ST_GeomFromText('POINT(4 4)'),
        ST_GeomFromText('POLYGON((0 0, 4 0, 4 4, 0 4, 0 0))')
    ) AS point_on_boundary;
```

### 计算距离

`ST_Distance(geometry A, geometry B)` 用于计算两个几何图形之间的最短距离，并以浮点数形式返回结果。

```sql
SELECT
  ST_Distance (ST_GeometryFromText ('POINT(0 5)'), ST_GeometryFromText ('LINESTRING(-2 2, 2 2)'));
-- 3
```

`ST_DWithin` 函数提供基于索引加速的布尔距离检测，用于判断两个对象是否处于指定距离范围内。

> 该函数特别适用于诸如"道路 500 米范围内有多少树木"这类空间分析场景——无需实际生成缓冲区，仅需测试距离关系即可获得结果。

以下是通过空间查询查找 Broad Street 地铁站周边 10 米范围内街道的 SQL 示例：

```sql
-- 查找Broad Street地铁站周边10米范围内街道
SELECT name FROM nyc_streets
  WHERE ST_DWithin (geom, ST_GeomFromText ('POINT(583571 4506714)', 26918), 10);
```

### 练习

```sql
-- 名为“Atlantic Commons”的街道的几何值是多少？
SELECT st_astext(geom) FROM "public".nyc_streets WHERE "name" = 'Atlantic Commons';

-- “Atlantic Commons” 位于哪个街区和行政区?
SELECT ns."name", nn.boroname FROM "public".nyc_streets ns INNER JOIN "public".nyc_neighborhoods nn ON st_intersects(ns.geom, nn.geom) WHERE ns."name" = 'Atlantic Commons';

-- “Atlantic Commons” 与哪些街道相连
SELECT ns2."name" FROM nyc_streets ns INNER JOIN nyc_streets ns2 ON st_dwithin(ns.geom, ns2.geom, 0.1) AND ns.gid != ns2.gid WHERE ns."name" = 'Atlantic Commons' ;

-- 大约有多少人居住在 “Atlantic Commons”（50 米范围内）
SELECT SUM(ncb.popn_total) FROM nyc_streets ns INNER JOIN nyc_census_blocks ncb ON st_dwithin(ns.geom, ncb.geom, 50) WHERE ns."name" = 'Atlantic Commons' ;
```

## 空间连接

其实就是连表查询, 但是连接条件是空间关系

### 连接与总结

问题驱动: **Manhattan 区的人口和种族构成是多少？**

> 分析: 人口与种族数据在 census 表, 所以需要连接 nyc_neighborhoods & census 条件是 geom 相交<br>

```sql
-- Manhattan 所有社区的人口和种族构成是多少？
SELECT
  nn."name",
  SUM(ncb.popn_total) AS pop_total,
  100 * SUM(ncb.popn_white) / SUM(ncb.popn_total) AS w_pct,
  100 * SUM(ncb.popn_black) / SUM(ncb.popn_total) AS b_pct
FROM
  nyc_neighborhoods nn
  INNER JOIN nyc_census_blocks ncb ON st_intersects (nn.geom, ncb.geom)
WHERE
  nn."boroname" = 'Manhattan'
GROUP BY
  nn.name
ORDER BY
  w_pct DESC;

-- 整个纽约的人口构成?
SELECT
  SUM(ncb.popn_total) AS pop_total,
  100 * SUM(ncb.popn_white) / SUM(ncb.popn_total) AS w_pct,
  100 * SUM(ncb.popn_black) / SUM(ncb.popn_total) AS b_pct
FROM
  nyc_census_blocks ncb;
```

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

- 空间分析

> 特别注意, 进行度量计算时, 需要把 geomtry 转为 geomgraphy,否则得出的结果单位是度
> 拓扑关系(包含/相交/重叠)时, 在小范围可以不用转换, 但是大范围/高纬度时需要转换,否则不准
> ST_Difference 不支持 geography 类型计算

```sql
-- ST_Buffer(geom, distance) -- 扩大或缩小图形(与圆角?)
SELECT feature_name, ST_Buffer(geom_polygon::geography, 1000)::geometry AS poly FROM "public".learn_table WHERE feature_name = 't_poly_1';
-- 与 buffer 相对的是 ST_Expand ,只扩展边框, 不改变形状
-- ST_Intersection(a, b) -- 求两个多边形的交集
SELECT 'intersection' as feature_name,ST_Intersection(a.geom_polygon, b.geom_polygon) as geom
FROM "public".learn_table a, "public".learn_table b
WHERE a.feature_name='t_poly_1' AND b.feature_name='t_poly_2';
-- ST_Difference(a, b) -- a - b，求差异部分, a图形减去与b图形相交部分
SELECT 'ST_Difference' as feature_name,ST_Difference(a.geom_polygon, b.geom_polygon) as geom
FROM "public".learn_table a, "public".learn_table b
WHERE a.feature_name='t_poly_1' AND b.feature_name='t_poly_2';
-- ST_Intersects(a, b) -- 判断是否相交（边触碰也算）
SELECT 'ST_Difference' as feature_name,ST_Intersects(a.geom_polygon, b.geom_polygon)
FROM "public".learn_table a, "public".learn_table b
WHERE a.feature_name='t_poly_1' AND b.feature_name='t_poly_2';
-- ST_Contains(a, b) -- a 完全包含 b？
SELECT feature_name, ST_Contains(ST_Buffer(geom_polygon::geography, 1000)::geometry, geom_polygon) FROM "public".learn_table WHERE feature_name = 't_poly_1';
-- ST_Within(a, b) -- a 是否在 b 内？
SELECT feature_name, ST_Contains(ST_Buffer(geom_polygon::geography, 0)::geometry, geom_polygon) FROM "public".learn_table WHERE feature_name = 't_poly_1';
-- ST_Overlaps 重叠(同纬度)
SELECT feature_name, ST_Overlaps(ST_Buffer(geom_polygon::geography, 0)::geometry, geom_polygon) FROM "public".learn_table WHERE feature_name = 't_poly_1';

```

- `ST_DWithin()` 判断两个几何是否在指定距离内的函数。

```sql
ST_DWithin(geometry A, geometry B, distance)
-- 或
ST_DWithin(geography A, geography B, distance)
```

- 操作符

```sql
-- 这些操作符可以直接使用索引：
a.geom && b.geom        -- 边界框相交
a.geom ~ b.geom         -- 包含
a.geom @ b.geom         -- 被包含
ST_Contains(a.geom, b.geom)
ST_Within(a.geom, b.geom)

-- 这些函数会自动利用索引：
ST_DWithin(a.geom, b.geom, distance)
ST_Intersects(a.geom, b.geom)  -- 实际上被优化为 && + 精确计算
```

## 索引,性能,优化

### 🧠 Part 1（30 min）空间索引原理（必须理解）

#### 1️⃣ 什么是空间索引（GiST）

- PostGIS 默认使用 **GiST（Generalized Search Tree）**
- 底层是 **R-Tree 思想**
- 索引的是 **最小外接矩形（BBox）**

👉 关键点：

> **索引 ≠ 精确几何**
> 索引先过滤「可能相交的候选」，再做精确计算

---

#### 2️⃣ 没索引 vs 有索引的区别（直觉理解）

| 情况      | 执行方式                     |
| --------- | ---------------------------- |
| ❌ 无索引 | 全表扫描（每个图斑都算一次） |
| ✅ 有索引 | 先用 BBox 排除 99% 无关数据  |

---

### 导入数据

```sql
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
```

### 🧪 Part 2（45 min）创建空间索引（实操）

我们对之前导入的表全部建索引：

```sql
CREATE INDEX idx_counties_geom
ON counties
USING GIST (geom);

CREATE INDEX idx_roads_geom
ON roads
USING GIST (geom);

CREATE INDEX idx_pois_geom
ON pois
USING GIST (geom);

CREATE INDEX idx_land_parcels_geom
ON land_parcels
USING GIST (geom);
```

#### 🔍 验证索引是否存在

```sql
SELECT
  tablename,
  indexname
FROM pg_indexes
WHERE tablename IN ('counties','roads','pois','land_parcels');
```

---

### 🧠 Part 3（45 min）EXPLAIN ANALYZE：读懂执行计划

#### ▶ 没索引（先删一个试试）

```sql
DROP INDEX idx_land_parcels_geom;
```

```sql
EXPLAIN ANALYZE
SELECT *
FROM land_parcels a
JOIN counties c
ON ST_Intersects(a.geom, c.geom);
```

你会看到：

```
Seq Scan on land_parcels
```

---

#### ▶ 有索引（重新建）

```sql
CREATE INDEX idx_land_parcels_geom
ON land_parcels
USING GIST (geom);
```

再执行：

```sql
EXPLAIN ANALYZE
SELECT *
FROM land_parcels a
JOIN counties c
ON ST_Intersects(a.geom, c.geom);
```

你应该看到类似：

```
Bitmap Index Scan using idx_land_parcels_geom
```

🎉 说明索引命中！

---

### 🧠 Part 4（40 min）写「索引友好」的空间 SQL / 理解为什么索引会失效

#### ✅ 正确写法（索引可用）

```sql
SELECT *
FROM land_parcels a
WHERE ST_Intersects(
  a.geom,
  ST_GeomFromText('POLYGON((...))', 4326)
);
```

---

#### ❌ 错误写法（索引失效）

```sql
-- ❌ 对 geom 做函数包裹
SELECT *
FROM land_parcels a
WHERE ST_Intersects(
  ST_Buffer(a.geom, 10),
  some_geom
);
```

💥 原因：

> **索引列不能被函数包裹**<br>
> 实际上是 st_buffer 生成了一个新的几何(无索引), 后续计算使用新几何

---

#### ✅ 正确优化方式

```sql
SELECT *
FROM land_parcels a
WHERE ST_Intersects(
  a.geom,
  ST_Buffer(some_geom, 10)
);
-- 优化思路：使用原始几何的索引，加上距离检查
SELECT *
FROM land_parcels a
WHERE ST_DWithin(a.geom, some_geom, 10)  -- 使用原始几何，索引有效
  AND ST_Intersects(ST_Buffer(a.geom, 10), some_geom);  -- 精确验证
-- 更简单
SELECT *
FROM land_parcels a
WHERE ST_DWithin(a.geom::geography, some_geom::geography, 10);  -- 地理类型，单位：米
-- 精确
-- 如果确实需要缓冲区交集，使用组合条件
-- EXPLAIN ANALYZE  -- 查看执行计划
SELECT *
FROM land_parcels a
WHERE
  -- 阶段1：索引过滤（快）
  a.geom && ST_Buffer(some_geom, 10)  -- 反转：对查询几何做缓冲区
  AND
  -- 阶段2：精确计算（慢，但数据量已减少）
  ST_Intersects(ST_Buffer(a.geom, 10), some_geom);
```

#### 索引友好函数

```sql
-- 这些函数被PostGIS特殊优化，可以使用索引：
WHERE ST_Intersects(a.geom, some_geom)
WHERE ST_Contains(a.geom, some_geom)
WHERE ST_Within(a.geom, some_geom)
WHERE ST_DWithin(a.geom, some_geom, 10)  -- 特殊优化！
WHERE ST_Covers(a.geom, some_geom)
WHERE ST_CoveredBy(a.geom, some_geom)

-- 原理：这些函数内部被重写为使用 && 等索引操作符
```

#### 可能失效函数

```sql
-- 这些函数通常会使索引失效，除非创建函数索引：

-- 1. 几何转换函数
WHERE ST_Transform(a.geom, 3857) && some_geom  -- 失效！
-- 需要：CREATE INDEX idx_transform ON table USING GIST (ST_Transform(geom, 3857))

-- 2. 几何处理函数
WHERE ST_Simplify(a.geom, 0.01) && some_geom  -- 失效！
WHERE ST_SnapToGrid(a.geom, 0.1) && some_geom  -- 失效！

-- 3. 几何生成函数
WHERE ST_Buffer(a.geom, 10) && some_geom  -- 失效！
WHERE ST_ConvexHull(a.geom) && some_geom  -- 失效！
```

#### 永远失效函数

```sql
-- 这些函数因为需要计算属性，无法使用空间索引：
WHERE ST_Area(a.geom) > 1000  -- 失效（计算面积）
WHERE ST_Length(a.geom) > 50   -- 失效（计算长度）
WHERE ST_Perimeter(a.geom) < 100  -- 失效
WHERE ST_NumGeometries(a.geom) > 1  -- 失效
```

#### 索引失效规则

> 规则 1：是否改变几何的坐标或形状？

```sql
-- ❌ 改变几何：索引失效
ST_Buffer(geom, ...)      -- 改变形状
ST_Transform(geom, ...)   -- 改变坐标
ST_Simplify(geom, ...)    -- 改变顶点

-- ✅ 不改变几何：可能使用索引
ST_Envelope(geom)         -- 只是计算属性，不改变存储
ST_Centroid(geom)         -- 生成新点，不改变原几何
```

> 规则 2：是否被 PostGIS 特殊优化？

```sql
-- ✅ 这些函数有特殊优化：
ST_Intersects(geom, other)   -- 优化为：geom && other + 精确计算
ST_DWithin(geom, other, d)   -- 优化为：geom && ST_Expand(other, d)

-- ❌ 这些没有优化：
ST_Buffer(geom, d) && other  -- 没有特殊优化
```

> 规则 3：是否在索引列上使用函数？

```sql
-- 原始列有索引：geom 有 GiST 索引

-- ✅ 直接使用列：索引有效
WHERE geom && some_bbox

-- ❌ 包装函数：索引失效（除非有函数索引）
WHERE ST_Buffer(geom, 10) && some_bbox
WHERE some_function(geom) && some_bbox
```

> 验证

```sql
-- 测试1：不修改几何的函数
EXPLAIN ANALYZE
SELECT * FROM land_parcels a
WHERE ST_Intersects(a.geom, some_geom);
-- 结果：Index Scan（索引有效）

-- 测试2：修改几何的函数
EXPLAIN ANALYZE
SELECT * FROM land_parcels a
WHERE ST_Intersects(ST_Buffer(a.geom, 10), some_geom);
-- 结果：Seq Scan（索引失效）

-- 测试3：计算属性的函数
EXPLAIN ANALYZE
SELECT * FROM land_parcels a
WHERE ST_Area(a.geom) > 1000;
-- 结果：Seq Scan（索引失效）
```

> 特殊情况, 函数索引与组合索引

```sql
-- 创建函数索引后，"修改几何"的函数也能用索引
CREATE INDEX idx_land_buffer ON land_parcels USING GIST (ST_Buffer(geom, 10));

-- 现在这个查询就能用索引了！
EXPLAIN ANALYZE
SELECT * FROM land_parcels a
WHERE ST_Intersects(ST_Buffer(a.geom, 10), some_geom);
-- 结果：Index Scan using idx_land_buffer

-- 复合索引：原始几何 + 缓冲区几何
CREATE INDEX idx_land_combo ON land_parcels USING GIST (geom, ST_Buffer(geom, 10));

-- 两个查询都能用索引：
WHERE ST_Intersects(a.geom, some_geom)  -- 使用第一个字段
WHERE ST_Intersects(ST_Buffer(a.geom, 10), some_geom)  -- 使用第二个字段
```

#### 索引的原理

1. **快速缩小范围**：先用简单的、索引友好的条件过滤掉大部分数据
2. **延迟复杂计算**：对剩余的小部分数据再做复杂的、耗时的计算
3. **选择性顺序**：把过滤性最强的条件放在最前面
4. **避免全表计算**：不要让每行数据都经过复杂函数计算

**PostGIS 的最佳实践**：

```sql
-- ✅ 正确模式：索引过滤 → 精确计算
SELECT *
FROM spatial_table
WHERE simple_indexed_condition   -- 使用索引快速过滤
  AND complex_spatial_function   -- 对少量数据精确计算
  AND other_conditions;          -- 其他条件
```

---

### 🧠 Part 5（30 min）常见性能坑（非常重要）

#### ⚠️ 坑 1：geometry / geography 混用

```sql
-- ❌ 会导致无法用索引
ST_Intersects(geom::geography, other_geom::geography)
```

👉 geography 计算 **慢 + 索引有限**

---

#### ⚠️ 坑 2：坐标系不统一

```sql
-- ❌ SRID 不一致，索引直接失效
ST_Intersects(geom_4326, geom_3857)
```

👉 必须先 `ST_Transform`

---

#### ⚠️ 坑 3：不用 BBox 预筛选

高级优化（了解即可）：

```sql
WHERE geom && other_geom
AND ST_Intersects(geom, other_geom)
```

---

### 🧪 今日实战任务（Checklist）

#### ✔️ 任务 1

给所有空间表建立 GiST 索引

#### ✔️ 任务 2

用 `EXPLAIN ANALYZE` 对比：

- 有索引
- 无索引

#### ✔️ 任务 3

写一条 **“索引友好”** 的图斑相交 SQL

---
