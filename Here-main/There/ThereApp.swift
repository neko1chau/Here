//
//  ThereApp.swift
//  There
//
//  Created by Dena Sohrabi on 9/2/24.
//

import AppKit
import Combine
import GRDB
import MenuBarExtraAccess
import PostHog
import SwiftUI
import UserNotifications

@main
struct ThereApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    @Environment(\.openWindow) var openWindow
    @ObservedObject var appState = AppState.shared
    @StateObject var router: Router = Router()
    @StateObject private var menubarSettings = MenubarSettings.shared

    var body: some Scene {
        MenuBarExtra {
            ContentView()
                .environment(\.database, .shared)
                .frame(width: 320)
                .frame(minHeight: 300)
                .frame(maxHeight: 600)
                .background(Color(NSColor.windowBackgroundColor).opacity(0.78).ignoresSafeArea())
                .environmentObject(appState)
                .environmentObject(router)
        } label: {
            MenuBarLabel()
                .fixedSize()
        }
        .menuBarExtraStyle(.window)
        .windowResizability(.contentSize)

        WindowGroup("init", id: "init") {
            InitialView()
                .environment(\.database, .shared)
                .fixedSize()
                .frame(width: 600, height: 400)
                .environmentObject(appState)
        }
        .windowStyle(.hiddenTitleBar)
        .defaultSize(width: 600, height: 400)
        .defaultPosition(.center)
        .windowResizability(.contentSize)
        #if MAC_OS_VERSION_15_0
            .windowBackgroundDragBehavior(.enabled)
        #endif

        Settings {
            Text("Coming soon...")
        }
        #if MAC_OS_VERSION_15_0
            .windowStyle(.plain)
        #endif
            .defaultSize(width: 600, height: 400)
            .windowResizability(.automatic)
    }
}

struct MenuBarLabel: View {
    @StateObject private var menubarSettings = MenubarSettings.shared
    @State private var currentDate = Date()
    @State private var selectedEntry: Entry?
    @State private var cancellables = Set<AnyCancellable>()

    var body: some View {
        Group {
            if let entry = selectedEntry {
                if menubarSettings.displayMode == .regionAndTime {
                    VStack(spacing: -1) {
                        Text(customRegionName(for: entry))
                            .font(.system(size: 8, weight: .regular))
                            .lineLimit(1)
                        Text(formattedTime(for: entry))
                            .font(.system(size: 10, weight: .medium))
                            .monospacedDigit()
                            .lineLimit(1)
                    }
                } else {
                    Text(formattedTime(for: entry))
                        .font(.system(size: 10, weight: .medium))
                        .monospacedDigit()
                }
            } else {
                Image(systemName: "clock")
                    .font(.system(size: 14))
            }
        }
        .onAppear {
            loadSelectedEntry()
            startTimer()
        }
        .onReceive(NotificationCenter.default.publisher(for: .menubarSettingsChanged)) { _ in
            loadSelectedEntry()
        }
        .onReceive(NotificationCenter.default.publisher(for: .entriesChanged)) { _ in
            loadSelectedEntry()
        }
    }

    private func loadSelectedEntry() {
        print("DEBUG selectedContactId = \(String(describing: menubarSettings.selectedContactId))")
        print("DEBUG displayMode = \(menubarSettings.displayMode)")
        guard let contactId = menubarSettings.selectedContactId else {
            selectedEntry = nil
            return
        }

        Task {
            do {
                let entry = try await AppDatabase.shared.reader.read { db in
                    try Entry.fetchOne(db, key: contactId)
                }
                await MainActor.run {
                    self.selectedEntry = entry
                }
            } catch {
                print("Failed to load selected entry: \(error)")
            }
        }
    }

    private func startTimer() {
        Timer.publish(every: 1, on: .main, in: .common)
            .autoconnect()
            .sink { _ in
                self.currentDate = Date()
                self.loadSelectedEntry()
            }
            .store(in: &cancellables)
    }

    private func customRegionName(for entry: Entry) -> String {
        if let contactId = menubarSettings.selectedContactId,
           let customText = MenubarSettings.shared.customDisplayTexts[contactId],
           !customText.isEmpty {
            return customText
        }
        return Utils.shared.getRegionName(for: entry.timezoneIdentifier)
    }

    private func formattedTime(for entry: Entry) -> String {
        guard let timeZone = TimeZone(identifier: entry.timezoneIdentifier) else {
            return ""
        }

        let formatter = DateFormatter()
        formatter.timeZone = timeZone
        formatter.dateFormat = "HH:mm"
        return formatter.string(from: currentDate)
    }

    private func regionName(for entry: Entry) -> String {
        return Utils.shared.getRegionName(for: entry.timezoneIdentifier)
    }
}

extension Notification.Name {
    static let entriesChanged = Notification.Name("entriesChanged")
}

extension EnvironmentValues {
    @Entry var database: AppDatabase = .shared
}

class AppState: ObservableObject {
    static let shared = AppState()
    @Published var menuBarViewIsPresented: Bool = false
    func presentMenu() {
        menuBarViewIsPresented = true
    }

    func hideMenu() {
        menuBarViewIsPresented = true
    }
}

class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_: Notification) {
        let POSTHOG_API_KEY = "phc_XZFRnJFd8RVNegex9sLKplgz8KCFxGyLZwxh5usmoig"
        let POSTHOG_HOST = "https://eu.i.posthog.com"

        let config = PostHogConfig(apiKey: POSTHOG_API_KEY, host: POSTHOG_HOST)
        PostHogSDK.shared.setup(config)
    }
}
