import SwiftUI
import Citadel
import NIOCore

// MARK: - SSH 终端（里程碑 1 · 命令式会话）
//
// 连接真实 PC / 服务器，逐条执行命令并显示输出。
// 这是通往 UTM SE 式体验的第一步：先让 iPhone 真正"操作一台电脑"。
// 完整交互式 TTY（vim/top 等）将在里程碑 1b 用 withPTY + SwiftTerm 实现。

struct TerminalView: View {
    private enum Phase: Equatable {
        case pickServer
        case connecting
        case connected
        case failed(String)
    }

    @State private var phase: Phase = .pickServer
    @State private var connections: [SSHConnection] = []
    @State private var showAddSheet = false
    @State private var draft = SSHConnection(name: "", host: "", username: "", password: "")

    @State private var client: SSHClient?
    @State private var activeName = ""
    @State private var lines: [TerminalLine] = []
    @State private var commandText = ""
    @State private var isBusy = false

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            switch phase {
            case .pickServer: serverPicker
            case .connecting: progressView("正在连接…")
            case .connected:  sessionView
            case .failed(let msg): failureView(msg)
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
                            connect(to: conn)
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
            Button { draft = SSHConnection(name: "", host: "", username: "", password: ""); showAddSheet = true } label: {
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
                    Text("服务器需要开启 SSH 服务（端口 22）。密码只保存在本机。")
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
            // 状态栏
            HStack(spacing: 8) {
                Circle().fill(Color.green).frame(width: 8, height: 8)
                Text(activeName).font(.caption.monospaced()).foregroundStyle(.green)
                Spacer()
                if isBusy { ProgressView().tint(.green) }
                Button {
                    if let c = client {
                        Task { try? await c.close() }
                    }
                    client = nil
                    phase = .pickServer
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(.gray)
                }
            }
            .padding(.horizontal)
            .padding(.vertical, 6)
            .background(Color(white: 0.08))

            // 输出流
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 2) {
                        ForEach(lines) { line in
                            Text(line.text)
                                .font(.system(size: 12, weight: .regular, design: .monospaced))
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

            // 输入栏
            HStack(spacing: 8) {
                Text("$").font(.system(.body, design: .monospaced)).foregroundStyle(.green)
                TextField("输入命令…", text: $commandText)
                    .font(.system(.body, design: .monospaced))
                    .foregroundStyle(.white)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .submitLabel(.go)
                    .onSubmit(runCommand)
                Button {
                    runCommand()
                } label: {
                    Image(systemName: "arrowtriangle.right.fill").foregroundStyle(.green)
                }
                .disabled(commandText.isEmpty || isBusy)
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

    private func connect(to conn: SSHConnection) {
        phase = .connecting
        activeName = conn.name
        lines = []
        Task {
            do {
                let settings = SSHClientSettings(
                    host: conn.host,
                    port: conn.port,
                    authenticationMethod: { .passwordBased(username: conn.username, password: conn.password) },
                    hostKeyValidator: .acceptAnything()
                )
                let c = try await SSHClient.connect(to: settings)
                await MainActor.run {
                    client = c
                    phase = .connected
                    append("已连接 \(conn.username)@\(conn.host)（命令式会话，输入命令后回车）")
                }
                if let banner = try? await c.executeCommand("uname -a") {
                    await MainActor.run { append(trim(banner)) }
                }
            } catch {
                await MainActor.run { phase = .failed(error.localizedDescription) }
            }
        }
    }

    private func runCommand() {
        let cmd = commandText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cmd.isEmpty, let c = client, !isBusy else { return }
        commandText = ""
        append("$ \(cmd)", isCommand: true)
        isBusy = true
        Task {
            do {
                let out = try await c.executeCommand(cmd)
                await MainActor.run {
                    append(trim(out).isEmpty ? "(无输出)" : trim(out))
                }
            } catch {
                await MainActor.run {
                    append("命令执行失败：\(error.localizedDescription)")
                    client = nil
                    phase = .failed("会话已断开：\(error.localizedDescription)")
                }
            }
            await MainActor.run { isBusy = false }
        }
    }

    private func trim(_ buffer: ByteBuffer) -> String {
        let s = String(buffer: buffer)
        return s.hasSuffix("\n") ? String(s.dropLast()) : s
    }
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
