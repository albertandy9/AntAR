//
//  ARExperienceViewModel.swift
//  AntAR
//

import Foundation
import Observation
import RealityKit
import SwiftUI

/// App-facing bridge for scene setup and the AR session.
///
/// It never decides story progression. SwiftUI and future interaction adapters call
/// `report(_:)`; the event queue and `GameStateMachineSystem` decide whether the event is valid.
@MainActor
@Observable
final class ARExperienceViewModel {
    var gameState: GameState = .scanningTable

    private let experienceRoot = AnchorEntity(world: .zero)
    private let scannedTable = AnchorEntity(
        .plane(.horizontal, classification: .table, minimumBounds: SIMD2<Float>(repeating: 0.25))
    )
    private let gameDirector = Entity()
    private var trackingSession: SpatialTrackingSession?
    private var hasAddedScene = false
    @ObservationIgnored
    nonisolated(unsafe) private var stateObserver: NSObjectProtocol?

    init() {
        AntARECSRegistry.register()

        experienceRoot.name = "ARSceneRoot"
        scannedTable.name = "ScannedSurface"
        scannedTable.components.set(SurfaceAnchorComponent())

        gameDirector.name = "GameDirector"
        gameDirector.components.set(GameDirectorComponent())
        gameDirector.components.set(GameStateComponent())
        gameDirector.components.set(GameEventComponent())
        experienceRoot.addChild(gameDirector)

        stateObserver = NotificationCenter.default.addObserver(
            forName: .gameStateDidChange,
            object: gameDirector,
            queue: .main
        ) { [weak self] notification in
            guard let rawValue = notification.userInfo?[GameStateNotificationKey.current] as? String,
                  let state = GameState(rawValue: rawValue) else {
                return
            }

            Task { @MainActor [weak self] in
                self?.gameState = state
            }
        }
    }

    deinit {
        if let stateObserver {
            NotificationCenter.default.removeObserver(stateObserver)
        }
    }

    func setUpScene(in content: RealityViewCameraContent) {
        guard !hasAddedScene else { return }
        content.add(experienceRoot)
        content.add(scannedTable)
        hasAddedScene = true
    }

    func startTracking() async {
        let session = SpatialTrackingSession()
        let configuration = SpatialTrackingSession.Configuration(
            tracking: [.plane],
            camera: .back
        )

        _ = await session.run(configuration)
        trackingSession = session
    }

    /// Entry point for future systems/adapters that are not themselves RealityKit systems.
    func report(_ event: GameEvent) {
        guard var events = gameDirector.components[GameEventComponent.self] else { return }
        events.enqueue(event)
        gameDirector.components[GameEventComponent.self] = events
    }
}
