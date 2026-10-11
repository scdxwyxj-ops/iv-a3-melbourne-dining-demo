# 模块责任与课程交付

四个功能模块分别维护，公共核心由集成负责人维护。当前模块负责人记录如下，未分配项保留为空缺。

## 责任表

| 模块 | 负责人 | 主要文件 | 功能范围 |
|---|---|---|---|
| 区域餐饮概览 | 未分配 | `R/modules/area/`、`www/css/area.css` | 区域地图、选区与餐饮概览、Tableau 图表 |
| 景点周边探索 | Jun Xu | `R/modules/nearby/`、`www/css/nearby.css` | 景点和半径选择、地图与附近列表、场所选择 |
| 双景点对比 | 未分配 | `R/modules/compare/`、`www/css/compare.css` | 同条件比较、类别图表、重叠识别 |
| 地点详情与收藏 | 未分配 | `R/modules/shortlist/`、`www/css/shortlist.css` | 详情、收藏管理、CSV 导出 |
| 公共核心集成 | 未分配 | `app.R`、`R/core/`、`www/css/common.css` | 模块接口、统一样式、依赖与整体集成 |

## 模块协作

各模块读取公共 `data` 对象，通过 `state` 传递选择和收藏 ID。接口约定见[架构说明](ARCHITECTURE.md)。区域概览的 Tableau 工作簿目录为 `tableau/`。

数据口径变更影响全部模块，变更说明需记录受影响字段与统计结果。公共组件或共享状态字段调整后，同步更新接口文档及相关模块。模块内不另行下载或清洗数据。

## 课程要求与交付

项目属于 GEOM90007 Information Visualisation Assignment 3，Group 26。最终界面需基于 R Shiny，并按课程 8.5 方法集成至少一个 Tableau 可视化。四个模块组成同一应用，保持一致的视觉与操作方式。

Part A 与 Part B 的截止时间为 2026 年 11 月 3 日 23:59，Australia/Sydney（AEDT）。Part A 提交包含应用和运行所需数据的 ZIP，报告 PDF 单独提交。

官方说明见 [Part A](https://canvas.lms.unimelb.edu.au/courses/241878/assignments/617019) 和 [Week 8.5 Tableau 与 Shiny 集成](https://canvas.lms.unimelb.edu.au/courses/241878/pages/8-dot-5-pre-lab-tasks-integrating-tableau-into-shiny)，需要相应的 Canvas 访问权限。
