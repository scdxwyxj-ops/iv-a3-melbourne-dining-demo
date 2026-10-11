# Melbourne Dining Explorer

Melbourne Dining Explorer 是一个基于 R Shiny 的墨尔本餐饮探索原型，围绕区域和景点周边的餐饮选择设计。项目使用 City of Melbourne 公开数据，提供区域概览和景点周边探索模块，另设双景点对比与地点收藏模块。

当前版本提供页面骨架与公共组件，区域及景点范围内的数量预览已连接真实数据。地图与餐饮列表仍为占位，Tableau 图表和收藏交互尚未实现。

![景点周边探索模块的占位界面](docs/preview-nearby.png)

## 功能状态

| 模块 | 已实现 | 待实现 |
|---|---|---|
| 区域餐饮概览 | 分区选择、所选区域的场所数量 | 分区地图、Tableau 概览图表 |
| 景点周边探索 | 景点和半径选择、范围内的场所数量 | 地图、附近列表、场所选择 |
| 双景点对比 | 同半径的数量比较、共同场所数量 | 双景点地图、类别比较图表 |
| 地点详情与收藏 | 页面布局、空收藏状态 | 场所详情、保存与移除、CSV 导出 |

占位区域在界面中明确标记，未实现的保存和导出按钮处于禁用状态。

## 运行要求

运行应用需要 R，以及 `shiny`、`jsonlite` 两个 R 包。浏览器用于访问 Shiny 界面。

当前版本在 Ubuntu WSL、R 4.3.3、shiny 1.14.0 和 jsonlite 2.0.0 环境中验证。最低支持版本尚未确定。

应用直接读取仓库中的数据快照，启动前无需下载或清洗数据。完整交互需要运行中的 R 服务，GitHub Pages 无法直接运行此 Shiny 应用。

## 获取与启动

克隆仓库并进入项目根目录：

```bash
git clone https://github.com/scdxwyxj-ops/iv-a3-melbourne-dining-demo.git
cd iv-a3-melbourne-dining-demo
```

首次运行前，在 R 控制台安装依赖：

```r
install.packages(c("shiny", "jsonlite"))
```

将 R 工作目录设为项目根目录后启动：

```r
shiny::runApp(".", host = "127.0.0.1", port = 3876, launch.browser = TRUE)
```

终端启动方式：

```bash
Rscript -e 'shiny::runApp(".", host="127.0.0.1", port=3876, launch.browser=FALSE)'
```

浏览器访问 [http://localhost:3876](http://localhost:3876)。如 3876 端口被占用，可修改命令中的 `port`，并使用对应端口访问。

启动提示缺少包时，在 R 控制台安装提示中的依赖。提示找不到文件时，检查工作目录是否包含 `app.R` 和 `data/`。

## 数据

| 文件 | 内容 |
|---|---|
| `data/venues.csv` | 2024 年餐饮调查快照，1,994 个场所，每行一个场所 |
| `data/landmarks.csv` | 242 条兴趣点记录，包含旅游及非旅游设施 |
| `data/clue_areas.geojson` | City of Melbourne 的 13 个 CLUE 统计分区 |

餐饮表将同一场所的室内外座位记录合并为一行。座位空值表示未知；多个场所可能共享坐标。范围计算使用直线距离，数据不提供实时营业状态或步行路线。字段和处理口径见[数据说明](data/README.md)。

## 代码结构

```text
app.R                       应用入口与页面组装
R/core/                     数据读取、距离计算、会话状态与公共组件
R/modules/area/             区域概览模块
R/modules/nearby/           景点周边探索模块
R/modules/compare/          双景点对比模块
R/modules/shortlist/        详情与收藏模块
www/css/common.css          公共配色与布局
www/css/                    各功能模块的样式
data/                       数据快照、来源说明与文件校验信息
tableau/                    Tableau 工作簿目录与接入说明
docs/                       架构、设计规范与协作文档
```

每个功能目录包含 `ui.R` 和 `server.R`，使用 Shiny module 隔离输入与输出。公共数据口径和组件由 `R/core/` 提供。

## 开发文档

- [模块结构与接口](docs/ARCHITECTURE.md)
- [公共设计语言](docs/DESIGN_LANGUAGE.md)
- [模块责任与课程交付](docs/TEAM_ASSIGNMENTS.md)
- [Tableau 接入说明](tableau/README.md)
- [AI 使用声明](docs/STARTER_AI_USAGE.md)

## 问题反馈

运行问题和功能建议可提交到 [GitHub Issues](https://github.com/scdxwyxj-ops/iv-a3-melbourne-dining-demo/issues)。问题报告应包含复现步骤、错误信息，以及 R 和依赖包的版本。

## 项目背景与许可

项目属于墨尔本大学 GEOM90007 Information Visualisation 的 Assignment 3，Group 26。课程要求最终应用在 R Shiny 中集成至少一个 Tableau 可视化；当前版本尚未完成该集成。

数据发布者为 City of Melbourne，按 [CC BY 4.0](https://creativecommons.org/licenses/by/4.0/) 使用。数据转换与署名信息见[数据说明](data/README.md)。应用代码与文档尚未指定许可证，数据许可不代表整个仓库的代码许可。
