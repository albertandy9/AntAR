//
//  ExperienceFeedback.swift
//  AntAR
//
//  Centralized app feedback. Game-state and ECS transitions decide *when* feedback happens;
//  this service only owns reusable audio players and main-thread haptic generators.
//

import AVFoundation
import UIKit

enum ExperienceSound: Hashable {
    case backgroundMusic
    case blockPickedUp
    case blockPlaced
    case button
    case levelCompleted
    case antTalking
    case antBoardsUFO
    case ufoCannotMove
    case ufoMoving
    case ufoDescends
    case ufoAscends
    case ufoTurn

    fileprivate var resource: (name: String, extension: String) {
        switch self {
        case .backgroundMusic: ("background-musik", "mp3")
        case .blockPickedUp: ("balok-diambil", "wav")
        case .blockPlaced: ("balok-ditaro", "wav")
        case .button: ("button", "wav")
        case .levelCompleted: ("berhasil", "wav")
        case .antTalking: ("semut-ngomong-diawal", "mp3")
        case .antBoardsUFO: ("semut-naik-ke-ufo", "wav")
        case .ufoCannotMove: ("ufo-gabisa-jalan", "wav")
        case .ufoMoving: ("ufo-gerak", "wav")
        case .ufoDescends: ("ufo-turun", "mp3")
        // The latest supplied ascent-transition recording currently uses this filename.
        case .ufoAscends: ("ufo-turun", "mp3")
        case .ufoTurn: ("ufo-turn", "wav")
        }
    }
}

@MainActor
final class ExperienceFeedback {
    static let shared = ExperienceFeedback()

    private var backgroundPlayer: AVAudioPlayer?
    private var movementPlayer: AVAudioPlayer?
    private var effectPlayers: [ExperienceSound: AVAudioPlayer] = [:]
    private var isUFOMoving = false

    private init() {
        configureAudioSession()
    }

    func startBackgroundMusic() {
        guard backgroundPlayer?.isPlaying != true,
              let player = makePlayer(for: .backgroundMusic) else {
            return
        }
        player.numberOfLoops = -1
        player.volume = 0.28
        player.prepareToPlay()
        player.play()
        backgroundPlayer = player
    }

    func play(_ sound: ExperienceSound) {
        guard sound != .backgroundMusic, sound != .ufoMoving,
              let player = makePlayer(for: sound) else {
            return
        }
        player.volume = 0.88
        player.prepareToPlay()
        player.play()
        effectPlayers[sound] = player
    }

    func stop(_ sound: ExperienceSound) {
        if sound == .ufoMoving {
            setUFOMoving(false)
            return
        }
        effectPlayers[sound]?.stop()
        effectPlayers[sound] = nil
    }

    /// The movement clip is stateful so a 20 Hz telemetry refresh never restarts it every frame.
    func setUFOMoving(_ moving: Bool) {
        guard moving != isUFOMoving else { return }
        isUFOMoving = moving

        if moving {
            guard let player = makePlayer(for: .ufoMoving) else { return }
            player.numberOfLoops = -1
            player.volume = 0.62
            player.prepareToPlay()
            player.play()
            movementPlayer = player
        } else {
            movementPlayer?.stop()
            movementPlayer = nil
        }
    }

    func impact(_ style: UIImpactFeedbackGenerator.FeedbackStyle = .light, intensity: CGFloat = 1) {
        let generator = UIImpactFeedbackGenerator(style: style)
        generator.prepare()
        generator.impactOccurred(intensity: intensity)
    }

    func success() {
        let generator = UINotificationFeedbackGenerator()
        generator.prepare()
        generator.notificationOccurred(.success)
    }

    func failure() {
        let generator = UINotificationFeedbackGenerator()
        generator.prepare()
        generator.notificationOccurred(.error)
    }

    private func configureAudioSession() {
        let session = AVAudioSession.sharedInstance()
        try? session.setCategory(.ambient, mode: .default, options: [.mixWithOthers])
        try? session.setActive(true)
    }

    private func makePlayer(for sound: ExperienceSound) -> AVAudioPlayer? {
        let resource = sound.resource
        let url = Bundle.main.url(
            forResource: resource.name,
            withExtension: resource.extension,
            subdirectory: "Sounds"
        ) ?? Bundle.main.url(forResource: resource.name, withExtension: resource.extension)

        guard let url else {
            assertionFailure("Missing sound asset: \(resource.name).\(resource.extension)")
            return nil
        }
        return try? AVAudioPlayer(contentsOf: url)
    }
}
