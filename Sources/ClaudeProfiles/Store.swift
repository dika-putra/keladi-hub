import AppKit
import Foundation

struct Profile: Codable, Identifiable, Equatable {
    let id: String
    var name: String
}

private struct Config: Codable {
    var defaultName: String
    var profiles: [Profile]
}

private let claudeBundleID = "com.anthropic.claudefordesktop"
private let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]

final class Store: ObservableObject {
    static let defaultProfile = Profile(id: "default", name: "Default")

    @Published private(set) var defaultName = "Evermos"
    @Published private(set) var profiles: [Profile] = []
    @Published private(set) var runningPIDs: [String: pid_t] = [:]

    private let configDir = appSupport.appendingPathComponent("ClaudeProfileSwitcher")
    private var configFile: URL { configDir.appendingPathComponent("profiles.json") }

    init() {
        load()
        refreshRunning()
    }

    var all: [Profile] { [Profile(id: Store.defaultProfile.id, name: defaultName)] + profiles }

    // Default profile uses Claude's own data dir (no flag), so existing login is kept.
    // Other profiles use Claude-<id>; the id (not the name) names the folder so rename never moves data.
    func dataDir(_ p: Profile) -> URL {
        p.id == Store.defaultProfile.id
            ? appSupport.appendingPathComponent("Claude")
            : appSupport.appendingPathComponent("Claude-\(p.id)")
    }

    // A profile's folder only exists after Claude was launched with it once, so no folder means "not logged in yet".
    func needsLogin(_ p: Profile) -> Bool {
        p.id != Store.defaultProfile.id && !FileManager.default.fileExists(atPath: dataDir(p).path)
    }

    func add(name: String) {
        let n = name.trimmingCharacters(in: .whitespaces)
        guard !n.isEmpty else { return }
        profiles.append(Profile(id: String(UUID().uuidString.prefix(8)).lowercased(), name: n))
        save()
    }

    func rename(_ p: Profile, to name: String) {
        let n = name.trimmingCharacters(in: .whitespaces)
        guard !n.isEmpty else { return }
        if p.id == Store.defaultProfile.id {
            defaultName = n
        } else if let i = profiles.firstIndex(where: { $0.id == p.id }) {
            profiles[i].name = n
        }
        save()
    }

    func remove(_ p: Profile, deleteData: Bool) {
        guard p.id != Store.defaultProfile.id, let i = profiles.firstIndex(of: p) else { return }
        refreshRunning()
        if deleteData, runningPIDs[p.id] == nil {
            let dir = dataDir(p)
            // Only ever delete Claude-<id> directly under Application Support.
            if dir.deletingLastPathComponent().path == appSupport.path, dir.lastPathComponent == "Claude-\(p.id)" {
                // Keep the profile and its data if the backup fails.
                guard backupHistory(of: p) else { return }
                try? FileManager.default.removeItem(at: dir)
            }
        }
        profiles.remove(at: i)
        save()
    }

    // Copies Code-session history to Backups/<name>-<id>-<timestamp> before a profile's data is deleted.
    private func backupHistory(of p: Profile) -> Bool {
        let fm = FileManager.default
        let src = dataDir(p)
        let items = ["claude-code-sessions", "scratch-workspaces", "git-worktrees.json"]
            .filter { fm.fileExists(atPath: src.appendingPathComponent($0).path) }
        if items.isEmpty { return true }
        let fmt = DateFormatter()
        fmt.dateFormat = "yyyyMMdd-HHmmss"
        let label = p.name.filter { $0.isLetter || $0.isNumber }
        let dest = configDir.appendingPathComponent("Backups/\(label)-\(p.id)-\(fmt.string(from: Date()))")
        do {
            try fm.createDirectory(at: dest, withIntermediateDirectories: true)
            for item in items { try fm.copyItem(at: src.appendingPathComponent(item), to: dest.appendingPathComponent(item)) }
            return true
        } catch {
            return false
        }
    }

    // Main Claude processes only (not Helpers). Matches by --user-data-dir flag.
    func refreshRunning() {
        objectWillChange.send()
        let out = run("/bin/ps", ["-axo", "pid=,command="])
        var found: [String: pid_t] = [:]
        for line in out.split(separator: "\n") {
            let parts = line.trimmingCharacters(in: .whitespaces).split(separator: " ", maxSplits: 1)
            guard parts.count == 2, let pid = pid_t(parts[0]) else { continue }
            let cmd = String(parts[1])
            guard cmd.contains("Claude.app/Contents/MacOS/Claude") else { continue }
            if let r = cmd.range(of: "--user-data-dir=") {
                let dir = String(cmd[r.upperBound...])
                if let p = profiles.first(where: { dataDir($0).path == dir }) { found[p.id] = found[p.id] ?? pid }
            } else if cmd.hasSuffix("Claude.app/Contents/MacOS/Claude") {
                found[Store.defaultProfile.id] = found[Store.defaultProfile.id] ?? pid
            }
        }
        runningPIDs = found
    }

    // Running profile: focus it. Launching again would start a second process on the same data dir.
    func launch(_ p: Profile) {
        refreshRunning()
        if let pid = runningPIDs[p.id] {
            NSRunningApplication(processIdentifier: pid)?.activate()
            return
        }
        guard let appURL = NSWorkspace.shared.urlForApplication(withBundleIdentifier: claudeBundleID) else { return }
        let cfg = NSWorkspace.OpenConfiguration()
        // Always a new instance: if another profile is running, macOS would otherwise just focus it.
        cfg.createsNewApplicationInstance = true
        if p.id != Store.defaultProfile.id {
            cfg.arguments = ["--user-data-dir=\(dataDir(p).path)"]
        }
        NSWorkspace.shared.openApplication(at: appURL, configuration: cfg) { _, _ in
            DispatchQueue.main.asyncAfter(deadline: .now() + 2) { self.refreshRunning() }
        }
    }

    private func load() {
        guard let data = try? Data(contentsOf: configFile) else { return }
        if let cfg = try? JSONDecoder().decode(Config.self, from: data) {
            defaultName = cfg.defaultName
            profiles = cfg.profiles
        } else if let list = try? JSONDecoder().decode([Profile].self, from: data) {
            profiles = list  // first-version format: plain array
        }
    }

    private func save() {
        try? FileManager.default.createDirectory(at: configDir, withIntermediateDirectories: true)
        if let data = try? JSONEncoder().encode(Config(defaultName: defaultName, profiles: profiles)) {
            try? data.write(to: configFile)
        }
    }

    private func run(_ path: String, _ args: [String]) -> String {
        let p = Process()
        p.executableURL = URL(fileURLWithPath: path)
        p.arguments = args
        let pipe = Pipe()
        p.standardOutput = pipe
        try? p.run()
        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        p.waitUntilExit()
        return String(decoding: data, as: UTF8.self)
    }
}
