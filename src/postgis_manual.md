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

### pgadmin 数据恢复

下载的数据包中存在 `nyc_data.backup` 文件, 右键`nyc`数据库选还原,并上传对应数据包的所有数据

选中`nyc_data.backup`即可, 详见 [此](https://postgis.net/workshops/zh_Hans/postgis-intro/loading_data.html)

> 只上传 nyc_data,backup 好像是不行的 ? 实践中以这个方式还原会出错

### ogr2ogr 导入 shp 文件

```bash
ogr2ogr   -nln nyc_census_blocks_2000   -nlt PROMOTE_TO_MULTI   -lco GEOMETRY_NAME=geom   -lco FID=gid   -lco PRECISION=NO   Pg:"dbname=nyc host=localhost user=postgres port=8096 password=123456" -progress  E:\MineSoft\noob_postgis\.database\postgis-workshop\data\2000\nyc_census_blocks_2000.shp
```
