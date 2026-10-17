import SwiftUI

struct ContentView: View {
    @EnvironmentObject var store: Store
    @State private var managing = false
    @State private var adding = false
    @State private var newName = ""
    @State private var renaming: Profile?
    @State private var renameText = ""
    @State private var removing: Profile?

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            ForEach(store.all) { p in row(p) }
            Divider().padding(.vertical, 4)
            if adding {
                HStack {
                    TextField("Profile name", text: $newName).onSubmit(commitAdd)
                    Button("Add", action: commitAdd)
                    Button("Cancel") { adding = false; newName = "" }
                }
            } else {
                HStack {
                    Button("+ Add profile") { adding = true }
                    Spacer()
                    Button(managing ? "Done" : "Manage") { managing.toggle() }
                    Button("Quit") { NSApplication.shared.terminate(nil) }
                }
            }
        }
        .buttonStyle(.borderless)
        .padding(12)
        .frame(width: 280)
        .onAppear { store.refreshRunning() }
        .confirmationDialog(
            "Remove \(removing?.name ?? "")?", isPresented: Binding(get: { removing != nil }, set: { if !$0 { removing = nil } })
        ) {
            Button("Remove profile (keep data)") { if let p = removing { store.remove(p, deleteData: false) } }
            Button("Remove and delete login/chat data", role: .destructive) {
                if let p = removing { store.remove(p, deleteData: true) }
            }
            Button("Cancel", role: .cancel) {}
        }
    }

    @ViewBuilder
    private func row(_ p: Profile) -> some View {
        let isDefault = p.id == Store.defaultProfile.id
        HStack {
            Circle().fill(store.runningPIDs[p.id] != nil ? .green : .clear).frame(width: 7, height: 7)
            if renaming == p {
                TextField("Name", text: $renameText).onSubmit {
                    store.rename(p, to: renameText)
                    renaming = nil
                }
            } else {
                Button(p.name) { store.launch(p) }.frame(maxWidth: .infinity, alignment: .leading)
            }
            if managing && !isDefault {
                Button { renaming = p; renameText = p.name } label: { Image(systemName: "pencil") }
                Button { removing = p } label: { Image(systemName: "trash") }
            }
        }
        .padding(.vertical, 3)
    }

    private func commitAdd() {
        store.add(name: newName)
        newName = ""
        adding = false
    }
}
