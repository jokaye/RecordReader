import AVFoundation
import Combine
import Foundation
import RecordReaderCore

@MainActor
final class PlayerController: NSObject, ObservableObject, AVAudioPlayerDelegate {
    @Published private(set) var isPlaying = false
    @Published private(set) var currentTime: TimeInterval = 0
    @Published private(set) var duration: TimeInterval = 0
    @Published private(set) var errorMessage: String?
    @Published private(set) var speed: PlaybackSpeed = .default
    var onFinish: (() -> Void)?

    private var player: AVAudioPlayer?
    private var timer: Timer?
    private var scopedURL: URL?
    private var hasSecurityScope = false
    private var loadedURL: URL?

    var progress: Double {
        guard duration > 0 else {
            return 0
        }
        return min(max(currentTime / duration, 0), 1)
    }

    var currentTimeLabel: String {
        Self.format(currentTime)
    }

    var durationLabel: String {
        Self.format(duration)
    }

    func load(url: URL) {
        if loadedURL == url, player != nil {
            return
        }

        stopTimer()
        releaseSecurityScope()
        scopedURL = url
        hasSecurityScope = url.startAccessingSecurityScopedResource()

        do {
            try AVAudioSession.sharedInstance().setCategory(.playback, mode: .spokenAudio)
            try AVAudioSession.sharedInstance().setActive(true)
            let nextPlayer = try AVAudioPlayer(contentsOf: url)
            nextPlayer.delegate = self
            nextPlayer.volume = 1.0
            nextPlayer.enableRate = true
            nextPlayer.rate = speed.rate
            guard nextPlayer.prepareToPlay(), nextPlayer.duration.isFinite, nextPlayer.duration > 0 else {
                throw PlayerControllerError.unplayableAudio
            }
            player = nextPlayer
            loadedURL = url
            currentTime = 0
            duration = nextPlayer.duration
            isPlaying = false
            errorMessage = nil
            DebugLog.shared.log("已加载录音 \(url.lastPathComponent)，时长 \(Int(nextPlayer.duration))s")
        } catch {
            player = nil
            loadedURL = nil
            currentTime = 0
            duration = 0
            isPlaying = false
            errorMessage = "无法加载这段录音：\(error.localizedDescription)"
            DebugLog.shared.log("加载录音失败 \(url.lastPathComponent)：\(error.localizedDescription)")
        }
    }

    func playPause() {
        guard let player else {
            errorMessage = "请先选择一段录音再播放。"
            return
        }

        if player.isPlaying {
            player.pause()
            isPlaying = false
            stopTimer()
        } else {
            play()
        }
    }

    func play() {
        guard let player else {
            errorMessage = "请先选择一段录音再播放。"
            return
        }
        guard player.play() else {
            isPlaying = false
            stopTimer()
            errorMessage = "无法开始播放这段录音。请确认文件仍可访问，并检查手机音量或重新导入。"
            return
        }
        player.rate = speed.rate
        errorMessage = nil
        isPlaying = true
        startTimer()
    }

    func cycleSpeed() {
        speed = speed.next()
        if let player {
            player.enableRate = true
            player.rate = speed.rate
            if !player.isPlaying {
                player.pause()
            }
        }
    }

    func seek(by delta: TimeInterval) {
        guard let player else {
            return
        }
        player.currentTime = min(max(player.currentTime + delta, 0), player.duration)
        currentTime = player.currentTime
    }

    func seek(toProgress progress: Double) {
        guard let player, player.duration > 0 else {
            return
        }
        let clampedProgress = min(max(progress, 0), 1)
        player.currentTime = player.duration * clampedProgress
        currentTime = player.currentTime
    }

    nonisolated func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
        let finishedDuration = player.duration
        Task { @MainActor in
            self.isPlaying = false
            self.currentTime = finishedDuration
            self.stopTimer()
            self.onFinish?()
        }
    }

    private func startTimer() {
        stopTimer()
        timer = Timer.scheduledTimer(withTimeInterval: 0.3, repeats: true) { [weak self] _ in
            self?.syncPlaybackState()
        }
    }

    private func syncPlaybackState() {
        guard let player else {
            return
        }
        currentTime = player.currentTime
        isPlaying = player.isPlaying
    }

    private func stopTimer() {
        timer?.invalidate()
        timer = nil
    }

    private func releaseSecurityScope() {
        if hasSecurityScope {
            scopedURL?.stopAccessingSecurityScopedResource()
            hasSecurityScope = false
        }
    }

    private static func format(_ value: TimeInterval) -> String {
        guard value.isFinite else {
            return "0:00"
        }
        let totalSeconds = max(0, Int(value.rounded()))
        return String(format: "%d:%02d", totalSeconds / 60, totalSeconds % 60)
    }
}

private enum PlayerControllerError: Error, LocalizedError {
    case unplayableAudio

    var errorDescription: String? {
        "这段录音无法准备播放。请确认文件是有效音频，并重新从文件夹或音频文件导入。"
    }
}
