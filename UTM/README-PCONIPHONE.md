# UTM 源码（参考实现）

本目录是 [UTM](https://github.com/utmapp/UTM) 的完整源码快照，作为 **PC on iPhone** 复刻 iOS 虚拟机能力时的参考实现（reference implementation）使用。

> 上游：`utmapp/UTM` @ `7eadb05 project: bumped version`
> 搬入日期：2026-10-02

## 为什么放在这里

**PC on iPhone** 的目标是在 iOS 上跑一个远程/本地虚拟 PC。UTM SE 是这条路上唯一真正跑通的开源先例，它的架构选择（QEMU + TCTI 无 JIT 解释器 + SPICE/VNC 显示）直接决定了我们的技术路线。把源码放在同一个仓库里，便于：

- 对照阅读关键实现（`Platform/` 下的 iOS 平台层、`QEMUHelper/` 的引擎封装）
- 复用许可证允许的部分（Apache-2.0 / LGPL 组件）
- 追踪上游改动，不靠记忆猜测

**它不参与本仓库的编译。** `PC-on-iPhone.xcodeproj` 不会引用 `UTM/` 下任何文件，云打包流水线也完全忽略该目录。

## 上游结构速览

| 目录 | 作用 |
| --- | --- |
| `Platform/` | 多平台适配层（iOS / macOS / visionOS），占体积最大（约 5.3MB） |
| `QEMUHelper/` | QEMU 引擎的启动、参数拼接、进程托管 |
| `QEMULauncher/` | 引擎启动器的独立进程包装 |
| `QEMURenderServer/` | 渲染服务进程（隔离显示输出） |
| `Services/` | 业务服务层（虚拟机管理、配置持久化等） |
| `Configuration/` | 配置模型（`UTMQemuConfiguration` 等） |
| `Renderer/` | 显示渲染层（Metal / SPICE / VNC 客户端） |
| `Remote/` | 远程连接协议 |
| `Scripting/` | 脚本化接口（Shortcuts / JavaScript） |
| `Intents/` | Siri Shortcuts 集成 |
| `Icons/` | 图标资源（约 3.7MB） |
| `patches/` | 对 QEMU 源码的补丁（裁剪、iOS 适配） |
| `scripts/` | 构建脚本（QEMU 交叉编译、依赖拉取） |
| `iOSHelper/` | iOS 侧辅助代码 |
| `JailbreakInterposer/` | 越狱环境下的插桩辅助 |
| `utmctl/` | 命令行控制工具 |
| `zh-Hans.lproj` / `zh-Hant.lproj` / `zh-HK.lproj` | 本地化资源（简体 / 繁体 / 港区） |
| `*.md` | 多语言 README（共 12 种语言） |

## 关键架构认知

复刻时最需要吃透的三件事：

1. **无 JIT 怎么跑** —— iOS 禁止运行时生成可执行内存，UTM SE 用 **TCTI**（Tiny-Code Threaded Interpreter）逐条解释 guest 指令。代价是慢一到两个数量级，收益是不越狱也能上架 App Store。

2. **引擎不是库，是独立进程** —— QEMU 以独立进程方式启动（`QEMULauncher` + `QEMURenderServer`），通过 IPC 与 App 通信。这样能绕开部分沙箱限制，也避免引擎崩溃拖垮 UI。

3. **显示走网络协议** —— 不是直接把宿主 framebuffer 塞给 UI，而是让 QEMU 输出 SPICE / VNC 流，App 侧当客户端渲染。这一步让显示层与引擎彻底解耦。

## 许可证

UTM 主体为 **Apache-2.0**，部分组件为 **LGPL**（QEMU 派生部分）。完整条款见本目录 `LICENSE`。任何复用都必须保留下游署名与许可证文本。

本目录内容**原样保留**，未做任何删减或修改。
