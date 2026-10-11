# 数据快照

本目录提供应用可直接读取的餐饮、兴趣点和 CLUE 分区数据。快照整理日期为 2026 年 10 月 11 日；餐饮数据的调查年份为 2024 年。整理日期不代表各数据集的调查或更新时间。

## 文件与读取

| 文件 | 记录单位与规模 | 用途 |
|---|---|---|
| `venues.csv` | 1,994 个餐饮场所，每行一个场所 | 餐饮位置、类别与座位属性 |
| `landmarks.csv` | 242 条兴趣点记录 | 景点候选与起点坐标 |
| `clue_areas.geojson` | 13 个 CLUE 分区 | 区域边界与分区名称 |
| `manifest.json` | 来源、转换规则、计数与 SHA-256 | 快照说明与文件一致性检查 |

CSV 使用 UTF-8 编码和逗号分隔。GeoJSON 保留源数据的几何与属性。目录分发的是处理后的固定快照，原始导出和处理脚本未包含在仓库中。

在项目根目录的 R 控制台读取：

```r
source("R/core/data.R")
data <- load_app_data("data")
nrow(data$venues)       # 1994
nrow(data$landmarks)    # 242
length(data$boundaries$features)  # 13
```

`load_app_data()` 检查必需字段、ID 唯一性、坐标、数据范围及记录数，并核对餐饮分区名称与边界名称。文件 SHA-256 保存在 `manifest.json`，供单独检查文件一致性；加载函数不会自动校验 SHA-256。

## 餐饮记录的处理

2024 年原始导出包含 3,249 行。筛选 ANZSIC 4511（Cafes and Restaurants）与 4512（Takeaway Food Services）后，保留 2,893 条座位记录。源数据可能将同一场所的室内、室外座位分别记录。

场所合并键由调查年、`property_id`、规范化店名和营业地址组成。规范化用于合并与生成稳定 ID，包括去除首尾空白、折叠连续空白及忽略大小写；显示店名和地址保留原始文字。

合并结果为 1,994 个场所，其中咖啡馆与餐厅 1,645 个，外卖 349 个。室内外座位转为两个字段。未记录的座位类型保留空值，不能按零座位解释。

合并组内的类别、坐标与分区一致。所选记录没有重复座位类型或缺失坐标。

## 餐饮字段

| 字段 | 含义与读取约定 |
|---|---|
| `venue_id` | 稳定字符 ID，用于场所关联和跨页面选择 |
| `census_year` | 调查年份，当前为 2024 |
| `property_id` | 来源属性 ID，按字符读取 |
| `name`、`address` | 原始店名和营业地址 |
| `area` | CLUE 分区名称，对应 GeoJSON 的 `featurenam` |
| `category_code` | 字符代码 4511 或 4512 |
| `category` | 展示类别名称 |
| `longitude`、`latitude` | 十进制度的经度与纬度 |
| `indoor_seats`、`outdoor_seats` | 记录中的座位数，空值表示未知 |

`load_app_data()` 将年份、坐标和座位字段转为数值，其他字段保留为字符。

## 兴趣点与分区

`landmarks.csv` 保留源数据的全部 242 条记录，加入稳定的 `poi_id`，并将嵌套坐标展开。字段为 `poi_id`、`name`、`theme`、`sub_theme`、`longitude`、`latitude`。

兴趣点包含学校等非旅游设施，数据集不构成完整的旅游景点清单。初始界面显示六个候选，由 `R/core/data.R` 中的 `landmark_choices()` 定义。

CLUE 是 Census of Land Use and Employment 的简称。`clue_areas.geojson` 保留 13 个统计分区，几何未简化。分区覆盖 City of Melbourne 的多个区域，不限于 CBD，也不等同于所有 suburb 边界。

## 距离与数据限制

GeoJSON 坐标顺序为 longitude、latitude。`venues_near()` 使用 Haversine 直线距离和 6,371,008.8 米的平均地球半径，返回指定半径内的场所，附加 `distance_m` 并按距离排序。

600 米半径的核对结果为 Federation Square 303 个场所、State Library Victoria 619 个场所，交集 65 个。计算示例在项目根目录运行：

```r
source("R/core/data.R")
source("R/core/geo.R")
data <- load_app_data("data")
fed_id <- unname(landmark_choices(data)[["Federation Square"]])
nrow(venues_near(data, fed_id, radius_m = 600))  # 303
```

1,994 个场所对应 1,133 组不同坐标，同一建筑内的多家店可能共享位置。场所关联应使用 `venue_id`，坐标不适合作为去重键，也不代表精确入口。

数据未提供营业时间、价格或菜系。餐饮记录为历史快照，直线距离不代表步行路线或行程时间。

## 来源与许可

三份源数据均由 City of Melbourne 发布，许可为 [Creative Commons Attribution 4.0](https://creativecommons.org/licenses/by/4.0/)。本快照经过类别筛选、记录合并及格式转换，具体规则见上文和 `manifest.json`。

- [Cafes and restaurants with seating capacity](https://data.melbourne.vic.gov.au/explore/dataset/cafes-and-restaurants-with-seating-capacity/information/)，使用 2024 年记录。
- [Landmarks and places of interest](https://data.melbourne.vic.gov.au/explore/dataset/landmarks-and-places-of-interest-including-schools-theatres-health-services-spor/information/)。
- [Small areas for Census of Land Use and Employment](https://data.melbourne.vic.gov.au/explore/dataset/small-areas-for-census-of-land-use-and-employment-clue/information/)。

再利用时保留 City of Melbourne 署名，并附上来源、许可链接和变换说明。`manifest.json` 记录原始导出 URL、下载时间、源文件 SHA-256，以及本目录数据文件的 SHA-256。
