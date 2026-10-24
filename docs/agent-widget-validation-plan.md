# 用现有 Coding Agent 生成 Widget：Skill、校验与预览方案

日期：2026-10-23。状态：产品与工程提案；本次整理现有能力和待交付范围，不新增模型、推理服务或产品功能。

## 建议：把校验与预览作为主线

面向已经使用 Coding Agent 的开发者，建议优先交付 **官方生成 Skill + CLI/MCP 校验工具 + Web 预览**。模型由用户自己的 Agent 提供，我们负责把 ScriptWidget 的语法、API、包格式和反馈闭环做好。Mac 原生校验作为准确性增强，接入已有 Mac App，不先另做一个独立应用。

这一方案可覆盖开发者的核心路径：描述需求 → Agent 创建组件包 → 调用校验与渲染 → 查看诊断和图片 → 修改 → 用户预览并安装。它不保证任意模型都能一次生成正确组件，但可以让失败具体、可复现、可修复。

[Mac 本地模型方案](local-widget-model-plan.md)保留为后续选项，建议先不投入微调和在线推理服务。没有自有模型也能交付这一工作流；不使用 Coding Agent 的普通用户，仍可使用现有模板和 App 内 AI 入口。

## 1. 已有能力与实际缺口

以下结论来自本仓库代码核对，不把已存在的能力列为新开发。

| 能力 | 已有实现 | 待完成的产品化 |
| --- | --- | --- |
| Web 预览与 mock | [Web Studio](web-studio-browser.md)支持编辑、导入、运行、Problems、可编辑 mock 和导出 | 提供直接进入“粘贴/打开组件 → 校验与预览”的入口，以及可复制/下载给 Agent 的报告 |
| 本地 CLI | [scriptwidget-preview.mjs](../Web/preview-engine/bin/scriptwidget-preview.mjs)输出 PNG、JSON 诊断，支持尺寸、macos profile、浅深色和 watch | 独立安装包、文档、稳定的报告契约和清楚的依赖提示；当前需要仓库中的运行时资源及 Chrome/Chromium |
| MCP | [scriptwidget-mcp.mjs](../Web/preview-engine/bin/scriptwidget-mcp.mjs)提供 `render_widget_preview`、`validate_widget_package`、`export_widget_package` | 核对目标 Agent 客户端兼容性、标准安装入口、精简工具说明；MCP 为可选便利层，CLI 已足以启动闭环 |
| 包校验 | [Package 2.0](package-format.md)与 JS manifest 校验器 | 区分 manifest、脚本执行、渲染与系统能力的结果，不以一个 `valid` 表示所有检查通过 |
| 原生执行 | [AgentRuntimeBridge](../Shared/ScriptWidgetRuntime/AI/AgentRuntimeBridge.swift)及原生测试/预览基础 | 尚未提供可对外分发、可校验完整包并返回原生 PNG 的 Mac CLI/API；现有桥接以 JSX 为中心，不能直接称为完整包校验服务 |
| 外部 Agent Skill | 有语法文档、模板及 App 内 Skills 1.0 | 还缺官方、可分发的外部 Coding Agent 创作 Skill，以及与校验工具版本匹配的参考资料 |

当前 npm 包的 `private: true`，CLI 又通过仓库相对路径读取 Babel/运行时资源，不能现在就承诺用户能执行某个公开 `npx` 命令。需先完成资源打包、干净环境安装与许可核对。

## 2. 三种入口，各自解决什么问题

| 入口 | 谁使用 | 输出与边界 |
| --- | --- | --- |
| Web 页面 | 用户查看，或没有本地工具时手动往返 | 快速编译、mock 执行、近似布局图和诊断；浏览器内处理用户输入，无需上传执行服务器 |
| CLI / 可选 MCP | 用户的 Coding Agent | 自动检查包、执行、截图和读取 JSON；这是自动修复循环的主要入口，不依赖 Agent 控制网页 |
| 已有 Mac App + 本地桥接 | 需要更接近正式结果的 Mac 用户 | 使用原生 JavaScriptCore / SwiftUI 检查与截图；仍不能替代真实 WidgetKit、系统授权、交互或 iPhone 的最终验收 |

建议先交付 Web + CLI/Skill，再增强 Mac 原生桥接。只提供网页也能让用户手动复制代码与报错，但 Agent 的自动循环较脆弱；只提供 Mac 则限制其他系统上的 Agent 使用现有 Web 预览引擎。工具可以跨平台，不代表要重新开展 Web 本地模型或 iOS 模型研发。

Web 页面继续静态托管，校验和预览在浏览器的受控 Worker 中运行。需要网站静态文件托管，但不需要模型服务器、GPU、账号后端或把用户代码上传到我们的执行服务。本地 CLI 也直接在用户机器运行；MCP 是本地进程，不是一个必须租云主机的服务。

## 3. Skill 应该交付什么

建议发布一个聚焦“创建/修改 ScriptWidget 并验证”的官方 Skill，包含：

- 短入口 `SKILL.md`：识别 ScriptWidget 方言、读取必要参考、调用校验、查看图片、修复错误、向用户交付结果。
- 按需参考：原生 JSX 标签/属性、宿主 API、Package 2.0、权限、数据与存储、尺寸、常见失败和受验证示例。参考资料标注 runtime/API 版本，语法以原生 switch 为准。
- 有效示例：优先复用模板与其资源，避免整个模板库塞进 prompt；不包含凭证或用户真实数据。
- 工具使用与结果解释：使用已安装的 CLI 或 MCP，先确认版本与依赖；报告未执行项，不把 mock 成功等同于真实系统调用成功。

不写泛泛的编程教程，也不让 Skill 自行安装依赖、登录服务或扩大 runtime 权限。外部 Agent 的工具权限由用户和该 Agent 管理。

需要明确区分：**外部 Coding Agent 的 SKILL.md 是创作工作流；App 内 Skills 1.0 是提示资料包**。后者只有 `skill.json` 与 `SKILL.md`，不会因为这个方案变成可执行工具。不能将带 scripts/references 的外部 Skill 直接冒充 `.swskill` 导入。

安装说明应针对实际验收过的 Agent 客户端编写，不能假设所有 Agent 都共享相同 Skill 搜索路径或 MCP 配置。未支持 Skill 的客户端仍可读取同一份创作指南，并直接调用 CLI。

## 4. 校验结果必须分层，不能只有一个绿色通过

| 层次 | 必须报告 | 不能推断出的结论 |
| --- | --- | --- |
| 包与静态检查 | manifest、入口/引用文件、权限声明、域名、资源路径、编译错误、可定位的标签/属性问题 | 没有运行的分支全部正确 |
| mock 执行 | 成功/异常/超时、日志、元素树、选定 fixtures 与参数 | 系统权限可用、接口数据真实、账号已经连接 |
| Web 渲染 | PNG、尺寸、外观、已知近似/不支持项、引擎版本与代码指纹 | 像素级原生一致、交互一定可用 |
| Mac 原生检查（可选） | 原生执行、SwiftUI 截图、平台与系统版本、所用 mock 和未执行项 | iPhone WidgetKit、真实授权或系统调度也已通过 |
| 人工验收 | 是否满足需求、视觉与交互是否可接受 | 靠编译成功自动证明所有需求都满足 |

Web 的图标、字体、Charts、材质和系统行为有已知差异，必须沿用[覆盖表](browser-preview-coverage.md)提示，不能因渲染成功而全部标为 supported。尺寸/profile 选择为 macos 也只是 Web 引擎使用 Mac 参数，并非原生渲染。

统一报告建议包含：`reportVersion`、工具/运行时版本、`sourceHash`、输入参数和 mock 指纹、backend、每层的 `passed/failed/notRun`、错误/警告、图片和未覆盖能力。这是待定义的稳定契约，不是现有 CLI 已具备全部字段。诊断尽可能有 code、file、line/column、原因与相关文档；无法可靠定位时不要伪造行号。

退出码必须区分检查失败与工具运行失败，warning 与不支持项不能静默消失。模型给出的修复建议仅供参考，不能替代工具检测。只运行一个 mock 场景的报告需清楚注明范围。

## 5. 用户与 Agent 的完整路径

开发者安装 Skill 和工具后，在自己的 Agent 中提出需求。Agent 创建独立目录及 `widget.json` / `main.jsx`，选择适用尺寸与数据来源；执行校验和截图，读取 JSON 并在支持图片输入时查看 PNG，按错误修复；最终交付组件包、最新报告与图片。模型不支持看图时不能声称已完成视觉检查，保留用户预览步骤。

用户可以将代码粘贴到 Web 页面，或打开完整包，查看预览与 Problems，再复制检查结果给 Agent。涉及图片、多个文件或 manifest 时，优先打开目录/`.swt`，不能只粘贴入口代码就当作完整包已验收。无 manifest 的快速草稿应明确显示 legacy/草稿状态，生成和导出完整包时采用 Package 2.0。

本次不建议把源码放进 URL 查询参数来实现“打开预览”，避免浏览器历史、链接分享或日志泄露。第一版用本地文件导入、复制粘贴和报告下载；自动跨进程打开项目可以后续再评估。

已存在的仓库内命令可以用来验证这个工作流：

```sh
node Web/preview-engine/bin/scriptwidget-preview.mjs MyWidget \
  --profile macos --family medium --appearance light \
  --output /absolute/path/to/output/preview.png \
  --diagnostics /absolute/path/to/output/preview.json
```

输出放在组件包外，避免生成图片/报告进入后续源码指纹或打包输入。深色需要独立运行；报告与截图必须匹配当前文件。以上是当前真实 CLI，不是尚未发布的简写命令。

## 6. 执行与数据边界

现有 CLI 渲染走 headless Chrome 沙箱，不能为简化工具改成在 Node 主进程 `eval` 用户代码；Node 的 `vm` 不作为安全隔离承诺。保持 Worker 超时、文件/归档/网络/存储预算，以及包路径和导出边界。

Web 和本地自动检查默认使用固定、可编辑 mock，不触发登录、真实健康/定位授权、真实网络调用或现有用户存储写入。测试成功/空数据/拒绝权限等场景，区分示例数据和真实结果。源码、mock 和敏感日志不默认发送到我们服务器。

Mac 原生桥接复用 App 的运行时与安全校验，临时工作目录与用户项目分开，加载完整包前验证路径、manifest、资源预算。默认仅允许 loopback 且显式配对，或使用更窄的本地 IPC；不为网页远程调用开放任意来源，不绕过 App Sandbox。CLI 用受控输入请求验证，不给模型任意文件读写或 shell 执行能力。

Mac 首期只做执行与原生截图，不把“自动申请系统权限”“真机账号验收”“持续运行交互模拟”混进校验工具。是否允许联网、真实数据和持久化修改是另一个明确授权的操作。

## 7. 有限的交付顺序

| 阶段 | 交付 | 验收标准 |
| --- | --- | --- |
| P1：可供 Agent 使用 | 官方外部 Skill；可独立安装的现有 CLI；版本化诊断；可选 MCP 安装文档 | 干净机器无需 clone 全仓库可使用；明确 Node/Chromium 依赖；用真实 Agent 完成一次生成→报错→修复→截图循环 |
| P2：用户可直接预览 | 复用 Web Studio 增加简明校验入口、报告导出、mock 场景和分层状态 | 合法/非法包、语法错误、资源缺失、超时、空数据与拒绝权限有明确反馈；可看浅深色图；检查过程中用户代码不发往执行服务器 |
| P3：Mac 原生增强 | 现有 App 的受控本地验证入口，CLI/MCP 可选请求原生执行与 PNG | 原生截图和报告对应相同 sourceHash/fixtures；取消、重复运行、隔离、资源释放与无 App 时的提示通过 |

每一阶段都可独立交付，不要求 P3 完成才让开发者用 Skill + CLI。首轮不做新模型训练、GPU 托管、付费额度系统、第二个 Mac App、IDE 插件或跨端自动安装。

成功标准不是“新增多少工具”，而是：独立 Agent 依据 Skill 能使用正确语法；拿到具体失败后能修复；用户能看到最新结果；Web 的近似检查与 Mac 原生检查不会混淆。用合法包、坏 manifest、错误 JSX、未知/近似能力、死循环和不同 mock 的固定样例验收，保留证据再宣布可用。

## 本次核对与验证

2026-10-23，在研究分支运行 CLI 的 `--help`，确认存在 `macos` profile、浅深色、JSON 报告和 watch 参数；运行 `node --test --test-timeout=180000 Web/preview-engine/test/cli.test.js`，3 项通过、0 跳过。该文件覆盖 PNG/源码 hash、失败后清理旧图、MCP 工具与路径限制，以及模拟服务的设备同步。设备同步使用测试服务，不是本次真机或 Mac 原生渲染验收；也尚未验证外部用户的独立安装、完整 Skill 行为或真实 Agent 客户端连接。
