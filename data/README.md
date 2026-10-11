# 可直接使用的数据快照

队友可以直接读取本目录中的三份数据，不需要执行清洗脚本。快照整理日期为 2026 年 10 月 11 日。原始下载文件和处理代码留在本地，未提交到共享仓库。

## 文件

| 文件 | 单位与规模 | 用途 |
|---|---|---|
| `venues.csv` | 2024 年，1,994 个餐饮场所，每行一家店 | 四页共用的餐饮点和属性 |
| `landmarks.csv` | 242 条兴趣点记录 | 景点候选和起点坐标 |
| `clue_areas.geojson` | 13 个 CLUE 分区 | 区域地图与边界 |
| `manifest.json` | 来源、变换说明、计数与 SHA-256 | 说明数据快照及检查结果 |

这三个文件就是原先所说的 processed 数据，已直接放在 `data/`。prepare 原本指生成这些结果的脚本；应用不需要它，仓库也不包含数据下载或清洗 pipeline。

## 餐饮口径

原始 2024 年导出有 3,249 行。筛选 ANZSIC 4511（Cafes and Restaurants）和 4512（Takeaway Food Services）后有 2,893 条座位记录。原表可能把同一场所的室内、室外座位分成不同的行。

用调查年、property_id、规范化店名及营业地址作为合并键，得到 1,994 个场所。规范化只用于合并和生成稳定 ID：去除首尾空白，折叠连续空白，并忽略大小写。显示店名和地址保留原始文字。

室内、室外座位转成两个字段。同一类型没有记录时保留空值，含义为未知，不能填成 0。坐标、类别与分区在合并组内一致；没有重复座位类型或缺失坐标。咖啡馆与餐厅 1,645 个，外卖 349 个。

## 字段约定

`venues.csv` 为 UTF-8、逗号分隔。

| 字段 | 类型与含义 |
|---|---|
| `venue_id` | 稳定字符 ID，用于页面间传递和关联 |
| `census_year` | 2024，调查年份 |
| `property_id` | 来源属性 ID，按字符读取 |
| `name`、`address` | 原始店名和营业地址 |
| `area` | CLUE 分区名称，与 GeoJSON 的 `featurenam` 对应 |
| `category_code` | 字符 4511 或 4512 |
| `category` | 展示类别名称 |
| `longitude`、`latitude` | 经度、纬度；十进制度 |
| `indoor_seats`、`outdoor_seats` | 记录中的座位数；空白代表未知 |

`landmarks.csv` 的字段为 `poi_id`、`name`、`theme`、`sub_theme`、`longitude`、`latitude`。它保留原始全部 242 条记录，将嵌套坐标展开并加入 ID。数据包含学校等非旅游设施，不能称为全部旅游景点。初始 UI 只列出公共数据中选出的六个候选；团队可调整候选，不用重新下载。

`clue_areas.geojson` 保留原始几何和属性，没有简化。分区为 City of Melbourne 的 CLUE 统计区域，覆盖范围不限于 CBD；它们也不等同于所有 suburb 边界。

## 地理计算

坐标使用经纬度；GeoJSON 顺序为 longitude、latitude。半径使用 Haversine 直线距离，平均地球半径 6,371,008.8 米。600 米内的检查结果：Federation Square 303 个、State Library Victoria 619 个、共同场所 65 个。

同一建筑内的多家店可能共享坐标：1,994 个场所只有 1,133 组不同坐标。不能按坐标去重，也不能将这些位置解释为精确入口。数据没有营业时间、价格或菜系，也不是实时营业清单。

## 来源与许可

数据发布者均为 City of Melbourne，许可为 [Creative Commons Attribution 4.0](https://creativecommons.org/licenses/by/4.0/)。本仓库进行了上述格式转换、类别选择和座位合并。使用、展示或再次发布时保留 City of Melbourne 署名、来源链接、许可和变换说明。

- [Cafes and restaurants with seating capacity](https://data.melbourne.vic.gov.au/explore/dataset/cafes-and-restaurants-with-seating-capacity/information/)，仅使用 2024 年快照。
- [Landmarks and places of interest](https://data.melbourne.vic.gov.au/explore/dataset/landmarks-and-places-of-interest-including-schools-theatres-health-services-spor/information/)。
- [Small areas for Census of Land Use and Employment](https://data.melbourne.vic.gov.au/explore/dataset/small-areas-for-census-of-land-use-and-employment-clue/information/)。

原始导出 URL、下载时间和 SHA-256，以及清洗后文件的 SHA-256，记录在 `manifest.json`。不把整理日期当作调查日期。
