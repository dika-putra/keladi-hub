import SwiftUI

struct ContentView: View {
    @EnvironmentObject var store: Store
    let close: () -> Void
    @State private var managing = false
    @State private var adding = false
    @State private var newName = ""
    @State private var renaming: Profile?
    @State private var renameText = ""
    @State private var removing: Profile?
    @State private var makingDefault: Profile?
    @State private var restoring: Profile?
    @State private var message: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            ForEach(store.all) { p in row(p) }
            Divider().padding(.vertical, 4)
            if let p = removing {
                removePanel(p)
            } else if let p = makingDefault {
                defaultPanel(p)
            } else if let p = restoring {
                restorePanel(p)
            } else if adding {
                HStack {
                    TextField("Profile name", text: $newName).onSubmit(commitAdd)
                    Button("Add", action: commitAdd)
                    Button("Cancel") { adding = false; newName = "" }
                }
            } else {
                HStack {
                    Button("+ Add profile") { adding = true }
                    Spacer()
                    Button(managing ? "Done" : "Manage") { finishManage() }
                    Button("Quit") { NSApplication.shared.terminate(nil) }
                }
            }
        }
        .buttonStyle(.borderless)
        .padding(12)
        .frame(width: 300)
    }

    private func removePanel(_ p: Profile) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Remove \(p.name)?").font(.headline)
            if store.runningPIDs[p.id] != nil {
                note("Claude is still open with this profile. Close that Claude window first, then remove it.", .orange)
                Button("OK") { removing = nil }
            } else {
                note("Deletes this profile's login, MCP config and cache. Code session history is saved to ~/Library/Application Support/ClaudeProfileSwitcher/Backups first (one backup per Claude account). Chats on claude.ai are not affected.", .secondary)
                Button("Remove and delete all local data") { store.remove(p, deleteData: true); removing = nil }
                    .foregroundStyle(.red)
                Button("Cancel") { removing = nil }
            }
        }
    }

    private func defaultPanel(_ p: Profile) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Make \(p.name) the default?").font(.headline)
            if let msg = message {
                note(msg, .orange)
                Button("OK") { makingDefault = nil; message = nil }
            } else {
                note("Claude opened from Spotlight or the Dock will open this account. The two profiles swap data folders. Close all Claude windows first.", .secondary)
                Button("Make default") {
                    message = store.makeDefault(p)
                    if message == nil { makingDefault = nil }
                }
                Button("Cancel") { makingDefault = nil }
            }
        }
    }

    private func restorePanel(_ p: Profile) -> some View {
        let backups = store.backups()
        return VStack(alignment: .leading, spacing: 6) {
            Text("Restore into \(p.name)").font(.headline)
            if let msg = message {
                note(msg, msg.hasPrefix("Restored") ? .green : .orange)
                Button("OK") { restoring = nil; message = nil }
            } else if backups.isEmpty {
                note("No backups yet. A backup is made when a profile is removed.", .secondary)
                Button("OK") { restoring = nil }
            } else {
                note("Pick a backup. Its Code sessions are merged into this profile. Close this profile's Claude window first.", .secondary)
                ForEach(backups.prefix(6)) { b in
                    Button("\(b.profileName) · account \(b.accountID.prefix(8)) · \(pretty(b.savedAt))") {
                        message = store.restore(b, to: p) ?? "Restored. Open the profile to check the sessions."
                    }
                }
                Button("Cancel") { restoring = nil }
            }
        }
    }

    private func note(_ text: String, _ color: Color) -> some View {
        Text(text).font(.caption).foregroundStyle(color).fixedSize(horizontal: false, vertical: true)
    }

    // Launching is only possible outside Manage mode, so rename/remove never share a row with an "open" tap target.
    @ViewBuilder
    private func row(_ p: Profile) -> some View {
        let isDefault = p.id == Store.defaultProfile.id
        let running = store.runningPIDs[p.id] != nil
        let title = isDefault ? "\(p.name) (default)" : p.name
        if managing {
            HStack {
                RunningDot(running: running)
                if renaming == p {
                    TextField("Name", text: $renameText).onSubmit {
                        store.rename(p, to: renameText)
                        renaming = nil
                    }
                } else {
                    Text(title).frame(maxWidth: .infinity, alignment: .leading)
                }
                Button { renaming = p; renameText = p.name } label: { Image(systemName: "pencil") }
                    .help("Rename")
                Button { message = nil; restoring = p } label: { Image(systemName: "arrow.counterclockwise") }
                    .help("Restore a backup")
                if !isDefault {
                    Button {
                        store.refreshRunning()
                        message = store.runningPIDs.isEmpty ? nil : "Claude is still open. Close all Claude windows first, then make this profile the default."
                        makingDefault = p
                    } label: { Image(systemName: "star") }
                        .help("Make default")
                    Button { store.refreshRunning(); removing = p } label: { Image(systemName: "trash") }
                        .help("Remove")
                }
            }
            .padding(.vertical, 6)
            .padding(.horizontal, 8)
        } else {
            LaunchRow(title: title, running: running, actionLabel: running ? "Show" : (store.needsLogin(p) ? "Login" : "Open")) {
                store.launch(p)
                close()
            }
        }
    }

    private func pretty(_ date: Date) -> String {
        let f = DateFormatter()
        f.dateFormat = "d MMM HH:mm"
        return f.string(from: date)
    }

    private func finishManage() {
        if managing, let p = renaming { store.rename(p, to: renameText) }
        renaming = nil
        managing.toggle()
    }

    private func commitAdd() {
        store.add(name: newName)
        newName = ""
        adding = false
    }
}

private struct RunningDot: View {
    let running: Bool
    var body: some View {
        Circle().fill(running ? Color.green : Color.clear).frame(width: 7, height: 7)
    }
}

private struct LaunchRow: View {
    let title: String
    let running: Bool
    let actionLabel: String
    let action: () -> Void
    @State private var hovering = false

    var body: some View {
        Button(action: action) {
            HStack {
                RunningDot(running: running)
                Text(title)
                Spacer()
                Text(actionLabel).font(.caption).foregroundStyle(.secondary)
                Image(systemName: "arrow.up.forward.app").foregroundStyle(.secondary)
            }
            .padding(.vertical, 8)
            .padding(.horizontal, 8)
            .frame(maxWidth: .infinity)
            .background(RoundedRectangle(cornerRadius: 6).fill(Color.primary.opacity(hovering ? 0.12 : 0.05)))
            .contentShape(Rectangle())
        }
        .help("Open Claude with this profile")
        .onHover { hovering = $0 }
    }
}
