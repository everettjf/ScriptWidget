# Widget 能力阶段交付清单

更新：2026-10-22。用户最新要求移除 Spotify、取消 C/D，实际完成 [A+B](widget-capabilities-plan.md) 并充分测试。当前开发进行中；此表保留其他已有成果，移除后的验证另记，不沿用旧测试计数。代码仍统一在 `codex/release-m1-m2` / PR #62。

## 已实现并纳入本轮

| 范围 | 已有成果 | 实际边界 |
| --- | --- | --- |
| M1/M2：基础和模板 | 真实打卡、饮水、心情、清单记录，持久化/恢复，组件身份隔离，有界时间线和默认样例；天气、公开数据、启动器、本地 Live Activity、植物/宠物等模板及 Gallery | 真实系统调度、共享容器及性能仍需设备验收 |
| M3：个人数据 | 指定来源日历；指定列表提醒事项读取及显式写入、操作回执；选定照片/相册快照与轮换；健康睡眠、活动、运动摘要 | 只使用授权范围内的数据；真实授权/撤权和有限照片选择仍需真机验收 |
| M4：GitHub 和 Music | 原生 GitHub 连接、Keychain 凭据、逐组件授权和受限资料代理；iOS Apple Music 只读播放快照、设置与模板 | macOS Music 明确不可用；没有播放控制 |
| M5：创作工具 | iOS/macOS/Web Layout、Theme、Assets；JSX 支持子集内编辑、撤销和源码保留；公开材质与回退；壁纸裁切和可导出配置 | 动态 JavaScript 继续通过 Code 编辑；Web 材质是有说明的近似效果 |
| M5：公开动画与 GIF | 私有桥接已移除，改用公开时间轴/旋转/位移、有界 ImageIO；原生/Web 时相与静态回退对齐，固定快照时钟统一 | 系统调度不保证永久动画；小号水族箱截断已修复；真实扩展内存/WidgetKit/AOD 验收仍待完成 |
| Web Studio 对齐 | 已新增 API 的可编辑默认样例、授权/空数据/错误场景，服务独立 fixture；浏览器编辑、保存重载和导出验证 | Web 不访问手机私人数据、不连接真实服务，mock 不作为原生真实数据导出 |

## 当前实现的支持矩阵（R01 核对）

此表描述候选源码，不代表已上传版本或真机验收。项目实际最低部署目标是 iOS App/Share **16.0**、iOS Widget 扩展 **18.0**，macOS App/Widget **26.0**。`release-readiness.md` 的旧 iOS 16 Widget 行与现有主分支配置矛盾；已单独向用户确认本次是否恢复旧系统组件，在决定前不更改部署目标、不把该行判为通过。Live Activity 的 App 代码虽从 16.2 可调用，完整系统展示仍受扩展部署目标约束。

| 能力 | iOS / iPadOS 原生 | macOS 原生 | Web Studio | 权限与边界 |
| --- | --- | --- | --- | --- |
| Code / Layout / Theme / Assets | 已实现 | 已实现 | 已实现 | [Layout](visual-layout.md) 只编辑支持的直接 JSX 子集；动态表达式、custom component/fragment 保留在 Code；只读、历史与旧控件边界适用 |
| 记录与模板 | 本地真实记录 | 本地真实记录 | 浏览器项目内模拟记录 | Package 2.0 的 `storage`、组件 owner 隔离；[备份](storage-api.md) 不携带系统健康/服务凭据 |
| Calendar | 选定来源的只读事件 | 同左 | 可编辑 mock | `calendar`，安装身份与系统授权；[来源、缓存、查询限制](calendar-api.md) |
| Reminders | 选定列表读取；显式用户动作写入 | 同左 | 可编辑数据与动作模拟 | 读取 `reminders`；写入还需 `remindersWrite`、声明动作及真实执行授权；[回执与重放](reminders-api.md) |
| Photos | 选定照片/相册的有界快照 | 同左 | 可编辑模拟照片 | `photos`；系统授权不等于选择来源，有限访问与离线来源可能为空；[只读和快照限制](photos-api.md) |
| Health | 仅 HealthKit 报告可用的设备；只读 | 不支持真实读数 | 可编辑样例 / No shared data | `health`，实际安装与授权；不推断单项读取授权，不导出/缓存读数；[聚合与空值](health-api.md) |
| Location | 系统授权、精度与组件可用性检查 | 当前数据契约不支持 | 可编辑 mock | `location`；已有缓存不能证明授权仍有效；[位置边界](location-api.md) |
| GitHub | 原生连接与逐组件批准 | 同左 | 独立模拟数据，无登录 | `services`；profile 另需 `network` 和 `api.github.com`；[Keychain 与撤权](services-api.md) |
| Music | 系统 Music App 的只读快照 | 明确不可用 | 曲目/权限状态 mock | `music`；无播放控制、无任意播放器信息、无第三方 SDK；[平台说明](music-api.md) |
| 材质 / 3D | 公共 SwiftUI 与无障碍回退 | 同左 | 有说明的 CSS 近似 | 无设备视差/传感器；Clear/Tinted 由系统容器决定；[材质预算](visual-effects.md) |
| 壁纸匹配 | 导入自有图片、手工校准裁切、PNG/配置 | 同左 | 指针/数值裁切、配置与包导出 | 不设置系统壁纸，不自动识别桌面位置；[壁纸流程](wallpaper-match.md) |
| 时钟 / 摆动 / GIF | 公共调度与固定/减少动态效果回退 | 静态回退，标准钟针保留正确时相 | 公共预览与固定截图 | 无永久系统播放承诺；GIF 有解码预算；[公开动画](public-animations.md) |
| 组件 / Control / Live Activity | 系统集成已实现；当前 Widget 扩展部署目标 18.0 | Mac Widget；无 iOS 系统入口承诺 | 预览与模拟，不能验证系统行为 | 普通组件动作和 Control 使用声明的动作；Activity 仅本地管理，非远端/交互 Island 控制；[系统边界](widgetkit-modern-features.md) |

数据 API 的精确方法、最低 Runtime API、同步/Promise 和授权类型见自动生成的 [能力目录](data-api-catalog.md)。Package/compiler ABI 1.0 与 public Runtime API 1.4 不等于操作系统版本。安装包需要的权限、host 和版本均须声明；mock 不授予真实权限，也不随组件包导出为私人系统数据。iOS 最低版本决定尚未收口，因此 R01 保留未完成。

## 本轮移除

Spotify 条件接入、授权/刷新、播放读取及内部写操作记录已移除；不是保留未配置提示，也不再列为后续 TODO。GitHub 与 iOS Music 只读能力保留。历史记录不代表当前支持状态。

## 验证与交付状态

最新测试工具收尾：`e311129` 浏览器 CI 两端通过，但 Apple 在存储文件探针退出 3，未进入 XCTest。新探针已用实际持锁复现同类拒绝；仅对未进入锁内的尝试做有界重试，数据/文件损坏均零重试，等待所有进程完成后清理。更新后的完整本地 gate 通过：Mac 701/0/32、iPhone 模拟器 707/0/31，9 项文件探针检查通过。产品代码、200 ms 运行时锁上限和签名输入未变；此前 iPad 707 与构建矩阵保持为独立证据，新提交远端 CI 仍待验证。具体原因不能由原先无诊断的退出码唯一确定。

最新完整 gate 通过：Mac **701 / 0 失败 / 32 跳过**，iPhone 模拟器 **707 / 0 / 31**，iPad 确定性全量 **707 / 0 / 31**，引擎 **174**。构建矩阵和刷新后的签名 Debug 构建/校验通过。工作区连续布局替换、规范路径文件树、观察者释放及新实例先于旧实例销毁的交接已覆盖。预览菜单现可容纳 300 点面板，实际 CUA 窗口显示正常；宿主负宽度警告仍保留。Web 面板键盘导航/编辑区焦点已实测。`4f5cde0` 的 Linux/Windows 浏览器已通过；其 Apple CI 的布局替换失败已有本地复现、修复与回归，须新提交 CI 验证。下方 696/706/706 是历史记录，不能替代本轮结果。完整 App 场景和真机验收仍未完成，具体证据见实施记录末节。

Final local verification: complete `release-readiness.sh` exited 0; the supplementary final Mac full run includes the latest closing-write tests and passed **696 / 0 failed / 32 skipped**. iPhone Simulator and final iPad deterministic full coverage each passed **706 / 0 / 31**. All corresponding runtimeWarnings arrays are empty. SDK/link/Sendable/Xcode diagnostics remain. Final device build matrix and refreshed signed Debug iOS build/deep-strict signature verification passed. These replace the earlier intermediate 694/704 native results; separate runs are not combined into one count. Final Web behavior still includes seven real IndexedDB cases.

Native inbound/outbound saves are fenced by each opening and revision. Copilot snapshots, replacements and explicit saves target one editor/window plus document/session, reject edits since the source snapshot, and confirm writes before reporting saved. Actual WKWebView/package tests cover same-path windows, stale autosave, newer edits, writer failure, no-acknowledgement saves, immediate/readonly switches and asynchronous formatting. Native hosts retain validated incremental UTF-16 recovery buffers; the closing host takes a final snapshot, writes the file before reopening and retains a draft on failure or changed external baseline. Recovered unsaved text is retried through real saving. Tests cover immediate teardown/reopening, closing without reopening, external changes, atomic Unicode edits and independent/multiple closing handoffs.

Seven real IndexedDB cases cover stale save completion, pre-debounce switches, save/delete with late edits, outgoing dirty status, inactive deletion failure/retry, active deletion failure retaining edits, and durable deletion after memory fallback. Aborted transactions retain projects and display an error. Memory operations preserve database order; loaded projects remain available to memory fallback. Before/after production-build screenshots and original failures are in the [execution record](widget-capabilities-execution.md).

Editor 52, engine 172, Studio 96, Gallery sync 2, 91 templates/22 curated packages, service probe 24 and retained browser/native probes pass locally. Aquarium has 16 native/Web captures across eight families: small 4.06%, median 2.82%; fine pixel differences remain documented. Original/final xcresult archives, logs and source hashes for the latest close/handoff fixes are retained under `__Release/capabilities/editor-teardown/`; earlier save/delete evidence and native screenshots remain under `__Release/capabilities/editor-session-target/`.

[Readiness at 99d6f7a](https://github.com/everettjf/scriptwidget/actions/runs/39869682111) failed at negative-clock movement 0 before standalone XCTest probes. Frame/readiness synchronization now passes a controlled delayed-start negative control, while intentionally forward playback still fails. This does not establish the sole cause of the old failure. The complete Apple Readiness step at [56eec76](https://github.com/everettjf/scriptwidget/actions/runs/39874795541) has now passed, including standalone XCTest probes; its iPad step was still running when checked. [Linux/Windows browsers at that head](https://github.com/everettjf/scriptwidget/actions/runs/39874795518) both passed. The later closing fixes still require final-head CI. [Linux/Windows browser CI at a04e3f0](https://github.com/everettjf/scriptwidget/actions/runs/39863618548) passed. Local Firefox startup failure is not a local pass.

The refreshed signed Debug build is **27.1.3 (27013)**, uninstalled and not an App Store archive. App/Share minimum iOS 16, Widget 18, Mac 26. No deployment targets changed; the user's compatibility decision remains pending. Signing metadata does not prove real app/widget Keychain or iCloud access.

A/B remains in progress. Remaining authoring checks include actual window-layout transitions, full keyboard/accessibility and end-to-end workflows; the component-level closing/pending-edit cases above are verified. Real permission/revocation, signed shared containers, WidgetKit/Always On/memory, release materials, Web deployment and native archive/upload remain. No deployment/upload/review submission has occurred. App Review stays manual. See [TODO](widget-capabilities-todo.md) and [plan](widget-capabilities-plan.md).
