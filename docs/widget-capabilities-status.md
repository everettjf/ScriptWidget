# Widget 能力阶段交付清单

更新：2026-10-22。用户已确认本轮冻结范围：完成已开始的内容；未开始的功能记入 [TODO](widget-capabilities-todo.md)，暂不开发。代码仍统一在 `codex/release-m1-m2` / [PR #62](https://github.com/everettjf/scriptwidget/pull/62)，不以实现全部 M3–M5 作为本轮收尾条件。阶段交付不等于已经部署或完成商店发布。

## 已实现并纳入本轮

| 范围 | 已有成果 | 实际边界 |
| --- | --- | --- |
| M1/M2：基础和模板 | 真实打卡、饮水、心情、清单记录，持久化/恢复，组件身份隔离，有界时间线和默认样例；天气、公开数据、启动器、本地 Live Activity、植物/宠物等模板及 Gallery | 真实系统调度、共享容器及性能仍需设备验收 |
| M3：个人数据 | 指定来源日历；指定列表提醒事项读取及显式写入、操作回执；选定照片/相册快照与轮换；健康睡眠、活动、运动摘要 | 只使用授权范围内的数据；真实授权/撤权和有限照片选择仍需真机验收 |
| M4：GitHub 和 Music | 原生 GitHub 连接、Keychain 凭据、逐组件授权和受限资料代理；iOS Apple Music 只读播放快照、设置与模板 | macOS Music 明确不可用；没有播放控制 |
| M4：Spotify 条件接入 | 系统登录 + PKCE、前台刷新、资料与播放快照、独立逐组件授权 | 不引入 Spotify SDK；当前 Client ID 留空，原生保留未配置提示；真实登录待配置后验收 |
| M5：创作工具 | iOS/macOS/Web Layout、Theme、Assets；JSX 支持子集内编辑、撤销和源码保留；公开材质与回退；壁纸裁切和可导出配置 | 动态 JavaScript 继续通过 Code 编辑；Web 材质是有说明的近似效果 |
| M5：GIF 收尾 | 系统 ImageIO 有界解码、帧数/内存/文件限制、内容缓存、Mac/辅助功能静态回退；Web 有界解码与静态回退 | 普通 iOS 时钟动画仍保留既有私有桥接；没有宣称已替换或完成真实扩展内存验收 |
| Web Studio 对齐 | 已新增 API 的可编辑默认样例、授权/空数据/错误场景，服务独立 fixture；浏览器编辑、保存重载和导出验证 | Web 不访问手机私人数据、不连接真实服务，mock 不作为原生真实数据导出 |

## 已开始、在本轮收尾的内部基础

服务播放操作的持久化记录已经补齐内部实现和确定性测试：派发前保存未知状态，绑定账户/连接/组件/操作/requestID；成功回执可重放；未知结果禁止自动重试；历史损坏、容量耗尽、撤权和保存失败均拒绝继续。已完成记录保留七天，未知记录不自动淘汰。

这只是私有基础，尚无实际 HTTP 写入、公开 JavaScript 控制 API、控制授权入口或播放按钮。现有只读代理继续拒绝写操作，不把内部基础计作“播放控制已支持”。它提供本地重放保护，不提供服务端 exactly-once 保证。下一步工作见 TODO。

## 验证与交付状态

最终 `./Scripts/release-readiness.sh` 已通过：Mac 706 项、iPhone 17 Simulator 716 项通过，均 0 失败，分别跳过 33/32 项。Editor 52、预览引擎 168、Web Studio 104、服务 probe 51 项及全部浏览器流程、两端 app build 通过。确切日志及结果路径见 [实施记录末尾](widget-capabilities-execution.md)；未将跳过用例计作通过。

当前是本地开发与验证成果：没有执行本轮 Web 部署、原生商店构建上传或 App Review 提交。App Review 仍由用户操作。真机、签名 Keychain/iCloud、WidgetKit 调度、Always On 和扩展内存验收未完成，不能称作已满足全部发版门槛。完整门槛见 [发布检查](release-readiness.md)。
