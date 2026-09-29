import Foundation

private struct ProfilesFile: Codable {
    var profiles: [Profile]
    var activeProfileID: String
    var defaultsVersion: Int?
    // nil in old files
    var autoSwitch: Bool?
    var appRules: [AppRule]?
}

// profiles.json in app support, watched for hand edits
@MainActor
public final class ProfileStore: ObservableObject {
    @Published public private(set) var profiles: [Profile]
    @Published public private(set) var activeProfileID: String
    @Published public private(set) var appRules: [AppRule]
    @Published public private(set) var autoSwitchEnabled: Bool

    public let fileURL: URL
    private var watcherSource: DispatchSourceFileSystemObject?
    private var defaultsVersion: Int?

    public init() {
        let supportDir = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("Flow", isDirectory: true)
        try? FileManager.default.createDirectory(at: supportDir, withIntermediateDirectories: true)
        self.fileURL = supportDir.appendingPathComponent("profiles.json")

        if let loaded = Self.load(from: fileURL) {
            self.profiles = loaded.profiles
            self.activeProfileID = loaded.activeProfileID
            self.defaultsVersion = loaded.defaultsVersion
            self.appRules = loaded.appRules ?? DefaultAppRules.all
            self.autoSwitchEnabled = loaded.autoSwitch ?? true
            migrateStockProfilesIfNeeded()
            if loaded.appRules == nil || loaded.autoSwitch == nil { save() }
        } else {
            self.appRules = DefaultAppRules.all
            self.autoSwitchEnabled = true
            self.profiles = DefaultProfiles.all
            self.activeProfileID = DefaultProfiles.writing.id
            self.defaultsVersion = DefaultProfiles.version
            save()
        }

        startWatching()
    }

    public var activeProfile: Profile {
        profiles.first(where: { $0.id == activeProfileID }) ?? profiles[0]
    }

    public struct Resolution {
        public let profile: Profile
        public let rule: AppRule?
    }

    public func resolveProfile(bundleID: String?, url: String?, title: String?) -> Resolution {
        if autoSwitchEnabled {
            for rule in appRules where rule.matches(bundleID: bundleID, url: url, title: title) {
                if let profile = profiles.first(where: { $0.id == rule.profileID }) {
                    return Resolution(profile: profile, rule: rule)
                }
            }
        }
        return Resolution(profile: activeProfile, rule: nil)
    }

    // top of list, first match wins
    public func addRule(_ rule: AppRule) {
        appRules.insert(rule, at: 0)
        save()
    }

    public func updateRule(at index: Int, profileID: String) {
        guard appRules.indices.contains(index) else { return }
        appRules[index].profileID = profileID
        save()
    }

    public func removeRule(at index: Int) {
        guard appRules.indices.contains(index) else { return }
        appRules.remove(at: index)
        save()
    }

    public func setAutoSwitch(_ enabled: Bool) {
        autoSwitchEnabled = enabled
        save()
    }

    public func setActiveProfile(id: String) {
        guard profiles.contains(where: { $0.id == id }) else { return }
        activeProfileID = id
        save()
    }

    @discardableResult
    public func addProfile(name: String = "New Profile", systemPrompt: String = "", temperature: Double = 0.3) -> String {
        let profile = Profile(id: UUID().uuidString, name: name, systemPrompt: systemPrompt, temperature: temperature)
        profiles.append(profile)
        save()
        return profile.id
    }

    public func updateProfile(id: String, name: String? = nil, systemPrompt: String? = nil, temperature: Double? = nil) {
        guard let index = profiles.firstIndex(where: { $0.id == id }) else { return }
        if let name { profiles[index].name = name }
        if let systemPrompt { profiles[index].systemPrompt = systemPrompt }
        if let temperature { profiles[index].temperature = temperature }
        save()
    }

    // can't delete the last one
    public func removeProfile(id: String) {
        guard profiles.count > 1, let index = profiles.firstIndex(where: { $0.id == id }) else { return }
        profiles.remove(at: index)
        if activeProfileID == id {
            activeProfileID = profiles[0].id
        }
        save()
    }

    // overwrites stock profiles by id, backs up old file first. custom ones untouched
    private func migrateStockProfilesIfNeeded() {
        guard (defaultsVersion ?? 0) < DefaultProfiles.version else { return }
        let backupURL = fileURL.deletingLastPathComponent()
            .appendingPathComponent("profiles.v\(defaultsVersion ?? 0).backup.json")
        try? FileManager.default.removeItem(at: backupURL)
        try? FileManager.default.copyItem(at: fileURL, to: backupURL)

        for stock in DefaultProfiles.all {
            if let index = profiles.firstIndex(where: { $0.id == stock.id }) {
                profiles[index] = stock
            } else {
                profiles.append(stock)
            }
        }
        defaultsVersion = DefaultProfiles.version
        save()
    }

    private static func load(from url: URL) -> ProfilesFile? {
        guard let data = try? Data(contentsOf: url) else { return nil }
        return try? JSONDecoder().decode(ProfilesFile.self, from: data)
    }

    private func save() {
        let file = ProfilesFile(profiles: profiles, activeProfileID: activeProfileID, defaultsVersion: defaultsVersion,
                                autoSwitch: autoSwitchEnabled, appRules: appRules)
        guard let data = try? JSONEncoder.prettyPrinted.encode(file) else { return }
        // pause watcher so we don't reload our own write
        watcherSource?.cancel()
        try? data.write(to: fileURL, options: .atomic)
        startWatching()
    }

    private func startWatching() {
        let fd = open(fileURL.path, O_EVTONLY)
        guard fd >= 0 else { return }

        let source = DispatchSource.makeFileSystemObjectSource(fileDescriptor: fd, eventMask: .write, queue: .main)
        source.setEventHandler { [weak self] in
            self?.reloadFromDisk()
        }
        source.setCancelHandler { close(fd) }
        source.resume()
        watcherSource = source
    }

    private func reloadFromDisk() {
        guard let loaded = Self.load(from: fileURL) else { return }
        profiles = loaded.profiles
        defaultsVersion = loaded.defaultsVersion
        appRules = loaded.appRules ?? appRules
        autoSwitchEnabled = loaded.autoSwitch ?? autoSwitchEnabled
        activeProfileID = loaded.profiles.contains(where: { $0.id == loaded.activeProfileID })
            ? loaded.activeProfileID
            : (profiles.first?.id ?? activeProfileID)
    }
}

private extension JSONEncoder {
    static var prettyPrinted: JSONEncoder {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        return encoder
    }
}
