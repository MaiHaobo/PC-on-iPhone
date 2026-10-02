# UTM 外部依赖总览

本文档记录 UTM 全部外部依赖的获取方式、版本锚点与用途。**这些依赖不存放在本仓库中**——这是上游作者的设计，也是唯一可行的方案。

> 版本锚点来源：`patches/sources`（首次提交时快照）
> 获取脚本：`scripts/build_dependencies.sh`

---

## 为什么依赖不在仓库里

UTM 依赖的总体积远超任何 Git 仓库的承载能力：

| 依赖 | 体积 | 文件数 |
| --- | --- | --- |
| `utmapp/WebKit` 全量 | 约 9.5 GB | 418,564 |
| 30 个 tarball 解压后 | 数 GB | — |
| 其余 9 个 git 仓库 | 约 55 MB | — |

GitHub 的限制是单文件 100 MB、仓库实际可用上限约 5 GB。把 WebKit 放进来会被服务端直接拒收。

作者的解决方案是 **`--filter=tree:0` 部分克隆 + `sparse-checkout` 稀疏检出**——只取真正需要的子目录。以 WebKit 为例：

```sh
WEBKIT_SUBDIRS="Source/ThirdParty/ANGLE Configurations Tools/ccache"
```

9.5 GB 里只检出这 3 个目录。构建产物（sysroot）则由 CI 缓存，同样不进仓库。

**执行方式**：`./scripts/build_dependencies.sh -p ios -a arm64`

---

## 一、Git 依赖（10 个）

全部按 `commit` 精确锚定，`clone()` 会检出到指定 commit 后初始化子模块。

| 依赖 | 仓库 | Commit | 用途 |
| --- | --- | --- | --- |
| libucontext | `utmapp/libucontext` | `9b1d8f01` | 协程上下文切换（ucontext 替代实现） |
| **WebKit** | `utmapp/WebKit` | `ed78ab6e` | 内嵌浏览器；**仅取 3 个子目录** |
| libepoxy | `utmapp/libepoxy` | `bf985874` | OpenGL 函数加载器 |
| Vulkan-Loader | `osy/Vulkan-Loader` | `6df86907` | Vulkan 加载器 |
| virglrenderer | `utmapp/virglrenderer` | `5d26f605` | 虚拟机 3D 加速 |
| mesa | `gitlab.freedesktop.org/osy/mesa` | `eed3e1d9` | Mesa 图形栈（注意：托管在 GitLab） |
| MoltenVK | `utmapp/MoltenVK` | `05604465` | Vulkan → Metal 转译 |
| dxmt | `utmapp/dxmt` | `70aa109c` | DirectX → Metal 转译 |
| d3dmetal-native | `utmapp/d3dmetal-native` | `f0dd1faf` | D3D 到 Metal 的本地实现 |
| Hypervisor | `utmapp/Hypervisor` | `b2c910fb` | hypervisor.framework 封装 |

> MoltenVK 需要额外跑 `./fetchDependencies --none -v` 拉取其子依赖。

---

## 二、Tarball 依赖（30 个）

`build_dependencies.sh` 按 `patches/sources` 中的 URL 下载并编译。核心几个：

| 依赖 | 版本 | 来源 |
| --- | --- | --- |
| **QEMU** | 10.0.12-utm | `utmapp/qemu` Release |
| glib | 2.83.0 | download.gnome.org |
| pixman | 0.38.0 | cairographics.org |
| spice-protocol | 0.14.4 | spice-space.org |
| spice-server | 0.14.3 | spice-space.org |
| spice-gtk（客户端） | 0.42 | spice-space.org |
| openssl | 1.1.1b | github.com/openssl |
| libslirp | 4.9.1 | `utmapp/libslirp` |
| swtpm / libtpms | 0.8.99 / 0.9.6 | `utmapp/swtpm` / `osy/libtpms` |
| gstreamer / base / good | 1.19.1 | gstreamer.freedesktop.org |
| libusb / usbredir | 1.0.25 / 0.14.0 | github / spice-space |
| **LLVM15** | 15.0.7 | llvm-project Release |

其余：pkg-config、libffi、iconv、gettext、libpng、libjpeg-turbo、libgpg-error、libgcrypt、opus、zstd、json-glib、libxml2、libsoup、phodav。

完整列表见 `patches/sources`。

---

## 三、SwiftPM 依赖（17 个）

由 Xcode 自动解析，锚定在 `UTM.xcodeproj/project.xcworkspace/xcshareddata/swiftpm/Package.resolved`。

| 包 | 版本 | 仓库 |
| --- | --- | --- |
| altkit | 0.0.2 | `rileytestut/AltKit` |
| cocoaspice | main | `utmapp/CocoaSpice` |
| cod | main | `saagarjha/Cod` |
| h | 1.0.1 | `rarestype/h` |
| inappsettingskit | 3.4.1 | `futuretap/InAppSettingsKit` |
| iqkeyboardmanager | 6.5.6 | `hackiftekhar/IQKeyboardManager` |
| **qemukit** | main | `utmapp/QEMUKit` |
| swift-argument-parser | 1.2.3 | `apple/swift-argument-parser` |
| swift-log | 1.5.3 | `apple/swift-log` |
| swift-png | 4.5.1 | `tayloraswift/swift-png` |
| swiftconnect | main | `utmapp/SwiftConnect` |
| swiftcopyfile | main | `osy/SwiftCopyfile` |
| **swiftportmap** | main | `osy/SwiftPortmap` |
| **swiftterm** | `fix/visionos-build` | `osy/SwiftTerm` |
| swiftui-visual-effects | 1.0.3 | `lucasbrown/swiftui-visual-effects` |
| visionkeyboardkit | main | `utmapp/VisionKeyboardKit` |
| zipfoundation | 0.9.20 | `weichsel/ZIPFoundation` |

> ⚠️ `swiftterm` 锚定在一个**未合并的分支** `fix/visionos-build`。上游若删除该分支，构建会失败。

> 注意：有 7 个包用 `main` 分支而非版本号（`cocoaspice`、`cod`、`qemukit`、`swiftconnect`、`swiftcopyfile`、`swiftportmap`、`visionkeyboardkit`）。这意味着**上游一提交，你的构建内容就会变**，不可复现。

---

## 四、补丁（17 个）

`patches/*.patch` 是对上述部分依赖的源码修改，`build_dependencies.sh` 在编译前自动应用。

覆盖：gettext、glib、gst-plugins-base、gst-plugins-good、json-glib、libgcrypt、libslirp、libsoup、libtpms、libusb、spice-gtk、swtpm、virglrenderer、MoltenVK 等。

---

## 五、构建流程

```
./scripts/build_dependencies.sh -p <platform> -a <arch>
    ├─ 下载 30 个 tarball（按 patches/sources 的 URL）
    ├─ 部分克隆 10 个 git 依赖（--filter=tree:0）
    ├─ 稀疏检出 WebKit 等大仓库的指定子目录
    ├─ 应用 17 个 patch
    ├─ 交叉编译出 sysroot-<platform>-<arch>/
    └─ 后续由 UTM.xcodeproj 链接该 sysroot
```

参数：`-p` 平台（ios / macos / visionos）、`-a` 架构（arm64 / x86_64）、`-d` 强制重新下载、`-q <path>` 使用既有 QEMU 路径。

**依赖系统要求**：主机需有 `glib-mkenums`、`glib-compile-resources`（`glib-utils` 包）以及完整 Xcode 工具链。

---

## 许可证提示

这些依赖的许可证各不相同，若将来要分发基于 UTM 的产物，需逐项核对：

- **WebKit** —— LGPL-2.1 + BSD（注意 LGPL 的动态链接与源码提供义务）
- Mesa —— MIT
- MoltenVK / Vulkan-Loader / virglrenderer —— Apache-2.0 / MIT
- QEMU —— GPL-2.0（**这是最强的传染性条款**）
- glib —— LGPL-2.1
- openssl 1.1.1 —— OpenSSL License + SSLeay License

UTM 自身为 Apache-2.0，但其构建产物因链接 QEMU 而受 GPL-2.0 约束。
