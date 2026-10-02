import Foundation

// MARK: - SSH 连接配置
//
// 里程碑 1 采用最简单的本地 JSON 持久化。
// 后续里程碑会把密码迁移到 Keychain，并支持密钥认证。

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
