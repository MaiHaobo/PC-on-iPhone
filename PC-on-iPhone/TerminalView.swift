import SwiftUI

// MARK: - 终端（里程碑 1 · 连接与探测）
//
// 目标：iOS 16 也能跑，不依赖任何第三方库。
//
// 当前能力：
//   - 管理 SSH 连接配置（本地持久化）
//   - 用 Network.framework 探测主机 SSH 端口连通性，并读取服务端版本横幅
//   - 命令历史与终端样式输出
//
// 里程碑 1b：在 TCPProbe 之上实现纯 Swift 的 SSH 协议栈
//   （版本协商 → 密钥交换 → 加密 → 认证 → exec 通道），
//   全部用系统自带的 Network.framework + CryptoKit，零第三方依赖，
//   这正是 UTM SE 能在老系统上运行的原因——把协议实现掌握在自己手里。

struct TerminalView: View {
    private enum Phase: Equatable {
        case pickServer
        case probing
        case ready
        case failed(String)
    }

    @State private var phase: Phase = .pickServer
    @State private var connections: [SSHConnection] = []
    @State private var showAddSheet = false
    @State private var draft = SSHConnection(name: "", host: "", username: "", password: "")

    @State private var active: SSHConnection?
    @State private var lines: [TerminalLine] = []
    @State private var commandText = ""
    @State private var probe: TCPProbe?

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            switch phase {
            case .pickServer:   serverPicker
            case .probing:      progressView("正在连接…")
            case .ready:        sessionView
            case .failed(let m): failureView(m)
            }
        }
        .navigationTitle("终端")
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(.black, for: .navigationBar)
        .toolbarBackground(.visible, for: .navigationBar)
        .toolbarColorScheme(.dark, for: .navigationBar)
        .onAppear { connections = SSHStore.load() }
        .sheet(isPresented: $showAddSheet) { addSheet }
    }

    // MARK: - 连接管理

    private var serverPicker: some View {
        List {
            if connections.isEmpty {
                ContentUnavailableCompat(
                    icon: "terminal",
                    title: "还没有连接",
                    detail: "添加你的 PC / 服务器，开始用 iPhone 操作它。"
                )
            } else {
                Section("已保存的连接") {
                    ForEach(connections) { conn in
                        Button {
                            startProbe(conn)
                        } label: {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(conn.name).font(.headline).foregroundStyle(.primary)
                                Text("\(conn.username)@\(conn.host):\(conn.port)")
                                    .font(.caption.monospaced())
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                    .onDelete { connections.remove(atOffsets: $0); SSHStore.save(connections) }
                }
            }
        }
        .toolbar {
            Button {
                draft = SSHConnection(name: "", host: "", username: "", password: "")
                showAddSheet = true
            } label: {
                Image(systemName: "plus")
            }
        }
    }

    private var addSheet: some View {
        NavigationStack {
            Form {
                Section("连接信息") {
                    TextField("名称（如：家里的电脑）", text: $draft.name)
                    TextField("主机地址 / IP", text: $draft.host)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                    TextField("端口", value: $draft.port, format: .number.grouping(.never))
                        .keyboardType(.numberPad)
                    TextField("用户名", text: $draft.username)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                    SecureField("密码", text: $draft.password)
                }
                Section {
                    Text("服务器需开启 SSH 服务（默认端口 22）。配置只保存在本机。")
                        .font(.footnote).foregroundStyle(.secondary)
                }
            }
            .navigationTitle("新建连接")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") { showAddSheet = false }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("保存") {
                        guard !draft.host.isEmpty, !draft.username.isEmpty else { return }
                        if draft.name.isEmpty { draft.name = draft.host }
                        connections.append(draft)
                        SSHStore.save(connections)
                        showAddSheet = false
                    }
                }
            }
        }
        .presentationDetents([.medium, .large])
    }

    // MARK: - 终端会话

    private var sessionView: some View {
        VStack(spacing: 0) {
            HStack(spacing: 8) {
                Circle().fill(Color.green).frame(width: 8, height: 8)
                Text(active.map { "\($0.username)@\($0.host)" } ?? "")
                    .font(.caption.monospaced()).foregroundStyle(.green)
                Spacer()
                Button {
                    probe?.cancel()
                    active = nil
                    phase = .pickServer
                } label: {
                    Image(systemName: "xmark.circle.fill").foregroundStyle(.gray)
                }
            }
            .padding(.horizontal)
            .padding(.vertical, 6)
            .background(Color(white: 0.08))

            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 2) {
                        ForEach(lines) { line in
                            Text(line.text)
                                .font(.system(size: 12, design: .monospaced))
                                .foregroundStyle(line.isCommand ? Color.yellow : Color.green)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .textSelection(.enabled)
                        }
                        Color.clear.frame(height: 1).id("bottom")
                    }
                    .padding(8)
                }
                .onChange(of: lines.count) { _ in
                    withAnimation(.easeOut(duration: 0.15)) {
                        proxy.scrollTo("bottom", anchor: .bottom)
                    }
                }
            }

            HStack(spacing: 8) {
                Text("$").font(.system(.body, design: .monospaced)).foregroundStyle(.green)
                TextField("输入命令（协议实现中）…", text: $commandText)
                    .font(.system(.body, design: .monospaced))
                    .foregroundStyle(.white)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .submitLabel(.go)
                    .onSubmit(submitCommand)
                Button {
                    submitCommand()
                } label: {
                    Image(systemName: "arrowtriangle.right.fill").foregroundStyle(.green)
                }
                .disabled(commandText.isEmpty)
            }
            .padding(10)
            .background(Color(white: 0.08))
        }
    }

    private func progressView(_ text: String) -> some View {
        VStack(spacing: 16) {
            ProgressView().tint(.green).scaleEffect(1.4)
            Text(text).font(.callout.monospaced()).foregroundStyle(.green)
        }
    }

    private func failureView(_ msg: String) -> some View {
        VStack(spacing: 16) {
            Image(systemName: "wifi.exclamationmark")
                .font(.system(size: 44)).foregroundStyle(.red)
            Text("连接失败").font(.headline)
            Text(msg).font(.footnote.monospaced())
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center).padding(.horizontal, 32)
            Button("返回") { phase = .pickServer }
                .buttonStyle(.borderedProminent)
        }
    }

    // MARK: - 逻辑

    private func append(_ text: String, isCommand: Bool = false) {
        for chunk in text.components(separatedBy: "\n") where !chunk.isEmpty {
            lines.append(TerminalLine(text: chunk, isCommand: isCommand))
        }
    }

    private func startProbe(_ conn: SSHConnection) {
        phase = .probing
        active = conn
        lines = []
        let p = TCPProbe()
        probe = p
        Task {
            do {
                let banner = try await p.probe(host: conn.host, port: conn.port)
                await MainActor.run {
                    phase = .ready
                    append("✓ 已连通 \(conn.host):\(conn.port)")
                    append(banner)
                    append("")
                    append("SSH 协议栈实现中（里程碑 1b），当前可验证连通性。")
                }
            } catch {
                await MainActor.run { phase = .failed(error.localizedDescription) }
            }
        }
    }

    private func submitCommand() {
        let cmd = commandText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cmd.isEmpty else { return }
        commandText = ""
        append("$ \(cmd)", isCommand: true)
        append("命令执行需要 SSH 协议支持，将在里程碑 1b 提供。")
    }
}

// MARK: - 终端行模型

struct TerminalLine: Identifiable {
    let id = UUID()
    let text: String
    var isCommand: Bool = false
}

// MARK: - 兼容 iOS 16 的空状态视图（ContentUnavailableView 是 iOS 17 的）

struct ContentUnavailableCompat: View {
    let icon: String
    let title: String
    let detail: String

    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 44))
                .foregroundStyle(.secondary)
            Text(title).font(.headline)
            Text(detail)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 48)
        .listRowBackground(Color.clear)
    }
}
