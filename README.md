# 雾灯档案 · Foglight Files

> 《鸿蒙高级应用开发工程师认证》期末大作业 · **主题一：校园线索推理与多结局探索**
> HarmonyOS / ArkTS + ArkUI 单机应用 · 独立完成 · CASE_2140「钟楼第七盏灯」

校庆前夜 21:40，钟楼活动室断电十四分钟，校庆奖杯与评优推荐名单一起消失。玩家作为校刊见习记者，在 3 个场景中调查、拾取线索、作出会改变后续剧情的选择，验证推理条件后提交最终判断，进入由条件决定的不同结局。**所有状态在每次操作后即时写入 Preferences，结束进程重启可逐项恢复。**

## 一、功能概览

| 模块 | 能力 |
|---|---|
| 案件简报 | 五阶段进度（接受调查 / 搜集线索 / 交叉验证 / 最终判断 / 案件结案）、百分比进度条、关键状态提示、存档时间与重开入口 |
| 场景探索 | 3 个场景自由切换；14 个事件节点的门槛提示（尚缺线索 / 分支未达成 / 路径已关闭）；选项交互、结果反馈动画 |
| 分支机制 | 选择写入 flag 后可**锁定后续事件**、切换事件正文变体；公开便签 → 证人改口 → 送修回执不可达 → 结局改变 |
| 线索板 | 9 条线索（含 3 条 ★ 定案线索），按全部 / 已获得 / 未获得 / ★定案筛选，点击展开详情与来源 |
| 推理验证 | 指认对象 / 动机 / 断电时间线三项断言；「验证推理条件」列出 `ready / 缺失线索 / 错误项`；条件不足仍可提交但进入残缺结局 |
| 多结局 | 4 个由不同条件触发的结局：`END_TRUTH`《灯下的署名》、`END_MISJUDGE`《错指的人》、`END_COVER`《没有寄出的稿子》、`END_PARTIAL`《半亮的路灯》，按固定优先级判定 |
| 调查日志 | 每次有效选择追加 1 条记录（seq / 时间 / 事件 / 选项 / 获得线索），上限 120 条 FIFO |
| 持久化 | `@ohos.data.preferences`（`foglight_state` / `game_state`），白名单反序列化，损坏回落并保留原串，冷启动门禁 |
| 可测试性 | 纯逻辑层零 `@ohos.*` 依赖，12 条 Local Unit Test 覆盖正常 / 边界 / 异常 |

## 二、开发环境

| 项 | 版本 / 说明 |
|---|---|
| IDE | DevEco Studio 26.0.0.865（macOS ARM64） |
| SDK | HarmonyOS SDK 26.0.0 Release / API 26 |
| 版本约束 | `targetSdkVersion 26.0.0`、`compatibleSdkVersion 6.1.1(24)`（**冻结，不得修改**） |
| 语言 / 模型 | ArkTS · Stage 模型 · ArkUI 状态管理 V1 |
| 构建工具 | hvigorw / ohpm / Node.js（DevEco Studio 内置） |
| 运行设备 | HarmonyOS 7.0.0(26.0.0) 模拟器（`127.0.0.1:5555`）或同版本真机 |
| 测试框架 | `@ohos/hypium` 1.0.25（Local Unit Test） |
| 个人信息 | 学号 / 姓名 / 班级：`<待补>`；GitHub 账号：`3058326056-oss` |
| GitHub 仓库 | https://github.com/3058326056-oss/FoglightFiles |

## 三、目录结构

```text
FoglightFiles/
├── AppScope/                         应用标识与资源
├── entry/src/main/ets/
│   ├── model/Models.ets              类型、id 白名单、白名单反序列化、深拷贝
│   ├── model/CaseCatalog.ets         3 场景 / 14 事件 / 9 线索 / 4 结局常量
│   ├── engine/CaseEngine.ets         纯函数案件引擎（零系统依赖）
│   ├── repository/                   IStateRepository / Preferences 实现 / 内存替身
│   ├── viewmodel/                    CaseViewModel（SSOT）/ AppContext 单例
│   ├── pages/                        Index + 6 个业务视图
│   ├── components/                   HeaderBar / ClueCard / EventCard / UiBus
│   └── entryability/EntryAbility.ets 依赖装配与冷启动门禁
├── entry/src/test/                   12 条业务用例 + 模板用例 + 测试夹具
├── docs/
│   ├── 软件需求说明书.md              开发前定稿（冻结契约）
│   ├── 系统架构设计.md                架构、接口、时序与配置清单
│   ├── 新技术认识.md / 学习疑问分析.md / 持续学习计划.md
│   ├── 报告正文.md                   Word 报告的正文源稿
│   ├── figures/                      架构图、流程图、模拟器实拍截图
│   └── evidence/test/                测试运行日志与覆盖率报告
├── screenshots/                      运行截图索引
├── demo/                             演示视频与复现脚本
└── README.md
```

## 四、构建、运行与测试

### 4.1 命令行构建

```bash
cd <本仓库根目录>
export NODE_HOME=/Applications/DevEco-Studio.app/Contents/tools/node
export DEVECO_SDK_HOME=/Applications/DevEco-Studio.app/Contents/sdk
export PATH="$NODE_HOME/bin:/Applications/DevEco-Studio.app/Contents/tools/ohpm/bin:/Applications/DevEco-Studio.app/Contents/sdk/default/openharmony/toolchains:$PATH"
ohpm install
/Applications/DevEco-Studio.app/Contents/tools/hvigor/bin/hvigorw assembleHap --mode module -p product=default --no-daemon
```

出现 `BUILD SUCCESSFUL` 即成功，HAP 位于 `entry/build/default/outputs/default/entry-default-unsigned.hap`（命令行构建未配置签名，IDE 运行时会自动签名）。

### 4.2 运行方法

1. DevEco Studio 打开本工程根目录，等待 Sync 完成。
2. **Tools → Device Manager** 启动 HarmonyOS 7.0.0(26.0.0) 模拟器，或连接同版本真机。
3. 选中 `entry`，点击 **Run 'entry'**（▶），IDE 自动签名、编译、安装并拉起应用。
4. 命令行方式：

```bash
hdc -t 127.0.0.1:5555 install -r entry/build/default/outputs/default/entry-default-unsigned.hap
hdc -t 127.0.0.1:5555 shell "aa start -a EntryAbility -b com.foglight.files"
```

5. 本地单元测试：DevEco Studio 右键 `entry/src/test/List.test.ets` → **Run 'List.test'**；或命令行：

```bash
/Applications/DevEco-Studio.app/Contents/tools/hvigor/bin/hvigorw test --mode module -p product=default --no-daemon
```

实测结果：`Tests run: 13, Failure: 0, Error: 0, Pass: 13, Ignore: 0`（12 条业务用例 + 1 条模板用例），日志见 `docs/evidence/test/test_result.txt`。

### 4.3 完整体验链路（验收用）

接受调查 → 旧馆搜集线索（E01–E05）→ 钟楼取得 ★送修回执（E06–E09）→ 连廊固定时间线（E10–E14）→ 线索板核对 3 条定案线索 → 推理台「验证推理条件」→「提交最终判断」→ 真相结局 → 强停进程重启，直接回到结局页且线索/日志/分支回顾逐项一致。

**分支对比**：重开后在「夹在书里的便签」选「当场念给大家听」，可观察到证人改口、E09 经费单据显示「因之前的选择，这条取证路径已经关闭」、信任度由 40 降到 35，最终指向 `END_COVER` 而非 `END_TRUTH`。

## 五、截图与演示

| 图 | 文件 | 内容 |
|---|---|---|
| 图2.1 | `docs/figures/fig2-1-system-architecture.png` | 系统架构图，逐模块标注「本人负责」 |
| 图3.1 | `docs/figures/fig3-1-business-flow.png` | 一次选择到重绘的业务流程图 |
| 图5.2 | `docs/figures/fig5-2-boundary-verdict.jpeg` | 边界：证据链不足时的验证结果 |
| 图6.1 a–h | `docs/figures/fig6-1-*.jpeg` | 简报、探索、事件、线索板、推理、结局、公开便签分支、锁定路径 |
| 图6.2 | `docs/figures/fig6-2-coldstart-restored.jpeg` | 杀进程重启后恢复结局 |
| 演示视频 | `demo/雾灯档案_运行演示.mp4` | 32 秒，由 11 张模拟器实拍关键帧合成，覆盖完整链路与分支对比；逐帧复现步骤见 `demo/演示脚本.md` |

## 六、文档索引

- `docs/软件需求说明书.md`：需求、数据契约、边界异常、12 条测试口径、验收标准
- `docs/系统架构设计.md`：分层、接口、时序、设计决策、配置清单
- `docs/新技术认识.md`：ArkUI 状态管理 V2 的用途、适用 API 版本与局限（含官方出处）
- `docs/学习疑问分析.md`：真实开发问题「状态更新但 UI 不刷新」的定位、资料与修复
- `docs/持续学习计划.md`：API 26 版本变更下的 V2 迁移验证任务与成效判据
- `docs/报告正文.md` / 根目录 Word 报告：按课程模板撰写的个人报告

## 七、开发声明与提交

本作品由本人**独立完成**：需求、剧情与数据契约、架构、全部源码、12 条测试、模拟器联调、截图与演示、文档与 Git 提交均由一人完成，无组队、无分工分摊。提交按 8 个开发节点拆分，Commit message 与产物一致，便于核验个人贡献。

**学习通答案（成绩认定前提）**：GitHub 仓库链接 `https://github.com/3058326056-oss/FoglightFiles` + 本人 GitHub 账号 `3058326056-oss`，两项必须同时填写，缺任一项整份作业计 0 分。

**待补（交付前统一替换）**：`<学号>`、`<姓名>`、班级（23物联1 / 2），用于报告封面、表1.1 与报告文件名。
