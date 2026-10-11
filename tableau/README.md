# Tableau 工作簿与接入

本目录用于保存区域餐饮概览的 Tableau 工作簿和发布信息。当前版本没有工作簿，`R/core/tableau.R` 提供的图表区域仍为占位。

## 数据与图表口径

图表直接连接仓库中的 `data/venues.csv`。区域字段为 `area`，餐饮类别字段为 `category`。场所数量使用 `COUNTD(venue_id)`，表示各 CLUE 分区的不同场所数；图表不将数量标为密度。

类别颜色与 Shiny 界面一致，规范见[公共设计语言](../docs/DESIGN_LANGUAGE.md)。

## Shiny 接入

课程要求最终 Shiny 应用集成至少一个 Tableau 可视化，集成方法见 [GEOM90007 Week 8.5](https://canvas.lms.unimelb.edu.au/courses/241878/pages/8-dot-5-pre-lab-tasks-integrating-tableau-into-shiny)。课程页面需要相应的 Canvas 访问权限。

工作簿文件保存在本目录。完成发布后，接入说明应记录工作簿文件名、发布 URL 和作者，注明输入数据及图表筛选字段。`R/core/tableau.R` 是 Shiny 侧的接入位置。

若通过 Tableau Public 发布，工作簿会公开。数据署名与许可见[数据说明](../data/README.md)。

## 接入验收

- Shiny 页面能够加载实际工作簿，而非占位区域。
- 图表尺寸适合卡片布局，页面切换后仍能显示。
- 图表的场所数量与 `venues.csv` 一致。
- 如实现联动，Shiny 控件与 Tableau 筛选范围一致。
- 发布内容保留数据来源和许可说明。

Tableau 图表的实现与连接状态应同步更新到根目录 README 的功能表。
