import SwiftUI

// MARK: - 主界面骨架
//
// 三个占位标签页，展示推荐的导航结构。
// 每个页面都可以独立拆成单独文件，按需增删 Tab 即可。

struct ContentView: View {
    var body: some View {
        TabView {
            HomeView()
                .tabItem {
                    Label("桌面", systemImage: "desktopcomputer")
                }

            TerminalView()
                .tabItem {
                    Label("终端", systemImage: "terminal")
                }

            SettingsView()
                .tabItem {
                    Label("设置", systemImage: "gearshape")
                }
        }
    }
}

// MARK: - 桌面（占位）

struct HomeView: View {
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    Image(systemName: "desktopcomputer")
                        .font(.system(size: 56))
                        .foregroundStyle(.tint)
                        .padding(.top, 48)

                    Text("PC on iPhone")
                        .font(.title.bold())

                    Text("把 PC 体验装进 iPhone。\n从这里开始搭建你的第一个功能模块。")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)

                    // 示例卡片：复制这个结构，快速做出你的界面
                    VStack(alignment: .leading, spacing: 8) {
                        Label("如何开始", systemImage: "1.circle")
                        Text("在 Views 里新建 SwiftUI 文件，把它挂到某个 Tab 下。")
                        Label("如何编译", systemImage: "2.circle")
                        Text("推送 v* 标签到 GitHub，Actions 自动打包并发布 IPA。")
                    }
                    .font(.footnote)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding()
                    .background(.regularMaterial, in: .rect(cornerRadius: 16))
                    .padding(.horizontal)
                }
                .padding(.bottom, 32)
            }
            .navigationTitle("桌面")
        }
    }
}

// MARK: - 终端（占位）

struct TerminalView: View {
    var body: some View {
        NavigationStack {
            VStack(spacing: 12) {
                Image(systemName: "terminal")
                    .font(.system(size: 48))
                    .foregroundStyle(.tint)
                Text("终端功能待实现")
                    .foregroundStyle(.secondary)
            }
            .navigationTitle("终端")
        }
    }
}

// MARK: - 设置（占位）

struct SettingsView: View {
    var body: some View {
        NavigationStack {
            Form {
                Section("关于") {
                    LabeledContent("版本", value: "1.0")
                    LabeledContent("框架", value: "SwiftUI · iOS 16+")
                }
                Section {
                    Text("在这里添加你的设置项。")
                        .foregroundStyle(.secondary)
                }
            }
            .navigationTitle("设置")
        }
    }
}

// MARK: - 预览

#Preview {
    ContentView()
}
