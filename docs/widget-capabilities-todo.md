# Widget A/B TODO

更新：2026-10-22。用户已要求启动 A+B 完整交付，移除 Spotify，取消 C/D。只维护当前 [A/B 规划](widget-capabilities-plan.md)，不保留已取消方向的候选任务。

## 范围清理

- [x] **X01** 移除 Spotify 原生代码/UI/回调/client 配置、运行时接口/内部操作记录、Web mock/状态选择、生成元数据及当前支持文档；保留 GitHub、Music、GIF 和其他既有能力。
- [x] **X02** 原生与 Web 的不支持 provider 回归、接口一致性、两端工程文件和完整 gate 通过；旧未发布 Spotify 草稿明确报错，不静默换数据源。

X01/X02 证据：最终完整 gate 退出 0，Mac 661 / iPhone Simulator 671 均 0 失败；服务 probe 24、Web Studio 96 及所有保留的浏览器流程通过。确切结果见 [实施记录](widget-capabilities-execution.md)。其余 A/B 项尚未据此勾选。

## B：创作能力完善

- [ ] **N01** 完整走查三端 Layout/Theme/Assets/壁纸流程；修复诊断、键盘/无障碍、文件/资源和异步操作实际缺陷，补回归与截图。
- [ ] **N02** 完成旧时钟/摆动/GIF 公开动画路径及兼容/静态回退验证，更新模板与限制说明；实际行为和公开符号分别验收。
- [ ] **N03** 彻底验证支持的 JSX 子集：源码保留、动态属性、未知结构、scope、陈旧命令、撤销、保存重开和 package 往返；复杂表达式继续可用 Code 编辑。

## A：当前版本验收与发布

| ID | 待办 | 完成标准 |
| --- | --- | --- |
| R01 | [ ] 支持矩阵和说明 | iOS/macOS/Web、系统版本、权限和支持子集准确；无 Spotify 入口/功能承诺；Music iOS 只读 |
| R02 | [ ] 真实个人数据 | Calendar/Reminders/Health 授权与撤权、有限 Photos、空数据/离线及提醒事项动作有证据 |
| R03 | [ ] 账户和存储边界 | GitHub 连接/逐组件授权；签名 app/widget Keychain、app-group/iCloud、锁定、断开重连、owner 隔离 |
| R04 | [ ] 系统组件和视觉性能 | 实际时间线/点击/锁屏、适用 Control/Live Activity、Clear/Tinted/Always On、扩展内存；动画替代方案与实际回退验收 |
| R05 | [ ] 最终测试矩阵 | 完整 gate、iPad/iCloud、设备矩阵、三端编辑和代表模板；分开记录模拟器、真机及未执行项 |
| R06 | [ ] 发布候选材料 | 实际版本/build、更新说明、截图/Header/搜索图对应最终功能，PR 与发布记录一致 |
| R07 | [ ] 部署上传 | 验收后 Web 部署、原生归档/上传和线上核对分别有证据；用户操作必要登录，自行提交 App Review |

按稳定 ID 链接实际代码、测试和验收结果。开发完成、自动化通过、真机验收、已部署和已上传不得混用；未执行项不能勾选。
