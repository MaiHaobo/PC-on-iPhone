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

// MARK: - TCP 连通性检测 / 服务端横幅读取
//
// 用系统自带的 Network.framework 建立到目标主机的 TCP 连接：
// 成功即说明「网络可达 + SSH 端口在监听」，并读取服务端版本横幅。
// 这正是完整 SSH 协议的第一步（RFC 4253 版本交换阶段）。

final class TCPProbe {
    private var connection: NWConnection?
    private let queue = DispatchQueue(label: "tcp.probe")

    /// 连接目标端口并读取服务端首行横幅
    /// - Returns: 服务端横幅，例如 "SSH-2.0-OpenSSH_9.6"
    func probe(host: String, port: Int, timeout: TimeInterval = 10) async throws -> String {
        guard let nwPort = NWEndpoint.Port(rawValue: UInt16(clamping: port)) else {
            throw NSError(domain: "TCPProbe", code: -2,
                          userInfo: [NSLocalizedDescriptionKey: "端口号无效：\(port)"])
        }
        let endpoint = NWEndpoint.hostPort(host: NWEndpoint.Host(host), port: nwPort)
        let conn = NWConnection(to: endpoint, using: .tcp)
        connection = conn

        return try await withCheckedThrowingContinuation { cont in
            let lock = NSLock()
            var finished = false
            let finish: (Result<String, Error>) -> Void = { result in
                lock.lock()
                let alreadyDone = finished
                finished = true
                lock.unlock()
                guard !alreadyDone else { return }
                conn.cancel()
                cont.resume(with: result)
            }

            conn.stateUpdateHandler = { state in
                switch state {
                case .ready:
                    conn.receive(minimumIncompleteLength: 1, maximumLength: 1024) { data, _, _, error in
                        if let error {
                            finish(.failure(error))
                        } else if let data, let text = String(data: data, encoding: .utf8) {
                            finish(.success(text.trimmingCharacters(in: .whitespacesAndNewlines)))
                        } else {
                            finish(.success("(服务端未发送横幅)"))
                        }
                    }
                case .failed(let error):
                    finish(.failure(error))
                case .waiting(let error):
                    // 例如目标不可达时 Network 会进入 waiting
                    finish(.failure(error))
                case .cancelled:
                    break
                default:
                    break
                }
            }
            conn.start(queue: queue)

            queue.asyncAfter(deadline: .now() + timeout) {
                finish(.failure(NSError(domain: "TCPProbe", code: -1,
                                        userInfo: [NSLocalizedDescriptionKey: "连接超时（\(Int(timeout)) 秒）"])))
            }
        }
    }

    func cancel() { connection?.cancel() }
}
