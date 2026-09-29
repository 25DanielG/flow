import FlowHistory
import FlowProfiles
import SwiftUI

struct ProfilesView: View {
    @ObservedObject var store: ProfileStore
    @ObservedObject var history: HistoryStore

    @State private var editingID: String?
    @State private var addingSite = false
    @State private var siteText = ""

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 36) {
                PageHeader(title: "Profiles", subtitle: "How Flow formats what you say.")
                profiles
                routing
            }
            .padding(.horizontal, Theme.pagePadding)
            .padding(.top, Theme.topInset)
            .padding(.bottom, 32)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    // MARK: Profiles

    private var profiles: some View {
        VStack(alignment: .leading, spacing: 12) {
            Eyebrow("Default profile")
            Card {
                VStack(spacing: 0) {
                    ForEach(Array(store.profiles.enumerated()), id: \.element.id) { index, profile in
                        if index > 0 { Rectangle().fill(Theme.hairline).frame(height: 1) }
                        profileRow(profile)
                    }
                }
            }
            HStack {
                Button {
                    editingID = store.addProfile()
                } label: {
                    Label("New profile", systemImage: "plus")
                }
                .buttonStyle(SubtleButtonStyle())
            }
        }
    }

    private func profileRow(_ profile: Profile) -> some View {
        let isDefault = profile.id == store.activeProfileID
        let isEditing = editingID == profile.id
        return VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 12) {
                Image(systemName: isDefault ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 15))
                    .foregroundStyle(isDefault ? Color.accentColor : Color.secondary.opacity(0.5))
                Text(profile.name)
                    .font(.system(size: 13.5, weight: isDefault ? .semibold : .regular))
                if isDefault {
                    Text("Default")
                        .font(.system(size: 10, weight: .medium))
                        .foregroundStyle(.secondary)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Capsule().fill(Color.primary.opacity(0.07)))
                }
                Spacer()
                iconButton(isEditing ? "chevron.up" : "pencil") {
                    editingID = isEditing ? nil : profile.id
                }
                if store.profiles.count > 1 {
                    iconButton("trash") {
                        if editingID == profile.id { editingID = nil }
                        store.removeProfile(id: profile.id)
                    }
                }
            }
            .contentShape(Rectangle())
            .onTapGesture { store.setActiveProfile(id: profile.id) }

            if isEditing {
                editor(profile)
            }
        }
        .padding(.vertical, 11)
    }

    private func editor(_ profile: Profile) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            TextField("Name", text: binding(profile, \.name) { store.updateProfile(id: profile.id, name: $0) })
                .textFieldStyle(.plain)
                .font(.system(size: 13))
                .padding(.horizontal, 10)
                .padding(.vertical, 7)
                .background(Color.primary.opacity(0.06), in: RoundedRectangle(cornerRadius: 8, style: .continuous))

            TextEditor(text: binding(profile, \.systemPrompt) { store.updateProfile(id: profile.id, systemPrompt: $0) })
                .font(.system(size: 11.5, design: .monospaced))
                .scrollContentBackground(.hidden)
                .padding(8)
                .frame(height: 220)
                .background(Color.primary.opacity(0.06), in: RoundedRectangle(cornerRadius: 8, style: .continuous))

            HStack {
                Text("Temperature")
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
                Slider(
                    value: binding(profile, \.temperature) { store.updateProfile(id: profile.id, temperature: $0) },
                    in: 0...1, step: 0.05
                )
                .frame(maxWidth: 200)
                Text(String(format: "%.2f", profile.temperature))
                    .font(.system(size: 12))
                    .monospacedDigit()
                    .foregroundStyle(.secondary)
            }
        }
    }

    // read from store, row copy goes stale while typing
    private func binding<Value>(
        _ profile: Profile, _ keyPath: KeyPath<Profile, Value>, set: @escaping (Value) -> Void
    ) -> Binding<Value> {
        Binding(
            get: { (store.profiles.first { $0.id == profile.id } ?? profile)[keyPath: keyPath] },
            set: set
        )
    }

    // MARK: Automatic routing

    private var routing: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Eyebrow("Automatic routing")
                Spacer()
                Toggle("", isOn: Binding(get: { store.autoSwitchEnabled }, set: { store.setAutoSwitch($0) }))
                    .labelsHidden()
                    .toggleStyle(.switch)
                    .controlSize(.small)
            }
            Text("Flow picks the profile from the app or website you're dictating into. Anywhere else, it uses your default.")
                .font(.system(size: 12))
                .foregroundStyle(.secondary)

            if store.autoSwitchEnabled {
                Card {
                    VStack(spacing: 0) {
                        ForEach(Array(store.appRules.enumerated()), id: \.offset) { index, rule in
                            if index > 0 { Rectangle().fill(Theme.hairline).frame(height: 1) }
                            ruleRow(index: index, rule: rule)
                        }
                        if store.appRules.isEmpty {
                            Text("No rules yet.")
                                .font(.system(size: 12))
                                .foregroundStyle(.tertiary)
                        }
                    }
                }
                addRuleControls
            }
        }
    }

    private func ruleRow(index: Int, rule: AppRule) -> some View {
        HStack(spacing: 12) {
            AppGlyph(bundleID: rule.bundleID, siteHost: rule.host, size: 22)
            VStack(alignment: .leading, spacing: 1) {
                Text(rule.label).font(.system(size: 13))
                Text(rule.host ?? rule.bundleID ?? rule.titleContains ?? "")
                    .font(.system(size: 10.5))
                    .foregroundStyle(.tertiary)
                    .lineLimit(1)
            }
            Spacer()
            Picker("", selection: Binding(
                get: { rule.profileID },
                set: { store.updateRule(at: index, profileID: $0) }
            )) {
                ForEach(store.profiles) { Text($0.name).tag($0.id) }
            }
            .labelsHidden()
            .pickerStyle(.menu)
            .fixedSize()
            iconButton("xmark") { store.removeRule(at: index) }
        }
        .padding(.vertical, 8)
    }

    private var addRuleControls: some View {
        HStack(spacing: 10) {
            Menu {
                let apps = suggestedApps
                if !apps.isEmpty {
                    Section("Apps you've dictated in") {
                        ForEach(apps) { entry in
                            Button(entry.name) {
                                store.addRule(AppRule(label: entry.name, bundleID: entry.bundleID, profileID: store.activeProfileID))
                            }
                        }
                    }
                }
                let sites = suggestedSites
                if !sites.isEmpty {
                    Section("Sites") {
                        ForEach(sites) { entry in
                            Button(entry.name) {
                                store.addRule(AppRule(label: entry.name, host: entry.name, profileID: store.activeProfileID))
                            }
                        }
                    }
                }
                Button("Other site…") { addingSite = true }
            } label: {
                Label("Add rule", systemImage: "plus")
            }
            .menuStyle(.borderlessButton)
            .fixedSize()

            if addingSite {
                TextField("example.com", text: $siteText)
                    .textFieldStyle(.plain)
                    .font(.system(size: 12))
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .frame(width: 180)
                    .background(Color.primary.opacity(0.06), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
                    .onSubmit(commitSite)
                Button("Add", action: commitSite)
                    .buttonStyle(SubtleButtonStyle(prominent: true))
                    .disabled(siteText.trimmingCharacters(in: .whitespaces).isEmpty)
            }
        }
    }

    private func commitSite() {
        let host = siteText.trimmingCharacters(in: .whitespaces).lowercased()
        guard !host.isEmpty else { return }
        store.addRule(AppRule(label: host, host: host, profileID: store.activeProfileID))
        siteText = ""
        addingSite = false
    }

    private var suggestedApps: [Insights.Entry] {
        let covered = Set(store.appRules.compactMap(\.bundleID))
        return Insights(records: history.records).apps.filter { !covered.contains($0.id) }.prefix(8).map { $0 }
    }

    private var suggestedSites: [Insights.Entry] {
        let covered = store.appRules.compactMap(\.host)
        return Insights(records: history.records).sites
            .filter { site in !covered.contains { site.name.contains($0) } }
            .prefix(8).map { $0 }
    }

    private func iconButton(_ symbol: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(.system(size: 11, weight: .medium))
                .frame(width: 24, height: 24)
        }
        .buttonStyle(.plain)
        .foregroundStyle(.tertiary)
    }
}
