import Combine
import Foundation
import ServiceManagement

/// The operating system is the source of truth. Merely opening Settings never registers the app.
@MainActor
final class LoginItemController: ObservableObject {
    enum Status: Equatable {
        case disabled, enabled, requiresApproval, unavailable
    }

    @Published private(set) var status: Status = .disabled
    @Published private(set) var errorMessage: String?
    private let readStatus: () -> Status
    private let register: () throws -> Void
    private let unregister: () throws -> Void
    private let openSystemSettings: () -> Void

    init(readStatus: @escaping () -> Status = {
        switch SMAppService.mainApp.status {
        case .notRegistered: return .disabled
        case .enabled: return .enabled
        case .requiresApproval: return .requiresApproval
        case .notFound: return .unavailable
        @unknown default: return .unavailable
        }
    }, register: @escaping () throws -> Void = { try SMAppService.mainApp.register() },
         unregister: @escaping () throws -> Void = { try SMAppService.mainApp.unregister() },
         openSystemSettings: @escaping () -> Void = { SMAppService.openSystemSettingsLoginItems() }) {
        self.readStatus = readStatus
        self.register = register
        self.unregister = unregister
        self.openSystemSettings = openSystemSettings
        refresh()
    }

    var isOn: Bool { status == .enabled || status == .requiresApproval }

    func refresh() { status = readStatus() }

    func setEnabled(_ enabled: Bool) {
        refresh()
        errorMessage = nil
        guard enabled != isOn else { return }
        do {
            if enabled { try register() } else { try unregister() }
        } catch {
            errorMessage = "Could not change launch at login: \(error.localizedDescription)"
        }
        refresh()
    }

    func manageInSystemSettings() { openSystemSettings() }
}
