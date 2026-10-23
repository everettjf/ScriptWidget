# Widget A/B TODO

更新：2026-10-22。用户已要求启动 A+B 完整交付，移除 Spotify，取消 C/D。只维护当前 [A/B 规划](widget-capabilities-plan.md)，不保留已取消方向的候选任务。

## 范围清理

- [x] **X01** 移除 Spotify 原生代码/UI/回调/client 配置、运行时接口/内部操作记录、Web mock/状态选择、生成元数据及当前支持文档；保留 GitHub、Music、GIF 和其他既有能力。
- [x] **X02** 原生与 Web 的不支持 provider 回归、接口一致性、两端工程文件和完整 gate 通过；旧未发布 Spotify 草稿明确报错，不静默换数据源。

X01/X02 证据：最终完整 gate 退出 0，Mac 661 / iPhone Simulator 671 均 0 失败；服务 probe 24、Web Studio 96 及所有保留的浏览器流程通过。确切结果见 [实施记录](widget-capabilities-execution.md)。其余 A/B 项尚未据此勾选。

## 阶段性收尾（2026-10-22）

用户要求停止继续展开开发，已有改动提交到同一分支，未完成项保留在本文件。下列清单是后续任务，不表示本次已验收或必须继续实施。

- **已实现**：真实记录与模板、个人数据 API、GitHub 和 iOS Music 只读、三端创作工具、公开动画/GIF、Web 可编辑 mock；Spotify 已移除，C/D 已取消。
- **已修复**：编辑器会话/窗口隔离、保存回执、关闭和切文件丢输入、布局替换交接、Web 删除失败丢草稿、预览窄面板及测试探针竞争诊断。
- **本地验证**：最新完整 gate Mac 701/0/32、iPhone 模拟器 707/0/31；此前独立 iPad 707/0/31、构建矩阵和签名 Debug 校验通过。跳过项与真机限制不计为通过。
- **远端验证**：`2c9b89d` 的 [Linux/Windows 浏览器 CI](https://github.com/everettjf/scriptwidget/actions/runs/39885727555) 通过；[Apple CI](https://github.com/everettjf/scriptwidget/actions/runs/39885727563) 收尾核对时仍运行中，后续核对终态；如失败另列缺陷。
- **兼容范围已确认**：App/Share iOS 16+，Widget iOS 18+，Mac 26+；修正文档，不恢复旧版 Widget。
- **交付边界**：已准备 27.1.3 (27013) 签名 Debug，未安装；未完成分发归档、Web 部署、商店上传或审核提交。App Review 由用户提交。

后续优先核对 CI，再处理下列验收和发布任务；不再追加功能。完整历史与确切证据见 [实施记录](widget-capabilities-execution.md)。

## B：创作能力完善

- [ ] **N01（进行中）** 已修复原生图片列表并发刷新乱序覆盖及陈旧错误提示，回归在两端实际 WKWebView 通过。Animation Aquarium 已改用独立元素，小号截断和换行已修复；16 张比较中位差异 2.82%、小号 4.06%，像素对齐差异保留说明。继续完整走查三端 Layout/Theme/Assets/壁纸流程；修复诊断、键盘/无障碍、文件/资源和异步操作实际缺陷，补回归与截图。
- [ ] **N02（实现及自动化已完成，系统实机表现待 R04）** 已移除私有桥接，改用 Foundation/SwiftUI/ImageIO；对齐负周期、时区/锚点、固定日期、摆动及 GIF 帧时序。Mac/减少动态效果的标准钟针显示正确静态时间。最终两端完整 gate、iPad 状态测试、构建矩阵和 Chromium/WebKit 实际渲染检查通过；Firefox 本地启动失败；Linux/Windows 跨浏览器 CI 已通过（见规划中的确切运行链接）；真实 WidgetKit/AOD/扩展内存不计作已验收。
- [ ] **N03** 彻底验证支持的 JSX 子集：源码保留、动态属性、未知结构、scope、陈旧命令、撤销、保存重开和 package 往返；复杂表达式继续可用 Code 编辑。已修复相同源码跨文件与同文件重绘的旧控件事件；继续完成其他支持子集、往返和三端流程验收。

N03 当前检查点：本批已确认缺陷均有实际桥接/文件或 IndexedDB 失败证据；最终完整 gate、补充 Mac 全量及最终 Web gate 已通过。覆盖真实写入失败、更新代码冲突、异步格式化和删除失败/重试。剩余生命周期、键盘/无障碍与完整操作验收不据此勾选，最终远端 CI 尚待验证。证据见实施记录末节。

最新补充：完整 gate 通过，Mac 701、iPhone 模拟器 707，均 0 失败，跳过 32/31；iPad 确定性全量 707/0/31，构建矩阵和签名 Debug 构建/校验通过。Mac 预览控件旧布局需 701 点，现已通过 300/360/900 点、最长尺寸名称及单个/全部画布测量；实际 CUA 窗口显示正常。宿主负宽度警告仍保留，不能据此宣称完整 App 场景验收完成。`4f5cde0` 的 Linux/Windows 浏览器 CI 已通过；Apple CI 在连续布局替换时读到旧内容，已补新实例创建顺序修复与两端回归，须新提交 CI 验证。

## A：当前版本验收与发布

| ID | 待办 | 完成标准 |
| --- | --- | --- |
| R01 | [ ] 支持矩阵和说明 | 兼容范围已确认并修正文档；继续核对 iOS/macOS/Web 权限和支持子集说明；无 Spotify 功能承诺；Music iOS 只读 |
| R02 | [ ] 真实个人数据 | Calendar/Reminders/Health 授权与撤权、有限 Photos、空数据/离线及提醒事项动作有证据 |
| R03 | [ ] 账户和存储边界 | GitHub 连接/逐组件授权；签名 app/widget Keychain、app-group/iCloud、锁定、断开重连、owner 隔离 |
| R04 | [ ] 系统组件和视觉性能 | 实际时间线/点击/锁屏、适用 Control/Live Activity、Clear/Tinted/Always On、扩展内存；动画替代方案与实际回退验收 |
| R05 | [ ] 最终测试矩阵 | 完整 gate、iPad/iCloud、设备矩阵、三端编辑和代表模板；分开记录模拟器、真机及未执行项 |
| R06 | [ ] 发布候选材料 | 实际版本/build、更新说明、截图/Header/搜索图对应最终功能，PR 与发布记录一致 |
| R07 | [ ] 部署上传 | 验收后 Web 部署、原生归档/上传和线上核对分别有证据；用户操作必要登录，自行提交 App Review |

按稳定 ID 链接实际代码、测试和验收结果。开发完成、自动化通过、真机验收、已部署和已上传不得混用；未执行项不能勾选。
