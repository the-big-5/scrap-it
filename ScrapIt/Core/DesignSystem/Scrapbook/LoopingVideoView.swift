import AVFoundation
import SwiftUI
import UIKit

/// Loops a Live Photo movie without sound (POC). When `isPlaying` is off the player is released and the
/// view turns transparent, so the still photo underneath shows.
struct LoopingVideoView: UIViewRepresentable {
    let url: URL
    let isPlaying: Bool

    func makeUIView(context: Context) -> LoopingPlayerUIView {
        LoopingPlayerUIView()
    }

    func updateUIView(_ uiView: LoopingPlayerUIView, context: Context) {
        if isPlaying {
            uiView.play(url)
        } else {
            uiView.stop()
        }
    }

    static func dismantleUIView(_ uiView: LoopingPlayerUIView, coordinator: ()) {
        uiView.stop()
    }
}

final class LoopingPlayerUIView: UIView {
    override class var layerClass: AnyClass { AVPlayerLayer.self }

    private var playerLayer: AVPlayerLayer { layer as! AVPlayerLayer }
    private var player: AVQueuePlayer?
    private var looper: AVPlayerLooper?
    private var readyObservation: NSKeyValueObservation?
    private var currentURL: URL?

    init() {
        super.init(frame: .zero)
        isUserInteractionEnabled = false
        backgroundColor = .clear
        alpha = 0
        playerLayer.videoGravity = .resizeAspectFill
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func play(_ url: URL) {
        if let player, currentURL == url {
            player.play()
            return
        }
        stop()

        // Muted loops must not stop other apps' music (change 023): `.ambient` mixes with them.
        try? AVAudioSession.sharedInstance().setCategory(.ambient)
        let player = AVQueuePlayer()
        player.isMuted = true
        player.preventsDisplaySleepDuringVideoPlayback = false
        looper = AVPlayerLooper(player: player, templateItem: AVPlayerItem(url: url))
        playerLayer.player = player
        // Shown once the first frame is ready, so there is no black flash.
        readyObservation = playerLayer.observe(\.isReadyForDisplay, options: [.initial, .new]) { [weak self] layer, _ in
            guard layer.isReadyForDisplay else { return }
            DispatchQueue.main.async {
                UIView.animate(withDuration: 0.2) { self?.alpha = 1 }
            }
        }
        player.play()
        self.player = player
        currentURL = url
    }

    func stop() {
        guard player != nil else { return }
        readyObservation = nil
        player?.pause()
        looper?.disableLooping()
        looper = nil
        playerLayer.player = nil
        player = nil
        currentURL = nil
        alpha = 0
    }
}
