# Widget A/B 收尾与发布规划

更新：2026-10-22。本轮只完成已有 A/B：**B 是创作能力收尾，A 是验收和发布**。不再以 M1–M5 作为开发批次，不新增功能方向。统一在 `codex/release-m1-m2` / [PR #62](https://github.com/everettjf/scriptwidget/pull/62) 交付，App Review 由用户提交。

## 范围固定

保留已实现的记录与模板、Calendar/Reminders/Photos/Health、GitHub、iOS Music 只读、可编辑 Web mock，以及三端 Layout/Theme/Assets/壁纸/公开动画/GIF。复杂 JavaScript 通过 Code 编辑，可视化编辑仅覆盖已支持的 JSX 子集。

Spotify 已移除；C 音乐控制扩展、D 远端/社交/Watch/系统监控已取消，不放回后续 TODO。历史 M/F 编号只用于追溯，见 [历史存档](widget-capabilities-plan-history.md)。

## 当前基线

- 原产品基线 `03fe86d` 之后，已完成独立探针路径、编辑器旧控件隔离、水族箱布局和真实指针 smoke 修复；已有功能不重复开发。
- 本批完整 gate：Mac 675 / iPhone Simulator 685 通过、均 0 失败；最终 Web gate 和构建矩阵通过。iPad 模拟器 685 通过/0 失败/31 跳过，计数与限制见 [状态表](widget-capabilities-status.md)。
- 同一提交的 [Linux/Windows Web Browsers CI](https://github.com/everettjf/scriptwidget/actions/runs/39859999773) 通过。
- 远端先后发现独立探针缺少 `XCTestCore.framework` 搜索路径和真实指针 smoke 抢在遮罩/布局稳定前点击。修复已在本地验证；[最近一次失败](https://github.com/everettjf/scriptwidget/actions/runs/39862348666) 位于旧版 Wallpaper smoke，最终候选仍待新的完整 CI。本地通过不替代远端结果。
- 真机权限、签名共享容器、系统组件和扩展性能尚未完成验收；本轮尚未部署 Web 或上传原生商店构建。

## 按顺序完成四批工作

| 批次 | 对应 TODO | 必做内容 | 完成标准 |
| --- | --- | --- | --- |
| 1. 修复剩余问题 | N01、N03、R05 | 定位 CI 探针依赖；检查相同源码切换文件后的旧表单、按钮和 Undo；修复小号水族箱空格定位排版 | 对确认缺陷先建立复现，再修复并补回归；模板原生/Web 截图逐项检查；远端失败得到实际验证 |
| 2. 完成 B 验收 | N01–N03、R01 | 三端创建→布局/主题/素材→预览→保存重开→导出/安装；核对动态表达式、未知结构、撤销及资源异步边界；完成支持矩阵 | 源码与资源不丢失、不串文件；不支持的可视化结构明确回到 Code；公开动画与静态回退说明准确，有操作与截图证据 |
| 3. 完成 A 真机验收 | R02–R04 | 真实授权/撤权、空数据与离线；GitHub 和逐组件授权；Keychain/app-group/iCloud；WidgetKit、适用的 Control/Live Activity、锁屏/Always On、扩展内存 | 分别记录实际设备、系统、动作、结果与证据；模拟器和 mock 不能替代真机结果；发现发布阻塞缺陷回到修复 |
| 4. 最终回归与发布 | R05–R07 | 冻结候选代码；完整 gate、iPad/iCloud 和设备矩阵；核对版本/build、更新说明与截图/Header/搜索图；Web 部署和原生归档上传 | 测试与材料对应最终代码；部署、上传、线上核对分别有记录；完成后由用户提交 App Review |

批次 1 优先处理已知失败和待验证风险，避免先反复跑完整矩阵。聚焦回归通过后再进入完整 gate。批次 2 可以整理支持说明；批次 3 中不依赖登录的检查先执行，需要真实账号或系统授权时再明确具体操作。

## 验收规则与停止扩展条件

- 只修复影响上述既有范围的缺陷；新增能力不进入本轮。
- 每项分别标注开发完成、自动化通过、真机通过、已部署、已上传。未执行不能勾选。
- 每批结束更新 [TODO](widget-capabilities-todo.md) 和 [状态表](widget-capabilities-status.md)，证据记录在 [实施记录](widget-capabilities-execution.md)。不靠测试总数或代码量表达进度。
- 完整执行 `./Scripts/release-readiness.sh`、适用的 `./Scripts/ipad-icloud-tests.sh` 与 `./Scripts/device-matrix.sh`，并完成 [发布检查](release-readiness.md) 中适用的设备项目。源码变更后重跑受影响的检查，最终完整结果必须对应候选代码。
- 不因本机 Firefox 启动失败阻止其他工作；已有 Linux/Windows 跨浏览器成功证据。本机限制保留记录，不宣称本机通过。
- 缺失的设备、账号或登录单独列出依赖，不把整个范围标成开发未完成。发现数据丢失、权限越界、崩溃或发布检查失败时，修复并重新验证后再发布。

当前批次 1 的产品修复与本地回归已完成，下一步确认最终 CI，然后进入批次 2/3 的剩余验收。本规划完成不代表 A/B 已验收或已发布。
