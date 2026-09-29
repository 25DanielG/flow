import AVFoundation
import CoreAudio

public struct AudioInputDevice: Identifiable, Sendable, Equatable {
    public let id: AudioDeviceID
    public let uid: String
    public let name: String
    public let isBluetooth: Bool
    public let isBuiltIn: Bool
}

public enum AudioInputDevices {
    public static func all() -> [AudioInputDevice] {
        var address = AudioObjectPropertyAddress(
            mSelector: kAudioHardwarePropertyDevices,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )
        var size: UInt32 = 0
        guard AudioObjectGetPropertyDataSize(AudioObjectID(kAudioObjectSystemObject), &address, 0, nil, &size) == noErr
        else { return [] }
        var ids = [AudioDeviceID](repeating: 0, count: Int(size) / MemoryLayout<AudioDeviceID>.size)
        guard AudioObjectGetPropertyData(AudioObjectID(kAudioObjectSystemObject), &address, 0, nil, &size, &ids) == noErr
        else { return [] }
        return ids.compactMap(device(for:))
    }

    public static func defaultInput() -> AudioInputDevice? {
        var address = AudioObjectPropertyAddress(
            mSelector: kAudioHardwarePropertyDefaultInputDevice,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )
        var id = AudioDeviceID(0)
        var size = UInt32(MemoryLayout<AudioDeviceID>.size)
        guard AudioObjectGetPropertyData(AudioObjectID(kAudioObjectSystemObject), &address, 0, nil, &size, &id) == noErr,
              id != 0
        else { return nil }
        return device(for: id)
    }

    private static func device(for id: AudioDeviceID) -> AudioInputDevice? {
        guard inputChannelCount(id) > 0,
              let uid = stringProperty(id, kAudioDevicePropertyDeviceUID),
              let name = stringProperty(id, kAudioObjectPropertyName)
        else { return nil }
        var address = AudioObjectPropertyAddress(
            mSelector: kAudioDevicePropertyTransportType,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )
        var transport: UInt32 = 0
        var size = UInt32(MemoryLayout<UInt32>.size)
        AudioObjectGetPropertyData(id, &address, 0, nil, &size, &transport)
        return AudioInputDevice(
            id: id, uid: uid, name: name,
            isBluetooth: transport == kAudioDeviceTransportTypeBluetooth
                || transport == kAudioDeviceTransportTypeBluetoothLE,
            isBuiltIn: transport == kAudioDeviceTransportTypeBuiltIn
        )
    }

    private static func inputChannelCount(_ id: AudioDeviceID) -> Int {
        var address = AudioObjectPropertyAddress(
            mSelector: kAudioDevicePropertyStreamConfiguration,
            mScope: kAudioObjectPropertyScopeInput,
            mElement: kAudioObjectPropertyElementMain
        )
        var size: UInt32 = 0
        guard AudioObjectGetPropertyDataSize(id, &address, 0, nil, &size) == noErr, size > 0 else { return 0 }
        let raw = UnsafeMutableRawPointer.allocate(byteCount: Int(size), alignment: MemoryLayout<AudioBufferList>.alignment)
        defer { raw.deallocate() }
        guard AudioObjectGetPropertyData(id, &address, 0, nil, &size, raw) == noErr else { return 0 }
        let list = UnsafeMutableAudioBufferListPointer(raw.assumingMemoryBound(to: AudioBufferList.self))
        return list.reduce(0) { $0 + Int($1.mNumberChannels) }
    }

    private static func stringProperty(_ id: AudioDeviceID, _ selector: AudioObjectPropertySelector) -> String? {
        var address = AudioObjectPropertyAddress(
            mSelector: selector,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )
        var value: Unmanaged<CFString>?
        var size = UInt32(MemoryLayout<Unmanaged<CFString>?>.size)
        guard AudioObjectGetPropertyData(id, &address, 0, nil, &size, &value) == noErr, let value else { return nil }
        return value.takeRetainedValue() as String
    }
}

// opening a bluetooth mic drops airpods from A2DP to HFP, so use built-in mic instead
public enum MicrophonePreference {
    public static let automatic = "auto"
    public static let systemDefault = "default"

    private static let key = "flow.microphone"

    public static var current: String {
        UserDefaults.standard.string(forKey: key) ?? automatic
    }

    public static func set(_ value: String) {
        UserDefaults.standard.set(value, forKey: key)
    }

    public static func resolve() -> (device: AudioInputDevice?, reason: String) {
        let choice = current
        switch choice {
        case systemDefault:
            return (nil, "system default")
        case automatic:
            guard let defaultInput = AudioInputDevices.defaultInput(), defaultInput.isBluetooth,
                  let builtIn = AudioInputDevices.all().first(where: \.isBuiltIn)
            else { return (nil, "automatic: default input isn't Bluetooth") }
            return (builtIn, "automatic: default input '\(defaultInput.name)' is Bluetooth")
        default:
            if let device = AudioInputDevices.all().first(where: { $0.uid == choice }) {
                return (device, "chosen in menu")
            }
            return (nil, "chosen microphone not connected, using system default")
        }
    }
}
