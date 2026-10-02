import Foundation
import Network

// MARK: - SSH 连接配置
//
// 设计目标：不依赖任何第三方库，保持 iOS 16 兼容。
// 里程碑 1b 将在此之上实现纯 Swift 的 SSH 协议栈
// （版本协商 → 密钥交换 → 加密通道 → 用户认证 → 会话通道），
// 全部基于系统自带的 Network.framework 与 CryptoKit。

struct SSHConnection: Identifiable, Codable, Hashable {
    var id = UUID()
    var name: String
    var host: String
    var port: Int = 22
    var username: String
    var password: String
}

enum SSHStore {
    private static var fileURL: URL {
        let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        return docs.appendingPathComponent("ssh-connections.json")
    }

    static func load() -> [SSHConnection] {
        guard let data = try? Data(contentsOf: fileURL) else { return [] }
        return (try? JSONDecoder().decode([SSHConnection].self, from: data)) ?? []
    }

    static func save(_ list: [SSHConnection]) {
        guard let data = try? JSONEncoder().encode(list) else { return }
        try? data.write(to: fileURL, options: .atomic)
    }
}

// MARK: - TCP 连通性探测
//
// 用系统自带的 Network.framework 连接目标主机端口：
// 成功即说明「网络可达 + SSH 端口在监听」，并读取服务端版本横幅。
// 这是完整 SSH 协议的第一步（RFC 4253 版本交换阶段）。
//
// 并发安全：用专用串行队列 + 状态锁保证 resume 只被调用一次。

/// 探测结果
struct ProbeResult {
    let banner: String
    let elapsed: TimeInterval
}

final class TCPProbe {
    private let queue = DispatchQueue(label: "com.pcfoni.tcp-probe")
    private let lock = NSLock()
    private var connection: NWConnection?
    private var hasResumed = false
    private var continuation: CheckedContinuation<ProbeResult, Error>?

    /// 连接目标端口并读取服务端首行横幅
    func probe(host: String, port: Int, timeout: TimeInterval = 10) async throws -> ProbeResult {
        guard let nwPort = NWEndpoint.Port(rawValue: UInt16(truncatingIfNeeded: max(1, min(port, 65535)))) else {
            throw ProbeError.invalidPort(port)
        }
        let start = Date()
        let endpoint = NWEndpoint.hostPort(host: NWEndpoint.Host(host), port: nwPort)
        let conn = NWConnection(to: endpoint, using: .tcp)

        lock.lock()
        connection = conn
        hasResumed = false
        lock.unlock()

        defer {
            conn.cancel()
            lock.lock()
            connection = nil
            lock.unlock()
        }

        let banner = try await withCheckedThrowingContinuation { (cont: CheckedContinuation<String, Error>) in
            lock.lock()
            continuation = cont
            lock.unlock()

            conn.stateUpdateHandler = { [weak self] state in
                guard let self else { return }
                switch state {
                case .ready:
                    conn.receive(minimumIncompleteLength: 1, maximumLength: 1024) { data, _, _, error in
                        if let error {
                            self.finish(.failure(error))
                        } else if let data, let text = String(data: data, encoding: .utf8) {
                            self.finish(.success(text.trimmingCharacters(in: .whitespacesAndNewlines)))
                        } else {
                            self.finish(.success("(服务端未发送横幅)"))
                        }
                    }
                case .failed(let error):
                    self.finish(.failure(error))
                case .waiting(let error):
                    self.finish(.failure(error))
                default:
                    break
                }
            }
            conn.start(queue: queue)

            queue.asyncAfter(deadline: .now() + timeout) { [weak self] in
                self?.finish(.failure(ProbeError.timeout(Int(timeout))))
            }
        }

        return ProbeResult(banner: banner, elapsed: Date().timeIntervalSince(start))
    }

    /// 线程安全的完成回调：保证 continuation 只 resume 一次
    private func finish(_ result: Result<String, Error>) {
        lock.lock()
        guard !hasResumed, let cont = continuation else {
            lock.unlock()
            return
        }
        hasResumed = true
        continuation = nil
        lock.unlock()

        cont.resume(with: result)
    }

    func cancel() {
        lock.lock()
        let conn = connection
        lock.unlock()
        conn?.cancel()
    }
}

enum ProbeError: LocalizedError {
    case invalidPort(Int)
    case timeout(Int)

    var errorDescription: String? {
        switch self {
        case .invalidPort(let p): return "端口号无效：\(p)"
        case .timeout(let t):     return "连接超时（\(t) 秒），请检查地址与网络"
        }
    }
}
