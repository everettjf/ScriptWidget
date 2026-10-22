# Widget 能力阶段交付清单

更新：2026-10-22。用户最新要求移除 Spotify、取消 C/D，实际完成 [A+B](widget-capabilities-plan.md) 并充分测试。当前开发进行中；此表保留其他已有成果，移除后的验证另记，不沿用旧测试计数。代码仍统一在 `codex/release-m1-m2` / PR #62。

## 已实现并纳入本轮

| 范围 | 已有成果 | 实际边界 |
| --- | --- | --- |
| M1/M2：基础和模板 | 真实打卡、饮水、心情、清单记录，持久化/恢复，组件身份隔离，有界时间线和默认样例；天气、公开数据、启动器、本地 Live Activity、植物/宠物等模板及 Gallery | 真实系统调度、共享容器及性能仍需设备验收 |
| M3：个人数据 | 指定来源日历；指定列表提醒事项读取及显式写入、操作回执；选定照片/相册快照与轮换；健康睡眠、活动、运动摘要 | 只使用授权范围内的数据；真实授权/撤权和有限照片选择仍需真机验收 |
| M4：GitHub 和 Music | 原生 GitHub 连接、Keychain 凭据、逐组件授权和受限资料代理；iOS Apple Music 只读播放快照、设置与模板 | macOS Music 明确不可用；没有播放控制 |
| M5：创作工具 | iOS/macOS/Web Layout、Theme、Assets；JSX 支持子集内编辑、撤销和源码保留；公开材质与回退；壁纸裁切和可导出配置 | 动态 JavaScript 继续通过 Code 编辑；Web 材质是有说明的近似效果 |
| M5：GIF 收尾 | 系统 ImageIO 有界解码、帧数/内存/文件限制、内容缓存、Mac/辅助功能静态回退；Web 有界解码与静态回退 | 普通 iOS 时钟动画仍保留既有私有桥接；没有宣称已替换或完成真实扩展内存验收 |
| Web Studio 对齐 | 已新增 API 的可编辑默认样例、授权/空数据/错误场景，服务独立 fixture；浏览器编辑、保存重载和导出验证 | Web 不访问手机私人数据、不连接真实服务，mock 不作为原生真实数据导出 |

## 本轮移除

Spotify 条件接入、授权/刷新、播放读取及内部写操作记录已移除；不是保留未配置提示，也不再列为后续 TODO。GitHub 与 iOS Music 只读能力保留。历史记录不代表当前支持状态。

## 验证与交付状态

移除后的最终 `./Scripts/release-readiness.sh` 通过：Mac **661 通过 / 0 失败 / 32 跳过**，iPhone 17 Simulator **671 通过 / 0 失败 / 31 跳过**，runtimeWarnings 均为空。Editor 52、预览引擎 168、Web Studio 96、服务 probe 24、91 模板/22 curated 包、浏览器流程及两端 app build 通过；计数变化对应 Spotify 的删除。SDK/link/Sendable/Xcode 诊断仍保留，不称作无编译警告。证据见 [实施记录末尾](widget-capabilities-execution.md)。这不是 A/B 全部完成或真机发布验收结论。

当前是本地开发与验证成果：没有执行本轮 Web 部署、原生商店构建上传或 App Review 提交。App Review 仍由用户操作。真机、签名 Keychain/iCloud、WidgetKit 调度、Always On 和扩展内存验收未完成，不能称作已满足全部发版门槛。完整门槛见 [发布检查](release-readiness.md)。
