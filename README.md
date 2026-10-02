# PC on iPhone

把 PC 体验装进 iPhone —— SwiftUI 原生 iOS 应用（SwiftUI · iOS 16+ · 液态玻璃就绪）。

> 🚧 **项目处于骨架阶段**：仓库已内置可编译的完整工程与云端打包流水线，欢迎在此之上开发。

## 功能规划

- **终端** —— SSH 客户端：连接你的 PC / 服务器，逐条执行命令（已实现）
  - 里程碑 1b：完整交互式 TTY（vim/top 等）+ 密钥认证
  - 里程碑 2：VNC 图形远程桌面
  - 里程碑 3：QEMU 虚拟机引擎（对标 UTM SE 的核心路线）
- **桌面** —— 主功能入口（规划中）
- **设置** —— 应用配置（规划中）

## 项目结构

```
PC-on-iPhone/
├── PC-on-iPhone/                 # 源码（SwiftUI）
│   ├── PCOnIPhoneApp.swift       # 应用入口
│   ├── ContentView.swift         # TabView 主骨架（桌面/终端/设置）
│   ├── Info.plist
│   ├── PC-on-iPhone.entitlements
│   └── Assets.xcassets           # 图标与颜色
├── PC-on-iPhone.xcodeproj
├── scripts/
│   └── build-ipa.sh              # 云端打包脚本（编译/签名/导出/发 Release）
└── .github/workflows/
    └── build-ipa.yml             # GitHub Actions 工作流
```

## 云端自动打包 IPA（无需 Mac）

1. Fork/clone 本仓库后，到 **Settings → Secrets and variables → Actions** 配置 4 个 Secret：
   | Secret 名 | 内容 |
   |---|---|
   | `BUILD_CERTIFICATE_BASE64` | .p12 证书文件转 base64 |
   | `P12_PASSWORD` | .p12 的导出密码 |
   | `BUILD_PROVISION_PROFILE_BASE64` | .mobileprovision 描述文件转 base64 |
   | `KEYCHAIN_PASSWORD` | 临时钥匙串密码（随意设置） |

2. **Bundle ID 说明**：本工程默认 `com.pcfoni.app`。请向你的证书供应商提供该 Bundle ID 获取对应的描述文件；若使用通配符描述文件则可直接使用。

3. 触发编译：推送一个 `v*` 标签（如 `v0.1`），或到 Actions 页面手动运行。构建成功后 IPA 会自动发布到 **Releases** 页。

## 本地开发

用 Xcode 15+ 打开 `PC-on-iPhone.xcodeproj`，选择模拟器直接 ⌘R 运行。

## 环境

- Xcode 15+（云端编译使用 Xcode 26/27）
- iOS 16.0+
- Swift 5

## License

[MIT](LICENSE)
