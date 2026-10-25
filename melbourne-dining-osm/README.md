# Melbourne Landmark Dining Explorer — OpenStreetMap version

独立的 R Shiny 应用目录，版本日期：2026-10-25。OpenStreetMap 提供底图，Google Places UI Kit 提供餐厅搜索、列表及详情。本目录不依赖仓库根目录的旧应用或 Tableau 文件，也没有上传真实 API 密钥。

## RStudio 启动

1. 下载并解压整个仓库，进入 `melbourne-dining-osm` 文件夹，打开 `MelbourneDining.Rproj`。不要只下载 `app.R` 或单独运行 server 文件。
2. 首次在 Console 安装依赖：`install.packages("shiny")`。
3. 将 `.Renviron.example` 复制为同目录的 `.Renviron`，填入受限制的浏览器密钥。不要把真实配置提交到 GitHub。文件管理器可能隐藏以点开头的文件；也可以在项目 Console 运行 `file.copy(".Renviron.example", ".Renviron", overwrite = FALSE)`，然后用 `file.edit(".Renviron")` 编辑。
4. 打开 `run_local.R`，点击 **Source**；或打开 `app.R` 点击 **Run App**。使用浏览器打开 `http://127.0.0.1:7463/`。不要同时启动两份应用占用该端口。
5. 修改密钥后，停止并重新启动应用。

需要联网。没有密钥时，OpenStreetMap 底图仍可使用，但 Google 餐厅搜索和详情不可用。本目录不包含 R、RStudio 或本机安装的 R 包。Node.js 仅用于开发测试，日常运行不需要。

## Google 配置

`.Renviron` 内容：

```text
GOOGLE_MAPS_BROWSER_KEY=填入浏览器密钥
PLACES_SESSION_REQUEST_LIMIT=15
```

Google Cloud 项目需有有效计费，启用 **Maps JavaScript API** 和 **Places UI Kit API**。密钥使用网站来源限制，并仅允许这两项 API。本地允许来源：

```text
http://127.0.0.1:7463/*
http://localhost:7463/*
```

不同电脑可以使用相同的本地地址；localhost 限制不是小组成员身份验证。这个版本不读取服务器 Places 密钥或 Google Map ID。云端使用另行配置的部署域名，本次上传不部署或更新云端应用。

Google 查询及详情可能产生费用，计入密钥所属项目。设置合理的 Cloud 配额和预算提醒；预算提醒不是自动停费开关。应用的会话搜索次数限制也不是账单硬上限。

## 当前功能

- 242 个地标候选，可从下拉搜索或地图选择。
- 半径滑块 200–1,200 米，默认 600 米，每步 50 米。距离是坐标直线距离，不是步行路线。
- 主菜系筛选，点击 Search 才发起查询；最多显示 10 家餐厅，固定按距离由近到远排列。
- Google 组件显示其可用的评分、价格、餐厅类型、营业状态和时间，采用亮色模式；缺失信息不补造。
- 编号标记、餐厅列表选择事件与详情联动，显示所选餐厅到地标的直线距离。
- 价格筛选暂时禁用；评分、价格升降序及 popularity 排序已移除。
- 改变地标、半径或菜系会清空旧结果，需要重新搜索；旧异步响应不会覆盖新条件。
- 不保存 Google 餐厅结果；结果在 15 分钟或 Melbourne 日期变化后清除。

餐厅搜索不是完整普查，营业时间请向餐厅确认。最终旅游地标名单及重要性分级仍待小组确认，地图地标使用相同大小。

## 文件结构

```text
melbourne-dining-osm/
  MelbourneDining.Rproj
  app.R
  run_local.R
  .Renviron.example
  .gitignore
  README.md
  R/domain.R
  R/osm_server.R
  data/landmarks.csv
  www/osm-explorer.js
  www/styles.css
  www/terms.html
  tests/osm_server_tests.R
  tests/osm_adapter.test.cjs
```

## 验证

在本目录运行离线测试，不会调用 Google API：

```sh
Rscript tests/osm_server_tests.R
node tests/osm_adapter.test.cjs
```

离线测试覆盖查询校验、距离排序、会话限制和组件联动契约，不代替真实浏览器、计费和密钥配置验收。手工检查：搜索后有结果；改变半径清空结果；点击餐厅标记或卡片时地图与详情对应。

## 作业提交与来源

GitHub 版不含真实 `.Renviron`。若学校要求解压即可使用，可在单独的作业提交副本中加入作业专用、受限制的 `.Renviron`，通过学校提交系统交付，确认 ZIP 包含这个隐藏文件；不要把带密钥的 ZIP 上传到公开仓库。保持密钥有效直至评分与复核结束，随后停用。

地标来自 City of Melbourne 开放数据，CC BY 4.0；处理包括字段规范化和稳定标识生成，并不代表数据提供方认可本应用。OSM 和 Google 官方组件署名保留；应用不抓取 Google 组件内部数据，不调用普通 Places REST 作为非 Google 地图的后备。Leaflet 从 CDN 加载，OSM 瓦片不离线预取。

代码由 Codex 协助编写，请按课程规定披露并理解、验收代码。

- [City of Melbourne 地标数据](https://data.melbourne.vic.gov.au/explore/dataset/landmarks-and-places-of-interest-including-schools-theatres-health-services-spor/information/)
- [CC BY 4.0](https://creativecommons.org/licenses/by/4.0/)
- [Google Places UI Kit 配置](https://developers.google.com/maps/documentation/javascript/places-ui-kit/get-started)
- [Google Maps 安全建议](https://developers.google.com/maps/api-security-best-practices)
- [Google Maps 服务条款](https://cloud.google.com/maps-platform/terms/maps-service-terms)
- [OSM 瓦片政策](https://operations.osmfoundation.org/policies/tiles/)
