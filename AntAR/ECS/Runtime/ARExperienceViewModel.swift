//
//  ARExperienceViewModel.swift
//  AntAR
//

import ARKit
import Foundation
import Observation
import RealityKit
import RealityKitContent

/// App-facing bridge for the focused UFO-travel AR slice and its user-selected AR anchor.
@MainActor
@Observable
final class ARExperienceViewModel {
    var gameState: GameState = .scanningTable
    var placementStatus: ARPlacementStatus = .loadingScene
    var sensorCount = 2
    var isSecondTileLight = false
    var irLineActivations: [Float] = Array(repeating: 0, count: 2)
    var isIRLineDetected = false
    var irLinePosition: Float = 0
    var leftMotorPower: Float = 0
    var rightMotorPower: Float = 0
    var isGasPedalPressed = false

    /// The one scene root: the game director and authored RC Pro scene are attached to one anchor
    /// made from the user's tap raycast result.
    private let tableContentRoot = Entity()
    private let gameDirector = Entity()
    private weak var arView: ARView?
    private var placementAnchor: AnchorEntity?
    private var isAuthoredSceneReady = false
    private var hasRequestedAuthoredScene = false
    @ObservationIgnored
    nonisolated(unsafe) private var stateObserver: NSObjectProtocol?
    @ObservationIgnored
    nonisolated(unsafe) private var telemetryTimer: Timer?

    init() {
        AntARECSRegistry.register()

        tableContentRoot.name = "ARSceneRoot"

        gameDirector.name = "GameDirector"
        gameDirector.components.set(GameDirectorComponent())
        gameDirector.components.set(GameStateComponent())
        gameDirector.components.set(GameEventComponent())
        gameDirector.components.set(UFOControlComponent())
        tableContentRoot.addChild(gameDirector)

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
                if state == .ufoTravelling {
                    self?.requestUFOTravel()
                }
            }
        }
    }

    deinit {
        if let stateObserver {
            NotificationCenter.default.removeObserver(stateObserver)
        }
        telemetryTimer?.invalidate()
    }

    func setUpScene(in arView: ARView) {
        self.arView = arView
        guard !hasRequestedAuthoredScene else { return }
        hasRequestedAuthoredScene = true
        Task { [weak self] in
            await self?.loadAuthoredScene()
        }
    }

    /// Creates the one scene anchor at the user's chosen point on a detected horizontal plane.
    /// A second tap deliberately does nothing so the learned route cannot move mid-travel.
    func placeScene(at raycastResult: ARRaycastResult, in arView: ARView) {
        guard placementAnchor == nil else { return }
        guard isAuthoredSceneReady else {
            placementStatus = .loadingScene
            return
        }

        let anchor = AnchorEntity(raycastResult: raycastResult)
        anchor.name = "UserSelectedTableAnchor"
        anchor.addChild(tableContentRoot)
        arView.scene.addAnchor(anchor)
        placementAnchor = anchor
        placementStatus = .placed
        startIRTelemetry()
        skipToUFOTravelling()
    }

    func notePlacementNeedsSurface() {
        guard placementAnchor == nil else { return }
        placementStatus = .needsSurface
    }

    /// Entry point for the completion event and any later state-10 interaction adapters.
    func report(_ event: GameEvent) {
        guard var events = gameDirector.components[GameEventComponent.self] else { return }
        events.enqueue(event)
        gameDirector.components[GameEventComponent.self] = events
    }

    /// UI input adapter: the gas pedal writes only the director's ECS control component.
    /// `UFOControlSystem` and `UFOPathFollowingSystem` decide what the machine does with it.
    func setGasPedalPressed(_ pressed: Bool) {
        guard placementAnchor != nil,
              gameState == .ufoTravelling,
              var control = gameDirector.components[UFOControlComponent.self] else {
            return
        }
        guard control.isPedalPressed != pressed else { return }

        control.setThrottle(pressed ? 1 : 0)
        gameDirector.components[UFOControlComponent.self] = control
        isGasPedalPressed = pressed
    }

    /// Queues an ECS reset command. Transform and follower state are reset by `UFOControlSystem`.
    func requestUFOReset() {
        guard placementAnchor != nil,
              var control = gameDirector.components[UFOControlComponent.self] else {
            return
        }

        control.requestReset()
        gameDirector.components[UFOControlComponent.self] = control
        isGasPedalPressed = false
    }

    /// Keeps the canonical state machine intact while this team's build skips story beats 1…9.
    /// Each event is consumed in order by `GameStateMachineSystem`; no code writes state 10
    /// directly. Remove this adapter when the upstream features report these events themselves.
    private func skipToUFOTravelling() {
        [
            GameEvent.surfaceLocked,
            .otherAntsExited,
            .lostAntReachedOrigin,
            .lostAntDialogueDismissed,
            .ufoReachedLostAnt,
            .antBoardedUFO,
            .allRequiredBlocksCollected,
            .requiredPathPlaced,
            .ufoMoveRequested
        ].forEach(report)
    }

    /// Re-arms the same local UFO after a light block has been swapped for a dark one. The global
    /// story remains in `.ufoTravelling`; a retry must not skip or duplicate a game state.
    func retryUFOTravel() {
        guard let ufo = tableContentRoot.antarDescendant(named: AntARSceneNames.travelUFO),
              var follower = ufo.components[UFOPathFollowerComponent.self],
              follower.state == .stalled else {
            return
        }

        follower.state = .idle
        follower.stallReason = nil
        follower.moveRequested = true
        ufo.components[UFOPathFollowerComponent.self] = follower
    }

    /// Starts the local follower once the canonical event chain has entered state 10.
    func requestUFOTravel() {
        guard placementAnchor != nil,
              gameState == .ufoTravelling,
              let ufo = tableContentRoot.antarDescendant(named: AntARSceneNames.travelUFO),
              var follower = ufo.components[UFOPathFollowerComponent.self],
              follower.state == .idle else {
            return
        }

        follower.moveRequested = true
        ufo.components[UFOPathFollowerComponent.self] = follower
    }

    /// Changes the second authored path tile between the two PRD teaching materials. A light
    /// tile makes its sensors turn yellow and stops the UFO; changing it back to dark retries.
    func toggleSecondTileIRTest() {
        let material: PathTileMaterial = isSecondTileLight ? .dark : .light
        guard let tile = tableContentRoot.antarDescendant(named: AntARSceneNames.pathTiles[1]) else {
            return
        }

        tile.components[IRReflectanceComponent.self] = material.irMaterial
        PathTileVisualFactory.apply(material, to: tile)
        isSecondTileLight.toggle()

        if material == .dark {
            retryUFOTravel()
        }
    }

    /// Entry point for the future drag/drop placement system. These are the four authored pool
    /// entities from the one RC Pro scene—no Swift-created path world.
    func configurePathTile(
        order: Int,
        atWorldPosition position: SIMD3<Float>,
        material: PathTileMaterial
    ) {
        guard (1...AntARSceneNames.pathTiles.count).contains(order),
              let tile = tableContentRoot.antarDescendant(named: AntARSceneNames.pathTiles[order - 1]),
              var pathTile = tile.components[PathTileComponent.self] else {
            return
        }

        pathTile.isPlaced = true
        tile.components[PathTileComponent.self] = pathTile
        tile.components[IRReflectanceComponent.self] = material.irMaterial
        PathTileVisualFactory.apply(material, to: tile)
        tile.setPosition(position, relativeTo: nil)
        tile.isEnabled = true
    }

    /// Rebuilds only the dynamic sensor/beam children on the scene-authored travel UFO. This is
    /// safe to call from the future IR control UI whenever the learner changes the sensor count.
    func setIRSensorCount(_ requestedCount: Int) {
        guard let ufo = tableContentRoot.antarDescendant(named: AntARSceneNames.travelUFO),
              var follower = ufo.components[UFOPathFollowerComponent.self] else {
            return
        }

        let count = min(max(requestedCount, IRSensorLayout.minimumCount), IRSensorLayout.maximumCount)
        sensorCount = count
        irLineActivations = Array(repeating: 0, count: count)
        follower.sensorCount = count
        ufo.components[UFOPathFollowerComponent.self] = follower
        ufo.components[IRSensorArrayComponent.self] = IRSensorArrayComponent(sensorCount: count)
        IRSensorFactory.rebuildSensors(on: ufo, sensorCount: count)
    }

    private func startIRTelemetry() {
        guard telemetryTimer == nil else { return }

        let timer = Timer(timeInterval: 0.06, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.refreshIRTelemetry()
            }
        }
        RunLoop.main.add(timer, forMode: .common)
        telemetryTimer = timer
        refreshIRTelemetry()
    }

    private func refreshIRTelemetry() {
        guard let ufo = tableContentRoot.antarDescendant(named: AntARSceneNames.travelUFO),
              let readings = ufo.components[IRSensorArrayComponent.self],
              let follower = ufo.components[UFOPathFollowerComponent.self] else {
            return
        }

        irLineActivations = readings.lineSignals.map { min(max($0, 0), 1) }
        let decision = IRLineFollowingPolicy.decide(lineSignals: readings.lineSignals)
        isIRLineDetected = decision.hasLine
        irLinePosition = decision.lateralCorrection
        leftMotorPower = follower.leftMotorPower
        rightMotorPower = follower.rightMotorPower
        if let control = gameDirector.components[UFOControlComponent.self] {
            isGasPedalPressed = control.isPedalPressed
        }
    }

    func removePathTile(order: Int) {
        guard (1...AntARSceneNames.pathTiles.count).contains(order),
              let tile = tableContentRoot.antarDescendant(named: AntARSceneNames.pathTiles[order - 1]),
              var pathTile = tile.components[PathTileComponent.self] else {
            return
        }

        pathTile.isPlaced = false
        tile.components[PathTileComponent.self] = pathTile
        tile.isEnabled = false
    }

    private func loadAuthoredScene() async {
        guard let authoredScene = try? await Entity(named: "Scene", in: realityKitContentBundle) else {
            placementStatus = .failedToLoadScene
            return
        }

        let requiredEntityNames = [
            AntARSceneNames.pickupUFOFinishMarker,
            AntARSceneNames.travelUFO,
            AntARSceneNames.home
        ] + AntARSceneNames.pathTiles
        guard requiredEntityNames.allSatisfy({ authoredScene.antarDescendant(named: $0) != nil }) else {
            placementStatus = .failedSceneContract
            return
        }

        // Do not call this `Root`: the USD asset can contain a root entity named `Root` inside a
        // loader container. Keeping this name unique stops visibility code from accidentally
        // gating the container and hiding the whole authored scene.
        authoredScene.name = "AntARAuthoredSceneContainer"
        tableContentRoot.addChild(authoredScene)
        isAuthoredSceneReady = true
        placementStatus = placementAnchor == nil ? .scanSurface : .placed
    }
}

enum ARPlacementStatus: Equatable {
    case loadingScene
    case scanSurface
    case needsSurface
    case placed
    case failedToLoadScene
    case failedSceneContract

    var prompt: String? {
        switch self {
        case .loadingScene:
            "Memuat scene UFO…"
        case .scanSurface:
            "Arahkan kamera ke meja, lalu ketuk untuk meletakkan UFO"
        case .needsSurface:
            "Permukaan belum terbaca. Gerakkan kamera perlahan di atas meja, lalu ketuk lagi."
        case .placed:
            nil
        case .failedToLoadScene:
            "Scene UFO gagal dimuat. Tutup dan buka ulang aplikasi."
        case .failedSceneContract:
            "Entity scene UFO tidak lengkap. Periksa finish_ufo, ufo_jalan, ant_nest, dan PathTile_1…4."
        }
    }
}
