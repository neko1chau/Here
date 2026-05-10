import SwiftUI

extension Notification.Name {
    static let menubarSettingsChanged = Notification.Name("menubarSettingsChanged")
}

struct CheckmarkModifier: ViewModifier {
    let isChecked: Bool
    func body(content: Content) -> some View {
        HStack {
            content
            Spacer()
            if isChecked {
                Image(systemName: "checkmark")
            }
        }
    }
}

extension View {
    func checkmark(_ isChecked: Bool) -> some View {
        modifier(CheckmarkModifier(isChecked: isChecked))
    }
}

struct SettingsButton: View {
    @State private var settingsHovered: Bool = false
    @Environment(\.openWindow) var openWindow
    @EnvironmentObject var appState: AppState
    @Environment(\.database) var database: AppDatabase
    @Environment(\.colorScheme) var scheme
    @AppStorage("launchAtLogin") private var launchAtLogin = false
    @StateObject private var fetcher = Fetcher()
    @StateObject private var menubarSettings = MenubarSettings.shared
    @Binding var sortOrder: SortOrder
    @State private var showingCustomTextEditor = false
    @State private var customTextInput = ""
    var backgroundColor: Color {
        if scheme == .dark {
            return Color(.gray).opacity(0.2)
        } else {
            return .white
        }
    }

    var body: some View {
        Menu {
            Toggle("Launch at Login", isOn: $launchAtLogin)
                .onChange(of: launchAtLogin) { newValue in
                    if newValue {
                        installLaunchAgent()
                    } else {
                        uninstallLaunchAgent()
                    }
                }
            Toggle("Ascending order", isOn: Binding(
                get: { sortOrder == .timeAscending },
                set: { newValue in
                    sortOrder = newValue ? .timeAscending : .timeDescending
                }
            ))

            Section("Menubar Display") {
                Text("Contact: \(selectedContactName)")
                    .font(.caption)
                    .foregroundColor(.secondary)

                Menu("Change Contact") {
                    Button("None") {
                        menubarSettings.selectedContactId = nil
                        NotificationCenter.default.post(name: .menubarSettingsChanged, object: nil)
                    }
                    if !fetcher.entries.isEmpty {
                        Divider()
                        ForEach(fetcher.entries) { entry in
                            Button(entry.name.isEmpty ? entry.city : entry.name) {
                                menubarSettings.selectedContactId = entry.id
                                NotificationCenter.default.post(name: .menubarSettingsChanged, object: nil)
                            }
                        }
                    }
                }

                if let contactId = menubarSettings.selectedContactId {
                    if let customText = menubarSettings.customDisplayTexts[contactId], !customText.isEmpty {
                        Text("Custom: \(customText)")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    } else {
                        Text("Custom: (not set)")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }

                    Button("Edit Custom Text") {
                        editCustomText(for: contactId)
                    }
                }

                Divider()

                Text("Display Mode: \(menubarSettings.displayMode.displayName)")
                    .font(.caption)
                    .foregroundColor(.secondary)

                Menu("Change Display Mode") {
                    ForEach(MenubarDisplayMode.allCases, id: \.self) { mode in
                        Button(mode.displayName) {
                            menubarSettings.displayMode = mode
                            NotificationCenter.default.post(name: .menubarSettingsChanged, object: nil)
                        }
                    }
                }
            }

            #if targetEnvironment(simulator) || DEBUG
                Section("Dev & Debug") {
                    Button("Clear Cache & Data") {
                        UserDefaults.standard.removeObject(forKey: "hasCompletedInitialSetup")
                        do {
                            _ = try database.dbWriter.write { db in
                                try Entry.deleteAll(db)
                            }
                        } catch {
                            print("Can't clear DB \(error)")
                        }
                    }
                }
            #endif

            Divider()

            Button("Quit") {
                NSApplication.shared.terminate(nil)
            }
            .keyboardShortcut("q", modifiers: .command)
        } label: {
            Image(systemName: "gearshape.fill")
                .font(.body)
        }
        .buttonStyle(SettingsButtonStyle())
    }

    private func editCustomText(for contactId: Int64) {
        let alert = NSAlert()
        alert.messageText = "Custom Display Text"
        alert.informativeText = "Enter text to display in menubar:"
        alert.addButton(withTitle: "Save")
        alert.addButton(withTitle: "Cancel")

        let textField = NSTextField(frame: NSRect(x: 0, y: 0, width: 200, height: 24))
        textField.stringValue = menubarSettings.customDisplayTexts[contactId] ?? ""
        alert.accessoryView = textField

        let response = alert.runModal()
        if response == .alertFirstButtonReturn {
            let text = textField.stringValue
            menubarSettings.setCustomDisplayText(for: contactId, text: text)
        }
    }

    private var selectedContactName: String {
        if let contactId = menubarSettings.selectedContactId,
           let entry = fetcher.entries.first(where: { $0.id == contactId }) {
            return entry.name.isEmpty ? entry.city : entry.name
        }
        return "None"
    }
}

#Preview {
    SettingsButton(sortOrder: .constant(.timeAscending))
}

struct SettingsButtonStyle: ButtonStyle {
    @Environment(\.colorScheme) var scheme
    @State private var isHovered = false

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .foregroundColor(isHovered ? .primary : .secondary)
            .frame(height: 28)
            .padding(.horizontal, 8)
            .background(isHovered ? backgroundColor : .clear)
            .cornerRadius(8)
            .onHover { hovering in
                withAnimation {
                    isHovered = hovering
                }
            }
    }

    private var backgroundColor: Color {
        scheme == .dark ? Color(.gray).opacity(0.2) : .white
    }
}
