import AppKit
import CoreLocation
import Foundation
import MapKit
import SwiftUI

extension EditTimeZoneView {
    func saveEntry() {
        guard let entry = entry else { return }

        if showingLocalUpload {
            if let localImage = image {
                _ = Utils.saveLocalAvatar(entryId: entry.id, image: localImage)
            } else {
                Utils.removeLocalAvatar(entryId: entry.id)
            }
        }

        let fileName = UUID().uuidString + ".png"
        let fileURL = getApplicationSupportDirectory().appendingPathComponent(fileName)

        var photoDataString: String? = nil
        if let tiffData = image?.tiffRepresentation,
           let bitmapImage = NSBitmapImageRep(data: tiffData),
           let pngData = bitmapImage.representation(using: .png, properties: [:]) {
            do {
                try pngData.write(to: fileURL)
                photoDataString = fileURL.absoluteString
            } catch {
                print("Failed to save image: \(error)")
            }
        }

        do {
            try database.dbWriter.write { db in
                let entry = Entry(
                    id: entry.id,
                    type: !countryEmoji.isEmpty && image == nil ? .place : .person,
                    name: name,
                    city: city,
                    timezoneIdentifier: selectedTimeZone?.identifier ?? "",
                    flag: image == nil ? countryEmoji : "",
                    photoData: photoDataString
                )
                try entry.save(db)
            }
            NotificationCenter.default.post(name: .entriesChanged, object: nil)
            NotificationCenter.default.post(name: .menubarSettingsChanged, object: nil)
        } catch {
            print("Failed to save entry \(error)")
        }

        router.cleanActiveRoute()
    }

    private func getApplicationSupportDirectory() -> URL {
        FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
    }
}
