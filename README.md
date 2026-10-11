# Melbourne Dining Explorer

GEOM90007 Assignment 3，Group 26 的 R Shiny 协作骨架。四个功能页已有占位布局，公共设计语言与可直接读取的数据已加入。地图、真实 Tableau 图表和收藏交互尚未实现；目前的数值预览使用实际数据。

![功能 2 的 Shiny 占位版界面](docs/preview-nearby.png)

## 本地启动

本项目在 Ubuntu WSL 中管理 Git，并运行 R。应用入口必须从仓库根目录启动。

首次使用，在 R 控制台安装依赖：

```r
install.packages(c("shiny", "jsonlite"))
```

随后启动应用：

```r
shiny::runApp(".", launch.browser = TRUE)
```

WSL 终端也可运行：

```bash
Rscript -e 'shiny::runApp(".", host="127.0.0.1", port=3876, launch.browser=FALSE)'
```

浏览器打开 `http://localhost:3876`。启动不需要下载数据，也不用运行清洗脚本。GitHub 保存代码；完整 Shiny 应用需要 R 服务，不能通过 GitHub Pages 直接运行。

## 四个功能

| 功能 | 目录 | 负责人 | 当前内容 |
|---|---|---|---|
| 1 区域餐饮概览 | `R/modules/area/` | 待认领 | 区域控件、真实数量预览、地图与 Tableau 占位 |
| 2 景点周边探索 | `R/modules/nearby/` | Jun Xu | 景点和半径控件、真实数量预览、地图与列表占位 |
| 3 双景点对比 | `R/modules/compare/` | 待认领 | 同半径数量与重叠预览、地图与类别图表占位 |
| 4 地点详情与收藏 | `R/modules/shortlist/` | 待认领 | 详情、地图与空收藏占位；保存和导出按钮禁用 |

公共核心的集成负责人待定。Jun Xu 只负责功能 2。其他成员的功能归属由团队填写。

## 仓库结构

```text
app.R                       入口和四个页面的组装
R/core/                     数据读取、会话状态、距离计算、公共组件、Tableau 占位
R/modules/area/             功能 1 的 ui.R 与 server.R
R/modules/nearby/           功能 2 的 ui.R 与 server.R
R/modules/compare/          功能 3 的 ui.R 与 server.R
R/modules/shortlist/        功能 4 的 ui.R 与 server.R
www/css/common.css          公共设计 token 与布局
www/css/{功能名}.css        每个功能自己的样式
data/                       可直接使用的 CSV、GeoJSON 与说明
tableau/                    后续工作簿与发布说明
docs/                       结构、设计语言、分工与 AI 使用说明
```

每个功能的界面和交互通过 Shiny module 的 `NS(id)`、`moduleServer(id, ...)` 隔离。队友主要修改自己的功能目录和对应 CSS；数据口径与公共组件由核心统一提供。

## 数据和设计文档

- [数据说明](data/README.md)：字段、清洗口径、来源和许可。
- [结构与接口](docs/ARCHITECTURE.md)：模块接口和共享状态约定。
- [公共设计语言](docs/DESIGN_LANGUAGE.md)：颜色、布局、组件和交互约定。
- [功能分工](docs/TEAM_ASSIGNMENTS.md)：责任范围与待认领项。
- [Tableau 接入](tableau/README.md)：预留图表和后续接入要求。
- [AI 使用记录](docs/STARTER_AI_USAGE.md)：本次骨架的生成范围。

## 作业技术要求

最终产品须使用 R Shiny，并嵌入至少一个真实 Tableau 可视化，按课程 8.5 方法集成。四个页面是一个应用。当前占位版尚未满足真实 Tableau 集成要求。

Part A 与 Part B 截止时间为 2026 年 11 月 3 日 23:59，Australia/Sydney。Part A 提交包含应用和所需数据的 ZIP，报告 PDF 单独提交。官方入口：[Part A](https://canvas.lms.unimelb.edu.au/courses/241878/assignments/617019)。

数据来自 City of Melbourne，按 CC BY 4.0 使用；转换说明见 `data/README.md`。课程课件、原始文件和本地清洗代码均未纳入共享仓库。
