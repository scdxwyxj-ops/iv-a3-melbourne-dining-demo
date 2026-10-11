# 四个功能的责任范围

Jun Xu 已确定负责功能 2。其余三个功能由队友各自认领，公共核心的集成负责人另行确定。本表只记录当前已确认的分工。

| 功能 | 负责人 | 主要修改文件 | 最终功能 |
|---|---|---|---|
| 1 区域餐饮概览 | 待认领 | `R/modules/area/`、`www/css/area.css` | 区域地图、选区与餐饮概览、Tableau 图表 |
| 2 景点周边探索 | Jun Xu | `R/modules/nearby/`、`www/css/nearby.css` | 景点和半径选择、地图与附近列表、场所选择 |
| 3 双景点对比 | 待认领 | `R/modules/compare/`、`www/css/compare.css` | 同条件双景点比较、类别图表、重叠识别 |
| 4 地点详情与收藏 | 待认领 | `R/modules/shortlist/`、`www/css/shortlist.css` | 详情、收藏管理与 CSV 导出 |
| 公共核心集成 | 待定 | `app.R`、`R/core/`、`www/css/common.css` | 模块接口、统一样式、依赖和整体集成 |

功能 1 的 Tableau 工作簿放在 `tableau/`。数据修改影响全部页面，应先说明变更口径；各模块只读取 `data`，不各自另行清洗或下载数据。

当前 GitHub 账户为 `scdxwyxj-ops`。队友的 GitHub 用户名未提供，未添加协作者，也没有代发邀请。功能归属不等于仓库访问权限。
