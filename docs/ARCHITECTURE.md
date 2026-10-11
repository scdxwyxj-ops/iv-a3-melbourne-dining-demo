# Shiny 模块结构与接口

四个功能使用同一份数据和公共样式。每个功能目录分为 `ui.R` 与 `server.R`，便于成员独立开发。功能 2 归 Jun Xu，其余功能和公共核心的负责人待定。

## 应用入口

`app.R` 加载核心与四个模块，读取数据，创建导航。在 `server()` 内为每个用户会话创建独立的共享状态，再把 `data` 和 `state` 传给各模块。数据快照为只读对象，可以在会话之间共享。

```r
nearby_ui(id, data)
nearby_server(id, data, state)
```

其他三个模块使用相同参数格式。UI 中每个输入和输出 ID 必须经过 `NS(id)`；server 使用 `moduleServer(id, ...)`。不要在模块文件中创建第二个 `shinyApp()`，也不要依赖另一个模块的内部 input ID。

## 公共核心

| 文件 | 接口与用途 |
|---|---|
| `R/core/data.R` | `load_app_data()`、`landmark_choices()`、`get_landmark()`，统一数据读取和检查 |
| `R/core/geo.R` | `haversine_m()`、`venues_near()`，统一直线距离与范围内场所口径 |
| `R/core/state.R` | `create_shared_state()`，每个会话独立的共享状态 |
| `R/core/components.R` | 页面标题、卡片、指标和明确的占位区域 |
| `R/core/tableau.R` | `tableau_placeholder()`，后续替换为真实集成 |

`data$venues` 为一店一行的 data.frame，`data$landmarks` 为兴趣点记录，`data$boundaries` 为 GeoJSON 列表。区域名称来自 `data$areas`。启动只读取仓库里的快照，不做下载和预处理。

## 共享状态

| 状态字段 | 初始值 | 主要写入功能 |
|---|---|---|
| `area` | Carlton | 功能 1 |
| `landmark_id` | Federation Square 的 `poi_id` | 功能 2 |
| `radius_m` | 600 | 功能 2 |
| `comparison_a_id` | Federation Square 的 `poi_id` | 功能 3 |
| `comparison_b_id` | State Library Victoria 的 `poi_id` | 功能 3 |
| `comparison_radius_m` | 600 | 功能 3 |
| `selected_venue_id` | NULL | 功能 2 选中场所；功能 4 可切换详情 |
| `saved_venue_ids` | 空字符向量 | 功能 4 |

比较页使用自己的景点和半径，避免覆盖功能 2 的探索条件。所有场所关联都使用 `venue_id`；坐标可能共用，名称也可能重复，均不适合作为主键。

共享状态只能在 Shiny 的 reactive 环境中读取和修改。不要把 `reactiveValues()` 放在全局区，否则不同用户可能共享收藏。当前没有跨会话保存功能。

## 功能 2 的起点

`R/modules/nearby/server.R` 已提供 `nearby_venues()` reactive。它返回半径范围内的场所，并附上 `distance_m`，按距离排序。后续地图和列表读取这个对象；用户选择场所时写入 `state$selected_venue_id`，详情页通过同一个 ID 获取记录。

功能 2 的样式写在 `www/css/nearby.css`，公共颜色通过 `var(--color-primary)` 等 token 读取。地图的图例和空状态应复用公共组件。

## 当前边界

四个模块都有可运行布局。功能 1 至 3 的数字预览已连接真实数据；地图、列表和图表仍为占位。功能 4 的收藏为空，保存和导出未接入。没有电车、实时营业状态或步行路线。

公共核心可后续加入 Leaflet 地图组件和 Tableau 事件桥接。加入新依赖时更新 README 的安装说明，应用脚本内不要自动安装包。
