//
//  BrightnessManager.swift
//  KikoNotchKit
//
//  DisplayServices display brightness manager based on Boring Notch foundation.
//

import AppKit
import Combine
import Foundation

@MainActor
public final class BrightnessManager: ObservableObject {
    public static let shared = BrightnessManager()

    @Published public private(set) var rawBrightness: Float = 0.8
    @Published public private(set) var isSupported: Bool = true
    @Published public private(set) var lastChangeAt: Date = .distantPast

    private init() {
        refresh()
    }

    public func refresh() {
        let displayID = mainDisplayID()
        var current: Float = 0
        if displayServicesGetBrightness(displayID: displayID, out: &current) {
            isSupported = true
            rawBrightness = max(0, min(1, current))
        } else {
            // Try IODisplayConnect fallback if available, or mark unsupported
            isSupported = checkDisplaySupported(displayID: displayID)
        }
    }

    public func setRelative(delta: Float) {
        let target = max(0, min(1, rawBrightness + delta))
        setAbsolute(value: target)
    }

    public func setAbsolute(value: Float) {
        let clamped = max(0, min(1, value))
        let displayID = mainDisplayID()
        if displayServicesSetBrightness(displayID: displayID, value: clamped) {
            isSupported = true
            rawBrightness = clamped
            lastChangeAt = Date()
        } else {
            // External monitor or unsupported
            refresh()
        }
    }

    // MARK: - Private DisplayServices Dynamic Binding

    private func mainDisplayID() -> CGDirectDisplayID {
        return CGMainDisplayID()
    }

    private func checkDisplaySupported(displayID: CGDirectDisplayID) -> Bool {
        var test: Float = 0
        return displayServicesGetBrightness(displayID: displayID, out: &test)
    }

    private func displayServicesGetBrightness(displayID: CGDirectDisplayID, out: inout Float) -> Bool {
        guard let handle = DisplayServicesHandle.handle,
              let sym = dlsym(handle, "DisplayServicesGetBrightness") else {
            return false
        }
        typealias Fn = @convention(c) (CGDirectDisplayID, UnsafeMutablePointer<Float>) -> Int32
        let fn = unsafeBitCast(sym, to: Fn.self)
        var tmp: Float = 0
        let r = fn(displayID, &tmp)
        if r == 0 {
            out = tmp
            return true
        }
        return false
    }

    private func displayServicesSetBrightness(displayID: CGDirectDisplayID, value: Float) -> Bool {
        guard let handle = DisplayServicesHandle.handle,
              let sym = dlsym(handle, "DisplayServicesSetBrightness") else {
            return false
        }
        typealias Fn = @convention(c) (CGDirectDisplayID, Float) -> Int32
        let fn = unsafeBitCast(sym, to: Fn.self)
        return fn(displayID, value) == 0
    }

    private enum DisplayServicesHandle {
        static let handle: UnsafeMutableRawPointer? = {
            let paths = [
                "/System/Library/PrivateFrameworks/DisplayServices.framework/DisplayServices",
                "/System/Library/PrivateFrameworks/DisplayServices.framework/Versions/Current/DisplayServices"
            ]
            for p in paths {
                if let h = dlopen(p, RTLD_LAZY) {
                    return h
                }
            }
            return nil
        }()
    }
}
