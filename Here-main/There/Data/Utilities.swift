import Foundation
import SwiftUI

enum MenubarDisplayMode: String, Codable, CaseIterable {
    case timeOnly = "timeOnly"
    case regionAndTime = "regionAndTime"

    var displayName: String {
        switch self {
        case .timeOnly: return "Time Only"
        case .regionAndTime: return "Region + Time"
        }
    }
}

class MenubarSettings: ObservableObject {
    static let shared = MenubarSettings()

    private let selectedContactIdKey = "menubarSelectedContactId"
    private let displayModeKey = "menubarDisplayMode"
    private let customDisplayTextsKey = "menubarCustomDisplayTexts"

    @Published var selectedContactId: Int64? {
        didSet {
            UserDefaults.standard.set(selectedContactId, forKey: selectedContactIdKey)
        }
    }

    @Published var displayMode: MenubarDisplayMode {
        didSet {
            UserDefaults.standard.set(displayMode.rawValue, forKey: displayModeKey)
        }
    }

    @Published var customDisplayTexts: [Int64: String] {
        didSet {
            if let data = try? JSONEncoder().encode(customDisplayTexts) {
                UserDefaults.standard.set(data, forKey: customDisplayTextsKey)
            }
        }
    }

    func setCustomDisplayText(for contactId: Int64, text: String) {
        customDisplayTexts[contactId] = text
        NotificationCenter.default.post(name: .menubarSettingsChanged, object: nil)
    }

    private init() {
        if let id = UserDefaults.standard.object(forKey: selectedContactIdKey) {
            if let intId = id as? Int64 {
                self.selectedContactId = intId
            } else if let intId = id as? Int {
                self.selectedContactId = Int64(intId)
            } else if let intId = id as? NSNumber {
                self.selectedContactId = intId.int64Value
            }
        } else {
            self.selectedContactId = nil
        }

        if let modeString = UserDefaults.standard.string(forKey: displayModeKey),
           let mode = MenubarDisplayMode(rawValue: modeString) {
            self.displayMode = mode
        } else {
            self.displayMode = .timeOnly
        }

        if let data = UserDefaults.standard.data(forKey: customDisplayTextsKey),
           let texts = try? JSONDecoder().decode([Int64: String].self, from: data) {
            self.customDisplayTexts = texts
        } else {
            self.customDisplayTexts = [:]
        }
    }
}

class Utils {
    public static var shared = Utils()

    private static var localAvatarsDirectory: URL? {
        let fileManager = FileManager.default
        guard let appSupport = try? fileManager.url(
            for: .applicationSupportDirectory,
            in: .userDomainMask,
            appropriateFor: nil,
            create: true
        ) else { return nil }

        let avatarsDir = appSupport.appendingPathComponent("LocalAvatars", isDirectory: true)
        try? fileManager.createDirectory(at: avatarsDir, withIntermediateDirectories: true)
        return avatarsDir
    }

    static func saveLocalAvatar(entryId: Int64, image: NSImage) -> Bool {
        guard let directory = localAvatarsDirectory,
              let tiffData = image.tiffRepresentation,
              let bitmap = NSBitmapImageRep(data: tiffData),
              let pngData = bitmap.representation(using: .png, properties: [:]) else {
            return false
        }

        let fileURL = directory.appendingPathComponent("\(entryId).png")
        do {
            try pngData.write(to: fileURL)
            return true
        } catch {
            print("Failed to save local avatar: \(error)")
            return false
        }
    }

    static func loadLocalAvatar(entryId: Int64) -> NSImage? {
        guard let directory = localAvatarsDirectory else { return nil }
        let fileURL = directory.appendingPathComponent("\(entryId).png")

        guard FileManager.default.fileExists(atPath: fileURL.path) else { return nil }
        return NSImage(contentsOf: fileURL)
    }

    static func removeLocalAvatar(entryId: Int64) {
        guard let directory = localAvatarsDirectory else { return }
        let fileURL = directory.appendingPathComponent("\(entryId).png")
        try? FileManager.default.removeItem(at: fileURL)
    }

    func selectPhoto() -> NSImage? {
        let openPanel = NSOpenPanel()
        openPanel.allowedContentTypes = [.jpeg, .png]
        openPanel.allowsMultipleSelection = false
        openPanel.prompt = "Select Image"
        if openPanel.runModal() == .OK, let url = openPanel.url {
            return NSImage(contentsOf: url)
        } else {
            return nil
        }
    }

    func getCountryEmoji(for countryCode: String) -> String {
        let base: UInt32 = 127397
        return countryCode.uppercased().unicodeScalars.map {
            String(UnicodeScalar(base + $0.value)!)
        }.joined()
    }

    func getRegionName(for timezoneIdentifier: String) -> String {
        let locale = Locale(identifier: "en_US")
        if let timezone = TimeZone(identifier: timezoneIdentifier) {
            let region = timezone.localizedName(for: .standard, locale: locale)
            return region ?? timezoneIdentifier
        }
        return timezoneIdentifier
    }
}
