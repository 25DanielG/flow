import AppKit
import FlowAudio
import FlowClaude
import FlowContext
import FlowHistory
import FlowHotkey
import FlowInsert
import FlowPostProcess
import FlowProfiles
import FlowTranscribe
import FlowUI
import FlowVocabulary

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private let permissions = PermissionsManager()
    private let appStatus = AppStatus()
    private let fnKeyMonitor = FNKeyMonitor()
    private let audioCapture = AudioCapture()
    private let waveformPanel = WaveformPanelController()
    private var whisperContext: WhisperContext?
    private let profileStore = ProfileStore()
    private let historyStore = HistoryStore()
    private let vocabularyStore = VocabularyStore()
    private lazy var mainWindowController = MainWindowController(
        historyStore: historyStore, profileStore: profileStore, vocabularyStore: vocabularyStore,
        status: appStatus, permissions: permissions
    )
    private let postProcessBackend = ClaudePostProcessBackend()

    func applicationDidFinishLaunching(_ notification: Notification) {
        // also in Info.plist, this is for `swift run`
        NSApp.setActivationPolicy(.regular)
        installMainMenu()

        // errors show in the waveform pill
        appStatus.onToast = { [weak self] message in self?.waveformPanel.flash(message) }

        fnKeyMonitor.delegate = self
        _ = fnKeyMonitor.start() // needs input monitoring, retried below

        promptForMissingPermissionsIfNeeded()
        loadWhisperModel()
        mainWindowController.show()
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool { false }

    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        if !flag { mainWindowController.show() }
        return true
    }

    // edit menu needed for cmd+v in text fields
    private func installMainMenu() {
        let mainMenu = NSMenu()

        let appItem = NSMenuItem()
        let appMenu = NSMenu()
        appMenu.addItem(withTitle: "Hide Flow", action: #selector(NSApplication.hide(_:)), keyEquivalent: "h")
        appMenu.addItem(.separator())
        appMenu.addItem(withTitle: "Quit Flow", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        appItem.submenu = appMenu
        mainMenu.addItem(appItem)

        let editItem = NSMenuItem()
        let edit = NSMenu(title: "Edit")
        edit.addItem(withTitle: "Undo", action: Selector(("undo:")), keyEquivalent: "z")
        edit.addItem(withTitle: "Redo", action: Selector(("redo:")), keyEquivalent: "Z")
        edit.addItem(.separator())
        edit.addItem(withTitle: "Cut", action: #selector(NSText.cut(_:)), keyEquivalent: "x")
        edit.addItem(withTitle: "Copy", action: #selector(NSText.copy(_:)), keyEquivalent: "c")
        edit.addItem(withTitle: "Paste", action: #selector(NSText.paste(_:)), keyEquivalent: "v")
        edit.addItem(withTitle: "Select All", action: #selector(NSText.selectAll(_:)), keyEquivalent: "a")
        editItem.submenu = edit
        mainMenu.addItem(editItem)

        let windowItem = NSMenuItem()
        let window = NSMenu(title: "Window")
        window.addItem(withTitle: "Minimize", action: #selector(NSWindow.performMiniaturize(_:)), keyEquivalent: "m")
        window.addItem(withTitle: "Close", action: #selector(NSWindow.performClose(_:)), keyEquivalent: "w")
        windowItem.submenu = window
        mainMenu.addItem(windowItem)
        NSApp.windowsMenu = window

        NSApp.mainMenu = mainMenu
    }

    // TODO proper model management
    private func loadWhisperModel() {
        let path = ProcessInfo.processInfo.environment["FLOW_MODEL_PATH"]
            ?? (NSHomeDirectory() as NSString).appendingPathComponent(
                "Documents/dev/whisper/vendor/whisper.cpp/models/ggml-small.en.bin"
            )
        Task { @MainActor in
            do {
                whisperContext = try WhisperContext(modelPath: path)
                print("Flow: whisper model loaded from \(path)")
            } catch {
                print("Flow: failed to load whisper model at \(path): \(error)")
            }
        }
    }

    private func promptForMissingPermissionsIfNeeded() {
        for kind in PermissionKind.allCases where permissions.status(for: kind) == .denied {
            permissions.request(kind) { [weak self] _ in
                if kind == .inputMonitoring {
                    // retry tap now that it's granted
                    _ = self?.fnKeyMonitor.start()
                }
            }
        }
    }
}

extension AppDelegate: FNKeyMonitorDelegate {
    func fnKeyMonitor(_ monitor: FNKeyMonitor, didProduce effect: DictationTriggerEffect) {
        switch effect {
        case .startRecording:
            waveformPanel.state.reset()
            waveformPanel.show()
            appStatus.setDictationState(.recording)
            do {
                try audioCapture.start { [weak self] level in
                    self?.waveformPanel.state.pushLevel(level)
                }
            } catch {
                print("Flow: failed to start audio capture: \(error)")
                waveformPanel.hide()
                appStatus.flashError("Couldn't start audio capture")
            }

        case .promoteToLocked:
            waveformPanel.state.isLocked = true
            appStatus.setDictationState(.locked)

        case .stopAndTranscribe:
            appStatus.setDictationState(.idle)
            waveformPanel.hide()
            // grab frontmost app now, slow AX reads happen in bg while whisper runs
            let foregroundApp = ForegroundContextReader.currentApp()
            let contextTask = Task.detached(priority: .userInitiated) {
                ForegroundContextReader.context(for: foregroundApp)
            }
            Task { @MainActor [audioCapture, whisperContext, postProcessBackend, profileStore, vocabularyStore, historyStore, appStatus] in
                let samples = await audioCapture.stop()
                let duration = Double(samples.count) / audioCapture.targetSampleRate
                guard let whisperContext else {
                    print(String(format: "Flow: captured %.1fs of audio but no whisper model loaded", duration))
                    appStatus.flashError("No whisper model loaded")
                    return
                }
                let start = Date()
                let rawText = await whisperContext.transcribe(
                    samples: samples, initialPrompt: vocabularyStore.initialPromptText
                )
                let elapsed = Date().timeIntervalSince(start)
                print(String(format: "Flow: %.1fs audio -> transcribed in %.2fs: \"%@\"", duration, elapsed, rawText))
                guard !rawText.isEmpty else { return }

                // fall back to raw text on any failure
                let foreground = await contextTask.value
                let resolution = profileStore.resolveProfile(
                    bundleID: foreground.bundleID, url: foreground.urlText, title: foreground.windowTitle
                )
                let profile = resolution.profile
                let routing = resolution.rule.map { "rule \"\($0.label)\"" } ?? "default"
                print("Flow: context app=\(foreground.bundleID ?? "?") url=\(foreground.urlText ?? "-") title=\"\(foreground.windowTitle ?? "-")\" -> profile \(profile.name) (\(routing))")
                appStatus.setLastRouting("\(profile.name) — \(resolution.rule?.label ?? "default profile")")
                var finalText = rawText
                var wasPostProcessed = false
                do {
                    let llmStart = Date()
                    let candidate = try await postProcessBackend.process(
                        transcript: rawText, profile: profile, vocabulary: vocabularyStore.terms.map(\.term)
                    )
                    let llmElapsed = Date().timeIntervalSince(llmStart)
                    if HallucinationGuard.looksFabricated(raw: rawText, final: candidate) {
                        // output way longer than input = made up
                        print(String(format: "Flow: post-processed (%@) in %.2fs looked fabricated, discarding: \"%@\"", profile.name, llmElapsed, candidate))
                        appStatus.flashError("Cleanup looked fabricated — used raw text")
                    } else {
                        finalText = candidate
                        wasPostProcessed = true
                        print(String(format: "Flow: post-processed (%@) in %.2fs: \"%@\"", profile.name, llmElapsed, finalText))
                    }
                } catch PostProcessingError.missingAPIKey {
                    print("Flow: no Anthropic API key set — inserting raw transcript")
                    appStatus.flashError("No API key — add it in Settings")
                } catch PostProcessingError.invalidAPIKey {
                    print("Flow: Anthropic API key rejected — inserting raw transcript")
                    appStatus.flashError("API key rejected — check Settings")
                } catch {
                    print("Flow: post-processing unavailable (\(error)) — inserting raw transcript")
                    appStatus.flashError("Cleanup unavailable — used raw text")
                }

                historyStore.record(DictationRecord(
                    rawText: rawText,
                    finalText: finalText,
                    profileName: profile.name,
                    audioDuration: duration,
                    wasPostProcessed: wasPostProcessed,
                    appBundleID: foreground.bundleID,
                    appName: foreground.appName,
                    siteHost: foreground.siteHost
                ))

                do {
                    try TextInserter.insert(finalText)
                } catch {
                    print("Flow: could not insert text (\(error)) — focused field may be a secure/password field")
                    appStatus.flashError("Couldn't insert text (secure field?)")
                }
            }

        case .discardRecording:
            appStatus.setDictationState(.idle)
            waveformPanel.hide()
            Task { @MainActor [audioCapture] in
                await audioCapture.discard()
                print("Flow: quick tap with no follow-up — discarded")
            }

        case .scheduleTimeout:
            break // FNKeyMonitor handles it
        }
    }
}
