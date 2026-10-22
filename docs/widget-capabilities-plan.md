# Widget A/B 完整交付规划

更新：2026-10-22。用户最新要求：**删除 C/D，移除已开发的 Spotify，将 A 和 B 做完整并充分测试。** 当前目标已恢复开发，不再沿用暂停状态。仍在 `codex/release-m1-m2` / [PR #62](https://github.com/everettjf/scriptwidget/pull/62) 统一提交。App Review 由用户提交。

## 范围

保留基础记录和模板、个人数据、GitHub 资料、iOS Music 只读快照、三端创作工具和对应 Web mock。移除 Spotify 原生授权/刷新/播放读取、设置、配置回调、内部写记录、公开接口、Web fixtures、补全及现行文档中的支持说明。C 音乐控制扩展与 D 远端/社交/Watch/系统监控不再作为后续待办保留。

历史 F/M 编号仅用于追溯，不能作为当前完成状态。旧规划见 [历史存档](widget-capabilities-plan-history.md)，实际状态以 [TODO](widget-capabilities-todo.md) 和 [执行记录](widget-capabilities-execution.md) 为准。

## 执行顺序

| 顺序 | 工作包 | 验收出口 |
| --- | --- | --- |
| 1 | 移除 Spotify 并固定支持矩阵 | 原生/Web 接口、UI、配置、生成文档和两端 bundle 一致；不支持的提供方明确拒绝、不发 HTTP |
| 2 | B：创作与动画收口 | 完整走通三端 Layout/Theme/Assets/壁纸；修复实际问题；公开动画方案、兼容/辅助功能回退验证；源码往返、撤销和资源边界可靠 |
| 3 | A：个人数据、存储和系统入口验收 | 权限与撤权、有限照片、提醒动作、GitHub、签名容器、WidgetKit/Control/Live Activity 等适用项逐项有证据 |
| 4 | A+B 最终回归 | 聚焦回归、真实浏览器/WKWebView、双平台 build、完整 gate、iPad/iCloud 和设备矩阵；截图和性能证据与最终代码对应 |
| 5 | 发布 | 核对版本、更新说明和宣传素材，Web 部署、原生归档/上传分别可追踪；用户手动提交 App Review |

## B：创作体验与公开动画

- **N01**：复核三端创建→布局/主题/素材→预览→保存/重开→导出/安装流程。修复诊断、键盘/读屏、文件切换和资源操作问题，防止迟到回调修改另一项目。
- **N02**：处理旧时钟/摆动/GIF 私有动画桥接，验证公开 API、系统实际限制与静态回退，更新模板/文档。不能把移除私有符号等同于持续动画行为一致。
- **N03**：以当前受支持的 JSX 子集为明确产品范围，验证字面量/动态表达式混合、未知结构、多个 render scope、陈旧命令、撤销及 package 往返。代码编辑仍支持复杂表达式；只有证据证明可靠时才扩展视觉编辑范围，不承诺任意 JS 的可视化映射。

B 的出口是现有创作能力可靠、限制明确、三端流程可用，不是把暂不支持的源码自动改写成“能编辑”的结构。

## A：真实验收与发布

按 [R01–R07](widget-capabilities-todo.md) 推进：固定支持矩阵；个人数据与服务边界；签名 Keychain/app-group/iCloud；WidgetKit 实际交付、辅助功能和扩展资源；iPad/设备矩阵；发布材料与构建；部署/上传核对。

自动化测试、模拟数据、签名设备和线上发布分别记账。真实设备、账号或登录缺失时，继续完成不依赖它们的工作，列出准确剩余条件，不把未执行写成通过。发现阻塞项必须修复或作明确发布处置，不以绿测试替代。

## 测试要求

- Spotify 移除回归：原生/Web 不支持的 provider 及缺失的 playback 方法、无残留回调/client/UI、GitHub 功能和权限保护保持有效。
- 创作回归：模型边界、原生实际 WKWebView、真实浏览器操作、原生/Web 树、编辑/历史/文件切换、保存重开、导出和资源安全。
- 动画/视觉回归：公开路径、时区/周期、异常参数、Reduce Motion/reduced luminance、快照/静态回退和实际截图。
- 最终执行 `./Scripts/release-readiness.sh`、适用的 `./Scripts/ipad-icloud-tests.sh` 与 `./Scripts/device-matrix.sh`，并完成 [发布清单](release-readiness.md) 中的实际设备项目。
- 元数据变更同步生成 API 文档与两端 editor bundle；纯模拟器证据不能证明物理扩展内存、AOD 或签名容器行为。

当前为实施中，不将历史 Mac 706 / iPhone Simulator 716 的结果用作移除 Spotify 后代码的验证。每次实现变更重新记录对应证据。
