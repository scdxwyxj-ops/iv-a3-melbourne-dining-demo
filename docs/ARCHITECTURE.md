# Shiny 模块结构与接口

应用由四个功能模块组成，共用数据快照和样式。每个功能目录包含 `ui.R` 与 `server.R`；公共接口位于 `R/core/`，模块责任分工见[责任表](TEAM_ASSIGNMENTS.md)。

## 应用入口

`app.R` 加载公共核心与功能模块，读取数据并组装导航。`server()` 为每个用户会话创建独立的状态对象，再把 `data` 和 `state` 传给各模块。只读数据快照可以在会话之间共享。

各模块使用相同的参数形式：

```r
nearby_ui(id, data)
nearby_server(id, data, state)
```

UI 内的输入与输出 ID 通过 `NS(id)` 命名，server 使用 `moduleServer(id, ...)`。应用入口由 `app.R` 统一管理；模块之间通过共享状态交换 ID，不依赖其他模块的内部 input ID。

## 公共核心

| 文件 | 接口与用途 |
|---|---|
| `R/core/data.R` | `load_app_data()`、`landmark_choices()`、`get_landmark()`，统一数据读取和检查 |
| `R/core/geo.R` | `haversine_m()`、`venues_near()`，统一直线距离与范围内场所口径 |
| `R/core/state.R` | `create_shared_state()`，每个会话独立的共享状态 |
| `R/core/components.R` | 页面标题、卡片、指标和占位区域 |
| `R/core/tableau.R` | `tableau_placeholder()`，Tableau 接入位置 |

`data$venues` 为一店一行的 data.frame，`data$landmarks` 为兴趣点记录，`data$boundaries` 为 GeoJSON 列表，`data$areas` 提供分区名称。完整字段说明见[数据文档](../data/README.md)。

## 共享状态

| 字段 | 初始值 | 主要写入模块 |
|---|---|---|
| `area` | Carlton | 区域概览 |
| `landmark_id` | Federation Square 的 `poi_id` | 景点周边探索 |
| `radius_m` | 600 | 景点周边探索 |
| `comparison_a_id` | Federation Square 的 `poi_id` | 双景点对比 |
| `comparison_b_id` | State Library Victoria 的 `poi_id` | 双景点对比 |
| `comparison_radius_m` | 600 | 双景点对比 |
| `selected_venue_id` | NULL | 周边探索选中场所；详情页可切换场所 |
| `saved_venue_ids` | 空字符向量 | 地点详情与收藏 |

比较模块独立保存景点和半径，避免改变周边探索的条件。场所关联使用 `venue_id`，兴趣点关联使用 `poi_id`；名称和坐标均不作为关联键。

`create_shared_state()` 在 `server()` 内调用。状态读写位于 Shiny reactive 环境中，因此不同会话的选择和收藏相互独立。当前没有跨会话持久化功能。

## 周边探索与详情的衔接

`R/modules/nearby/server.R` 的 `nearby_venues()` reactive 返回半径内的场所，包含 `distance_m`，按距离排序。地图和列表后续读取该对象。场所选择交互应写入 `state$selected_venue_id`，详情模块据此获取对应记录。

收藏模块负责维护 `state$saved_venue_ids`。新增、移除和导出均使用场所 ID，座位缺失在详情中显示为 Unknown。

## 样式与依赖

公共样式位于 `www/css/common.css`，模块样式位于对应的 `www/css/{模块名}.css`。模块通过 `var(--color-primary)` 等 CSS token 使用公共配色，组件规范见[设计语言](DESIGN_LANGUAGE.md)。

当前运行依赖为 `shiny` 和 `jsonlite`。增加依赖时同步更新根目录 README 的安装说明；包安装由环境准备完成，应用脚本内不调用 `install.packages()`。

## 实现状态

区域概览、周边探索和双景点对比的数字预览已连接数据。地图、场所列表和类别图表仍为占位，详情与收藏交互未接入。

后续地图可使用 Leaflet，Tableau 接入位置已预留。电车、实时营业状态和步行路线不在当前原型范围内。
