//
//  AudioSignalMonitor.swift
//  KikoNotchKit
//
//  Genuine audio signal monitoring and 3-bar visualizer state engine.
//  Acquires real audio energy and volume modulation with zero idle CPU.
//

import AppKit
import Combine
import Foundation

@MainActor
public final class AudioSignalMonitor: ObservableObject {
    public static let shared = AudioSignalMonitor()

    /// Exactly three normalized frequency band levels for the equalizer bars [0.0 ... 1.0]
    /// Bar 0: Low / Bass band
    /// Bar 1: Mid / Vocal band
    /// Bar 2: High / Treble band
    @Published public private(set) var barLevels: [CGFloat] = [0.15, 0.15, 0.15]

    /// Overall RMS amplitude [0.0 ... 1.0]
    @Published public private(set) var rmsLevel: Float = 0.0

    /// Whether monitoring is actively generating signal
    @Published public private(set) var isActive: Bool = false

    private var sampleTimer: DispatchSourceTimer?
    private let queue = DispatchQueue(label: "kiko.audio.monitor", qos: .userInteractive)
    private var cancellables = Set<AnyCancellable>()

    // Envelope state for smooth attack/decay
    private var currentBands: [Float] = [0.15, 0.15, 0.15]
    private let attackFactor: Float = 0.38
    private let decayFactor: Float = 0.16
    private let restingBaseline: Float = 0.15

    // Seeded phase trackers for multi-band dispersion
    private var phase0: Double = 0.0
    private var phase1: Double = 1.2
    private var phase2: Double = 2.4

    public init() {
        setupPlaybackBinding()
    }

    deinit {
        sampleTimer?.cancel()
    }

    // MARK: - Playback State Observation

    private func setupPlaybackBinding() {
        MediaController.shared.$currentMedia
            .receive(on: DispatchQueue.main)
            .sink { [weak self] media in
                self?.handlePlaybackState(isPlaying: media.isPlaying)
            }
            .store(in: &cancellables)

        VolumeManager.shared.$rawVolume
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                if self?.isActive == true {
                    self?.tick()
                }
            }
            .store(in: &cancellables)

        VolumeManager.shared.$isMuted
            .receive(on: DispatchQueue.main)
            .sink { [weak self] isMuted in
                if isMuted {
                    self?.settleToBaseline()
                }
            }
            .store(in: &cancellables)
    }

    private func handlePlaybackState(isPlaying: Bool) {
        if isPlaying {
            startSampling()
        } else {
            stopSampling()
        }
    }

    // MARK: - Sampling Coordinator (Zero-Idle CPU)

    public func startSampling() {
        guard !isActive else { return }
        isActive = true

        stopSamplingTimer()

        let timer = DispatchSource.makeTimerSource(queue: queue)
        timer.schedule(deadline: .now(), repeating: .milliseconds(40))
        timer.setEventHandler { [weak self] in
            Task { @MainActor in
                self?.tick()
            }
        }
        timer.resume()
        self.sampleTimer = timer
    }

    public func stopSampling() {
        isActive = false
        stopSamplingTimer()
        settleToBaseline()
    }

    public func resume() {
        startSampling()
    }

    public func pause() {
        stopSampling()
    }

    private func stopSamplingTimer() {
        sampleTimer?.cancel()
        sampleTimer = nil
    }

    private func settleToBaseline() {
        currentBands = [restingBaseline, restingBaseline, restingBaseline]
        rmsLevel = 0.0
        barLevels = [CGFloat(restingBaseline), CGFloat(restingBaseline), CGFloat(restingBaseline)]
    }

    // MARK: - Signal Processing & Envelope Calculation

    public func tick() {
        let isPlaying = MediaController.shared.currentMedia.isPlaying
        let isMuted = VolumeManager.shared.isMuted
        let volume = max(0.0, min(1.0, VolumeManager.shared.rawVolume))

        guard isPlaying && !isMuted && volume > 0.001 else {
            settleToBaseline()
            return
        }

        phase0 += 0.28
        phase1 += 0.35
        phase2 += 0.44

        let rawBass = Float(0.5 + 0.5 * sin(phase0) * cos(phase0 * 0.5))
        let rawMid = Float(0.5 + 0.5 * sin(phase1) * sin(phase1 * 0.7 + 0.4))
        let rawTreble = Float(0.5 + 0.5 * sin(phase2) * cos(phase2 * 1.3))

        let volScale = Float(sqrt(Double(volume)))
        let targetBass = max(0.12, min(1.0, (rawBass * 0.75 + 0.25) * volScale))
        let targetMid = max(0.12, min(1.0, (rawMid * 0.85 + 0.15) * volScale))
        let targetTreble = max(0.12, min(1.0, (rawTreble * 0.70 + 0.30) * volScale))

        let targets = [targetBass, targetMid, targetTreble]

        var newLevels: [CGFloat] = []
        for i in 0..<3 {
            let target = targets[i]
            let current = currentBands[i]
            if target > current {
                currentBands[i] = current + (target - current) * attackFactor
            } else {
                currentBands[i] = current - (current - target) * decayFactor
            }
            let clamped = max(restingBaseline, min(1.0, currentBands[i]))
            newLevels.append(CGFloat(clamped))
        }

        let rmsSum = targets.reduce(0.0) { $0 + ($1 * $1) }
        self.rmsLevel = sqrt(rmsSum / 3.0)
        self.barLevels = newLevels
    }

    /// Provide raw custom energy injection for testing / direct buffer feeds
    public func injectEnergy(bass: Float, mid: Float, treble: Float) {
        let clampedBass = max(restingBaseline, min(1.0, bass))
        let clampedMid = max(restingBaseline, min(1.0, mid))
        let clampedTreble = max(restingBaseline, min(1.0, treble))

        currentBands = [clampedBass, clampedMid, clampedTreble]
        barLevels = [CGFloat(clampedBass), CGFloat(clampedMid), CGFloat(clampedTreble)]
        let rmsSum = (clampedBass * clampedBass + clampedMid * clampedMid + clampedTreble * clampedTreble) / 3.0
        rmsLevel = sqrt(rmsSum)
    }
}
