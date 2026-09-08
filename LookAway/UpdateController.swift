import AppKit
import CryptoKit
import Foundation

struct ReleaseManifest: Codable, Equatable {
    let version: String
    let url: URL
    let sha256: String
}

struct ReleaseVersion: Comparable, Equatable {
    let parts: [Int]

    init(_ text: String) {
        parts = text.split(separator: ".").map { Int($0) ?? 0 }
    }

    static func == (lhs: ReleaseVersion, rhs: ReleaseVersion) -> Bool {
        let count = max(lhs.parts.count, rhs.parts.count)
        for index in 0..<count {
            let a = index < lhs.parts.count ? lhs.parts[index] : 0
            let b = index < rhs.parts.count ? rhs.parts[index] : 0
            if a != b { return false }
        }
        return true
    }

    static func < (lhs: ReleaseVersion, rhs: ReleaseVersion) -> Bool {
        let count = max(lhs.parts.count, rhs.parts.count)
        for index in 0..<count {
            let a = index < lhs.parts.count ? lhs.parts[index] : 0
            let b = index < rhs.parts.count ? rhs.parts[index] : 0
            if a != b { return a < b }
        }
        return false
    }
}

@MainActor
final class UpdateController {
    private let manifestURL = URL(string: "https://github.com/longnt27/lookaway/releases/latest/download/latest.json")!
    private var timer: Timer?
    private var checking = false
    private var canInstall: () -> Bool = { true }

    func startAutomaticChecks(canInstall: @escaping () -> Bool) {
        self.canInstall = canInstall
        timer?.invalidate()
        timer = Timer.scheduledTimer(withTimeInterval: 6 * 60 * 60, repeats: true) { [weak self] _ in
            Task { @MainActor in await self?.check(manual: false) }
        }
        Task {
            try? await Task.sleep(for: .seconds(20))
            await check(manual: false)
        }
    }

    func stop() {
        timer?.invalidate()
        timer = nil
    }

    func checkManually() {
        Task { await check(manual: true) }
    }

    private func check(manual: Bool) async {
        guard !checking else { return }
        checking = true
        defer { checking = false }
        do {
            let (data, response) = try await URLSession.shared.data(from: manifestURL)
            guard (response as? HTTPURLResponse)?.statusCode == 200 else { throw UpdateError.badResponse }
            let manifest = try JSONDecoder().decode(ReleaseManifest.self, from: data)
            guard manifest.url.scheme == "https", manifest.url.host == "github.com",
                  manifest.url.path.hasPrefix("/longnt27/lookaway/releases/download/") else {
                throw UpdateError.untrustedURL
            }
            let current = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "0"
            guard ReleaseVersion(current) < ReleaseVersion(manifest.version) else {
                if manual { showAlert(title: "LookAway is up to date", message: "You have version \(current).") }
                return
            }
            guard canInstall() else {
                if manual { showAlert(title: "Update ready later", message: "Finish the current break before updating.") }
                return
            }
            try await downloadAndInstall(manifest)
        } catch {
            if manual { showAlert(title: "Update failed", message: error.localizedDescription) }
        }
    }

    private func downloadAndInstall(_ manifest: ReleaseManifest) async throws {
        let destination = Bundle.main.bundleURL
        let parent = destination.deletingLastPathComponent()
        guard FileManager.default.isWritableFile(atPath: parent.path) else { throw UpdateError.installLocationNotWritable }

        let (downloaded, response) = try await URLSession.shared.download(from: manifest.url)
        guard (response as? HTTPURLResponse)?.statusCode == 200 else { throw UpdateError.badResponse }
        let data = try Data(contentsOf: downloaded, options: .mappedIfSafe)
        let digest = SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined()
        guard digest.caseInsensitiveCompare(manifest.sha256) == .orderedSame else { throw UpdateError.checksumMismatch }

        let root = FileManager.default.temporaryDirectory.appendingPathComponent("LookAway-update-\(UUID().uuidString)", isDirectory: true)
        let unpacked = root.appendingPathComponent("unpacked", isDirectory: true)
        try FileManager.default.createDirectory(at: unpacked, withIntermediateDirectories: true)
        let zip = root.appendingPathComponent("LookAway.zip")
        try FileManager.default.copyItem(at: downloaded, to: zip)
        try run("/usr/bin/ditto", ["-x", "-k", zip.path, unpacked.path])

        let staged = unpacked.appendingPathComponent("LookAway.app", isDirectory: true)
        guard let bundle = Bundle(url: staged),
              bundle.bundleIdentifier == Bundle.main.bundleIdentifier,
              (bundle.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String) == manifest.version,
              FileManager.default.isExecutableFile(atPath: staged.appendingPathComponent("Contents/MacOS/LookAway").path) else {
            throw UpdateError.invalidBundle
        }

        let script = root.appendingPathComponent("install-update.sh")
        let body = """
        #!/bin/sh
        set -eu
        PID="$1"
        STAGED="$2"
        DEST="$3"
        ROOT="$4"
        while kill -0 "$PID" >/dev/null 2>&1; do sleep 0.2; done
        BACKUP="${DEST}.lookaway-old-$$"
        rm -rf "$BACKUP"
        if [ -e "$DEST" ]; then mv "$DEST" "$BACKUP"; fi
        if /usr/bin/ditto "$STAGED" "$DEST"; then
          rm -rf "$BACKUP"
          /usr/bin/open "$DEST"
          rm -rf "$ROOT"
        else
          rm -rf "$DEST"
          if [ -e "$BACKUP" ]; then mv "$BACKUP" "$DEST"; fi
          exit 1
        fi
        """
        try body.write(to: script, atomically: true, encoding: .utf8)

        let helper = Process()
        helper.executableURL = URL(fileURLWithPath: "/bin/sh")
        helper.arguments = [script.path, String(ProcessInfo.processInfo.processIdentifier), staged.path, destination.path, root.path]
        try helper.run()
        NSApplication.shared.terminate(nil)
    }

    private func run(_ executable: String, _ arguments: [String]) throws {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: executable)
        process.arguments = arguments
        try process.run()
        process.waitUntilExit()
        guard process.terminationStatus == 0 else { throw UpdateError.unpackFailed }
    }

    private func showAlert(title: String, message: String) {
        NSApplication.shared.activate(ignoringOtherApps: true)
        let alert = NSAlert()
        alert.messageText = title
        alert.informativeText = message
        alert.addButton(withTitle: "OK")
        alert.runModal()
    }
}

enum UpdateError: LocalizedError {
    case badResponse, untrustedURL, checksumMismatch, invalidBundle, unpackFailed, installLocationNotWritable

    var errorDescription: String? {
        switch self {
        case .badResponse: return "The release server returned an unexpected response."
        case .untrustedURL: return "The release manifest points to an unexpected download location."
        case .checksumMismatch: return "The downloaded update failed SHA-256 verification."
        case .invalidBundle: return "The downloaded archive does not contain the expected LookAway app."
        case .unpackFailed: return "The downloaded update could not be unpacked."
        case .installLocationNotWritable: return "LookAway cannot update itself from this folder. Reinstall it with the one-line installer so it lives in ~/Applications."
        }
    }
}
