//
//  ARExperienceViewModel.swift
//  AntAR
//

import Foundation
import Observation
import RealityKit
import RealityKitContent
import SwiftUI
import UIKit


@MainActor
@Observable
final class ARExperienceViewModel {
    var gameState: GameState = .scanningTable
    var isTableReadyToPlace = false
    var isCoachingOverlayActive = true
    private(set) var hasFoundUndersizedTable = false
    var sensorCount = 2
    var irLineActivations: [Float] = Array(repeating: 0, count: 2)
    var isIRLineDetected = false
    var irLinePosition: Float = 0
    var leftMotorPower: Float = 0
    var rightMotorPower: Float = 0
    var isGasPedalPressed = false
    
    private(set) var lostAntGreetPhase: LostAntGreetPhase?
    private(set) var placementAnchor: Entity?
    private(set) var ufoDirection: CGVector?


    private(set) var collectedBlocks: [CollectedBlock] = []

    // Not `private` — ContentView's tap handler needs `scannedTable.isAnchored` and its transform
    // to ray-plane-intersect a 2D tap into a 3D table point (ContentView.intersect(ray:withPlane:)).
    let scannedTable = AnchorEntity(
        .plane(.horizontal, classification: .table, minimumBounds: SIMD2<Float>(repeating: 0.25))
    )

    // Same .table classification as scannedTable, but a much smaller minimumBounds — used only to
    // tell "found a table-shaped surface that's currently too small" apart from "haven't found a
    // table at all." As the user keeps moving the phone over more of the real surface, ARKit
    // extends its estimate of the same underlying plane, so this and scannedTable both track the
    // same real-world plane growing, just anchor at different size thresholds.
    private let looselySizedTable = AnchorEntity(.plane(.horizontal, classification: .table, minimumBounds: SIMD2<Float>(repeating: 0.05)))

    private let cameraAnchor = AnchorEntity(.camera)
    private let experienceRoot = AnchorEntity(world: .zero)
    private let gameDirector = Entity()
    private var hasAddedScene = false
    private var hasPlacedAnchor = false
    private var hasSpawnedUFO = false
    private var hasStartedAntsLeaveFormation = false
    private var hasStartedLostAntGreet = false
    private var hasStartedAntBoarding = false
    private var hasStartedUFOAscend = false
    private var hasSpawnedBlocks = false
    private var hasRevealedEnvironment = false
    private var hasQueuedRequiredPathEvents = false

    private var masterScene: Entity?

    private var masterSceneLoadTask: Task<Void, Never>?
    @ObservationIgnored
    nonisolated(unsafe) private var stateObserver: NSObjectProtocol?
    @ObservationIgnored
    nonisolated(unsafe) private var hapticObserver: NSObjectProtocol?
    @ObservationIgnored
    nonisolated(unsafe) private var lostAntGreetObserver: NSObjectProtocol?

    init() {
        AntARECSRegistry.register()

        experienceRoot.name = "ARSceneRoot"
        scannedTable.name = "ScannedSurface"
        scannedTable.components.set(SurfaceAnchorComponent())

        cameraAnchor.name = "PlayerCamera"
        cameraAnchor.components.set(PlayerCameraComponent())

        gameDirector.name = "GameDirector"
        gameDirector.components.set(GameDirectorComponent())
        gameDirector.components.set(GameStateComponent())
        gameDirector.components.set(GameEventComponent())
        gameDirector.components.set(UFOControlComponent())
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
                if state == .antsLeaveFormation {
                    self?.beginAntsLeaveFormationIfNeeded()
                } else if state == .lostAntDialogue {
                    self?.beginLostAntGreetIfNeeded()
                } else if state == .ufoAppears {
                    self?.spawnUFOIfNeeded()
                } else if state == .antEntersUFO {
                    self?.beginAntBoardingIfNeeded()
                } else if state == .blocksScattered {
                    self?.beginUFOAscendIfNeeded()
                    self?.spawnBlocksIfNeeded()
                } else if state == .ufoTravelling {
                    self?.requestUFOTravel()
                } else if state == .completed {
                    self?.releaseGasPedal()
                    self?.presentCompletedExperience()
                }
            }
        }

        hapticObserver = NotificationCenter.default.addObserver(
            forName: .hapticCueRequested,
            object: nil,
            queue: .main
        ) { notification in
            guard let styleRaw = notification.userInfo?[HapticNotificationKey.style] as? String,
                  let style = HapticStyle(rawValue: styleRaw),
                  let intensity = notification.userInfo?[HapticNotificationKey.intensity] as? Float else {
                return
            }

            let uiKitStyle: UIImpactFeedbackGenerator.FeedbackStyle = switch style {
            case .light: .light
            case .medium: .medium
            case .heavy: .heavy
            case .soft: .soft
            case .rigid: .rigid
            }

            let generator = UIImpactFeedbackGenerator(style: uiKitStyle)
            generator.prepare()
            generator.impactOccurred(intensity: CGFloat(intensity))
        }

        lostAntGreetObserver = NotificationCenter.default.addObserver(
            forName: .lostAntGreetPhaseDidChange,
            object: nil,
            queue: .main
        ) { [weak self] notification in
            guard let rawValue = notification.userInfo?[LostAntGreetNotificationKey.phase] as? String,
                  let phase = LostAntGreetPhase(rawValue: rawValue) else {
                return
            }
            self?.lostAntGreetPhase = phase
        }
    }

    deinit {
        if let stateObserver {
            NotificationCenter.default.removeObserver(stateObserver)
        }
        if let hapticObserver {
            NotificationCenter.default.removeObserver(hapticObserver)
        }
        if let lostAntGreetObserver {
            NotificationCenter.default.removeObserver(lostAntGreetObserver)
        }
    }

    // ARView (in ARViewContainer) owns the ARSession directly now, so this attaches anchors to its
    // RealityKit.Scene via addAnchor(_:) instead of RealityViewCameraContent's add(_:).
    func setUpScene(in scene: RealityKit.Scene) {
        guard !hasAddedScene else { return }
        scene.addAnchor(experienceRoot)
        scene.addAnchor(scannedTable)
        scene.addAnchor(looselySizedTable)
        scene.addAnchor(cameraAnchor)
        hasAddedScene = true
    }


    private var tableScanOverlay: Entity?

    func addTableScanOverlay(_ entity: Entity) {
        experienceRoot.addChild(entity)
        tableScanOverlay = entity
    }

    /// Entry point for future systems/adapters that are not themselves RealityKit systems.
    func report(_ event: GameEvent) {
        guard var events = gameDirector.components[GameEventComponent.self] else { return }
        events.enqueue(event)
        gameDirector.components[GameEventComponent.self] = events
    }


    func refreshSurfaceReadiness() {
        guard !isTableReadyToPlace else { return }
        isTableReadyToPlace = scannedTable.components[SurfaceAnchorComponent.self]?.isLocked ?? false
    }


    func refreshUndersizedTableDetected() {
        guard !hasFoundUndersizedTable else { return }
        hasFoundUndersizedTable = looselySizedTable.isAnchored
    }

    func confirmPlacement(at worldPoint: SIMD3<Float>) {
        guard isTableReadyToPlace, !hasPlacedAnchor else { return }
        hasPlacedAnchor = true

        // The LiDAR scan overlay's job was purely "confirm a surface was found" during the
        // Tap-untuk-Memindai wait — gone the instant the user actually taps, same moment
        // everything else in this method starts building the real placed scene.
        tableScanOverlay?.removeFromParent()
        tableScanOverlay = nil

        let anchor = Entity()
        anchor.name = "PlacementAnchor"

        scannedTable.addChild(anchor)
        anchor.setPosition(worldPoint, relativeTo: nil)


        let cameraPosition = cameraAnchor.position(relativeTo: nil)
        var facing = SIMD3<Float>(worldPoint.x - cameraPosition.x, 0, worldPoint.z - cameraPosition.z)
        facing = simd_length(facing) > 0.0001 ? normalize(facing) : SIMD3<Float>(0, 0, -1)
        let right = normalize(cross(facing, SIMD3<Float>(0, 1, 0)))
        anchor.setOrientation(simd_quatf(from: SIMD3<Float>(1, 0, 0), to: right), relativeTo: nil)

        placementAnchor = anchor


        Task { await loadMasterSceneIfNeeded() }


        report(.surfaceLocked)
    }


    private func loadMasterSceneIfNeeded() async {
        if let masterSceneLoadTask {
            await masterSceneLoadTask.value
            return
        }

        let task = Task { @MainActor [weak self] in

            guard let self, let placementAnchor = self.placementAnchor else { return }

            guard let scene = try? await Entity(named: "Scene", in: realityKitContentBundle) else {
                return
            }

            scene.name = "MasterScene"

            let contentRoot = scene.findEntity(named: "Root") ?? scene
            for child in contentRoot.children {
                child.isEnabled = false
            }


            placementAnchor.addChild(scene)
            scene.setPosition(.zero, relativeTo: placementAnchor)

            self.masterScene = scene
            self.bindTravelEntities(in: scene)
        }

        masterSceneLoadTask = task
        await task.value
    }

    private func spawnUFOIfNeeded() {
        guard !hasSpawnedUFO else { return }
        hasSpawnedUFO = true
        Task { await spawnUFO() }
    }


    private func spawnUFO() async {
        await loadMasterSceneIfNeeded()
        guard let masterScene, let ufo = masterScene.findEntity(named: "ufo_angkat_semut") else { return }

        ufo.isEnabled = true


        let baseScale = ufo.scale.x
        ufo.components.set(UFOComponent(baseScale: baseScale, appearProgress: 0))
        ufo.scale = .zero


        ufo.components.set(HapticCueComponent())
        ufo.components.set(SoundCueComponent())

        let bounds = ufo.visualBounds(relativeTo: ufo)
        let extents = bounds.max - bounds.min
        ufo.components.set(CollisionComponent(shapes: [.generateBox(size: extents)]))
        ufo.components.set(InputTargetComponent())
    }

    func refreshUFODirectionIndicator() {
        guard gameState == .ufoAppears,
              let masterScene,
              let ufo = masterScene.findEntity(named: "ufo_angkat_semut"),
              ufo.components[UFODescendComponent.self] == nil else {
            ufoDirection = nil
            return
        }

        let cameraPosition = cameraAnchor.position(relativeTo: nil)
        let toUFO = ufo.position(relativeTo: nil) - cameraPosition
        guard simd_length(toUFO) > 0.0001 else {
            ufoDirection = nil
            return
        }
        let direction = normalize(toUFO)


        let cameraForward = cameraAnchor.convert(direction: SIMD3<Float>(0, 0, -1), to: nil)
        let onScreenCosThreshold: Float = cos(28 * .pi / 180)
        guard dot(direction, cameraForward) <= onScreenCosThreshold else {
            ufoDirection = nil
            return
        }

        let cameraRight = cameraAnchor.convert(direction: SIMD3<Float>(1, 0, 0), to: nil)
        let cameraUp = cameraAnchor.convert(direction: SIMD3<Float>(0, 1, 0), to: nil)
        // SwiftUI screen space is y-down; camera "up" is y-up, hence the negation.
        var dx = Double(dot(direction, cameraRight))
        var dy = Double(-dot(direction, cameraUp))
        if abs(dx) < 0.0001, abs(dy) < 0.0001 {

            dx = 1
        }
        ufoDirection = CGVector(dx: dx, dy: dy)
    }

    func handleUFOTapped(_ tappedEntity: Entity) {
        guard let masterScene, let ufo = masterScene.findEntity(named: "ufo_angkat_semut") else { return }
        guard isEntity(tappedEntity, partOf: ufo) else { return }
        guard ufo.components[UFODescendComponent.self] == nil else { return }
        guard let target = masterScene.findEntity(named: "finish_ufo") else { return }

        let start = ufo.position(relativeTo: nil)
        let end = target.position(relativeTo: nil)
        ufo.components.set(UFODescendComponent(startPosition: start, targetPosition: end))
    }


    private func isEntity(_ entity: Entity, partOf root: Entity) -> Bool {
        var current: Entity? = entity
        while let node = current {
            if node == root { return true }
            current = node.parent
        }
        return false
    }

    private func beginAntBoardingIfNeeded() {
        guard !hasStartedAntBoarding else { return }
        hasStartedAntBoarding = true
        Task { await beginAntBoarding() }
    }

    private func beginAntsLeaveFormationIfNeeded() {
        guard !hasStartedAntsLeaveFormation else { return }
        hasStartedAntsLeaveFormation = true
        Task { await beginAntsLeaveFormation() }
    }

    /// Step 4 (Attach Component to an Entity). RC PRO <-> CODE HOOKUP: ant1...ant4 and
    /// ant_noanthena, and their finish_ant1...finish_ant4 / finish_ant_noanthena markers, are all
    /// children of Root inside Scene.usda (checked directly in the file), already part of
    /// `masterScene` once loaded — like every top-level child of Root, they start disabled (see
    /// loadMasterSceneIfNeeded()), so each ant is explicitly re-enabled here before
    /// AntWalkComponent is attached; AntWalkSystem does the actual walking, animation, and (for
    /// ant_noanthena only) staying visible once arrived.
    ///
    /// Triggered by `.antsLeaveFormation` (see the state observer above) — the very first real
    /// state after the user taps to confirm placement.
    ///
    /// Falls back to silently skipping any ant whose entity or marker can't be found, so a
    /// missing/misnamed asset doesn't crash the app or block the other four.
    private func beginAntsLeaveFormation() async {
        await loadMasterSceneIfNeeded()
        guard let masterScene else { return }

        for entry in AntFormationConfig.entries {
            guard let ant = masterScene.findEntity(named: entry.antName),
                  let finish = masterScene.findEntity(named: entry.finishName) else {
                continue
            }

            ant.isEnabled = true

            let start = ant.position(relativeTo: nil)
            let target = finish.position(relativeTo: nil)
            ant.components.set(
                AntWalkComponent(startPosition: start, targetPosition: target, disappearsOnArrival: entry.disappearsOnArrival)
            )
        }
    }

    private func beginLostAntGreetIfNeeded() {
        guard !hasStartedLostAntGreet else { return }
        hasStartedLostAntGreet = true
        Task { await beginLostAntGreet() }
    }


    private func beginLostAntGreet() async {
        await loadMasterSceneIfNeeded()
        guard let masterScene, let ant = masterScene.findEntity(named: "ant_noanthena") else { return }

        let rest = ant.position(relativeTo: nil)


        ant.components.set(OpacityComponent(opacity: 1))
        ant.components.set(LostAntGreetComponent(restPosition: rest, risenPosition: rest))


        lostAntGreetPhase = .arrived
    }


    private func beginAntBoarding() async {
        await loadMasterSceneIfNeeded()
        guard let masterScene,
              let ant = masterScene.findEntity(named: "ant_noanthena"),
              let ufo = masterScene.findEntity(named: "ufo_angkat_semut") else {
            return
        }

        let start = ant.position(relativeTo: nil)
        let target = ufo.position(relativeTo: nil)

        ant.components.set(OpacityComponent(opacity: 1))
        ant.components.set(AntBoardComponent(startPosition: start, targetPosition: target))
    }

    private func beginUFOAscendIfNeeded() {
        guard !hasStartedUFOAscend else { return }
        hasStartedUFOAscend = true
        Task { await beginUFOAscend() }
    }


    private func beginUFOAscend() async {
        await loadMasterSceneIfNeeded()
        guard let masterScene,
              let ufo = masterScene.findEntity(named: "ufo_angkat_semut"),
              let target = masterScene.findEntity(named: "ufo_jalan") else {
            return
        }

        ufo.components.set(OpacityComponent(opacity: 1))
        let start = ufo.position(relativeTo: nil)
        let end = target.position(relativeTo: nil)
        ufo.components.set(UFOAscendComponent(startPosition: start, targetPosition: end))

        try? await Task.sleep(for: .seconds(Double(UFOAscendComponent.duration)))
        target.isEnabled = true
        revealEnvironment()
    }

    private func revealEnvironment() {
        guard !hasRevealedEnvironment, let masterScene else { return }
        hasRevealedEnvironment = true

        for name in EnvironmentLayoutConfig.grassEntityNames {
            masterScene.findEntity(named: name)?.isEnabled = true
        }
        masterScene.findEntity(named: EnvironmentLayoutConfig.nestEntityName)?.isEnabled = true

        guard let background = masterScene.findEntity(named: EnvironmentLayoutConfig.backgroundEntityName) else {
            return
        }
        background.isEnabled = true

        if let modelHolder = modelEntity(in: background),
           var model = modelHolder.components[ModelComponent.self] {
            var material = PhysicallyBasedMaterial()
            material.baseColor = .init(tint: EnvironmentLayoutConfig.backgroundColor)
            model.materials = [material]
            modelHolder.components[ModelComponent.self] = model
        }
    }

    private func spawnBlocksIfNeeded() {
        guard !hasSpawnedBlocks else { return }
        hasSpawnedBlocks = true
        Task { await spawnBlocks() }
    }

    private func spawnBlocks() async {
        await loadMasterSceneIfNeeded()
        guard let masterScene else { return }

        for entry in BlockLayoutConfig.entries {
            guard let block = masterScene.findEntity(named: entry.name) else { continue }

            block.isEnabled = true

            if let positionOverride = entry.positionOverride {
                block.setPosition(positionOverride, relativeTo: block.parent)
            }

            if let modelHolder = modelEntity(in: block),
               var model = modelHolder.components[ModelComponent.self] {
                var material = PhysicallyBasedMaterial()
                material.baseColor = .init(tint: entry.color)
                model.materials = [material]
                modelHolder.components[ModelComponent.self] = model
            }

            let bounds = block.visualBounds(relativeTo: block)
            let extents = bounds.max - bounds.min
            block.components.set(CollisionComponent(shapes: [.generateBox(size: extents)]))
            block.components.set(InputTargetComponent())
            block.components.set(BlockCollectibleComponent())

            let baseScale = block.scale.x
            block.components.set(BlockComponent(baseScale: baseScale, appearProgress: 0))
            block.scale = .zero
        }
    }

    func handleBlockTapped(_ tappedEntity: Entity) {
        guard let masterScene else { return }

        for entry in BlockLayoutConfig.entries {
            guard let block = masterScene.findEntity(named: entry.name), isEntity(tappedEntity, partOf: block) else {
                continue
            }
            guard var collectible = block.components[BlockCollectibleComponent.self] else { return }
            guard collectible.isInRange, !collectible.isCollected else { return }

            collectible.isCollected = true
            block.components[BlockCollectibleComponent.self] = collectible
            block.isEnabled = false

            collectedBlocks.append(CollectedBlock(name: entry.name, uiColor: entry.color))
            if collectedBlocks.count >= BlockLayoutConfig.requiredCount {
                report(.allRequiredBlocksCollected)
            }
            return
        }
    }


    private var nextBlockSlotIndex = 0


    func placeBlockInFrontOfUFO(blockID: String) {
        guard nextBlockSlotIndex < BlockPlacementConfig.dropSlotNames.count else { return }
        guard let inventoryIndex = collectedBlocks.firstIndex(where: { $0.id == blockID }) else { return }
        guard let masterScene,
              let block = masterScene.findEntity(named: blockID),
              let slot = masterScene.findEntity(named: BlockPlacementConfig.dropSlotNames[nextBlockSlotIndex]) else {
            return
        }

        collectedBlocks.remove(at: inventoryIndex)
        nextBlockSlotIndex += 1

        block.setPosition(slot.position(relativeTo: nil), relativeTo: nil)

        if let entry = BlockLayoutConfig.entries.first(where: { $0.name == blockID }) {
            let reflectance = IRReflectanceComponent.from(displayColor: entry.color)
            block.components.set(PathTileComponent(order: nextBlockSlotIndex, isPlaced: true))
            block.components.set(reflectance)
        }

        // Same "grow in from zero" reveal spawnBlocks() uses originally — reuses
        // BlockComponent/BlockAppearanceSystem rather than a new animation.
        let baseScale = block.scale.x
        block.components.set(BlockComponent(baseScale: baseScale, appearProgress: 0))
        block.scale = .zero
        block.isEnabled = true

        if nextBlockSlotIndex >= BlockPlacementConfig.requiredPathBlockCount,
           !hasQueuedRequiredPathEvents {
            hasQueuedRequiredPathEvents = true
            report(.requiredPathPlaced)
            report(.ufoMoveRequested)
        }
    }

    /// SwiftUI writes throttle intent only; the ECS systems own movement and motor state.
    func setGasPedalPressed(_ pressed: Bool) {
        guard gameState == .ufoTravelling,
              var control = gameDirector.components[UFOControlComponent.self] else {
            return
        }
        guard control.isPedalPressed != pressed else { return }

        control.setThrottle(pressed ? 1 : 0)
        gameDirector.components[UFOControlComponent.self] = control
        isGasPedalPressed = pressed
    }


    func requestUFOReset() {
        guard gameState == .ufoTravelling,
              var control = gameDirector.components[UFOControlComponent.self] else {
            return
        }

        control.requestReset()
        gameDirector.components[UFOControlComponent.self] = control
        isGasPedalPressed = false
    }

    func setIRSensorCount(_ requestedCount: Int) {
        guard let ufo = masterScene?.findEntity(named: AntARSceneNames.travelUFO),
              var follower = ufo.components[UFOPathFollowerComponent.self] else {
            return
        }

        let count = min(max(requestedCount, IRSensorLayout.minimumCount), IRSensorLayout.maximumCount)
        sensorCount = count
        irLineActivations = Array(repeating: 0, count: count)
        follower.sensorCount = count
        ufo.components[UFOPathFollowerComponent.self] = follower
        ufo.components[IRSensorArrayComponent.self] = IRSensorArrayComponent(sensorCount: count)
        IRSensorFactory.rebuildSensors(
            on: ufo,
            sensorCount: count,
            sensorRange: follower.hoverHeight
        )
    }

    func refreshIRTelemetry() {
        guard let ufo = masterScene?.findEntity(named: AntARSceneNames.travelUFO),
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
        isGasPedalPressed = gameDirector.components[UFOControlComponent.self]?.isPedalPressed ?? false
    }

    private func bindTravelEntities(in scene: Entity) {
        guard let ufo = scene.findEntity(named: AntARSceneNames.travelUFO),
              let home = scene.findEntity(named: AntARSceneNames.home) else {
            return
        }

        let routeStart = ufo.position(relativeTo: ufo.parent)
        let placedSurfaceY = BlockPlacementConfig.dropSlotNames.compactMap {
            scene.findEntity(named: $0)?.position(relativeTo: ufo.parent).y
        }.first ?? 0
        let hoverHeight = max(routeStart.y - placedSurfaceY, 0.05)

        ufo.components.set(
            UFOPathFollowerComponent(
                routeStartPosition: routeStart,
                hoverHeight: hoverHeight
            )
        )
        ufo.components.set(IRSensorArrayComponent(sensorCount: sensorCount))
        home.components.set(HomeComponent())
        IRSensorFactory.rebuildSensors(
            on: ufo,
            sensorCount: sensorCount,
            sensorRange: hoverHeight
        )
        setIRVisualsEnabled(false, on: ufo)
    }

    private func requestUFOTravel() {
        guard let ufo = masterScene?.findEntity(named: AntARSceneNames.travelUFO),
              var follower = ufo.components[UFOPathFollowerComponent.self],
              follower.state == .idle else {
            return
        }
        ufo.isEnabled = true
        setIRVisualsEnabled(true, on: ufo)
        follower.moveRequested = true
        ufo.components[UFOPathFollowerComponent.self] = follower
    }

    private func releaseGasPedal() {
        guard var control = gameDirector.components[UFOControlComponent.self] else { return }
        control.setThrottle(0)
        gameDirector.components[UFOControlComponent.self] = control
        isGasPedalPressed = false
    }

    private func setIRVisualsEnabled(_ enabled: Bool, on ufo: Entity) {
        for child in ufo.children where child.components[IRSensorComponent.self] != nil {
            child.isEnabled = enabled
        }
    }

    private func presentCompletedExperience() {
        guard let masterScene,
              let ufo = masterScene.findEntity(named: AntARSceneNames.travelUFO),
              let home = masterScene.findEntity(named: AntARSceneNames.home),
              let follower = ufo.components[UFOPathFollowerComponent.self] else {
            return
        }

        var position = home.position(relativeTo: ufo.parent)
        position.y += follower.hoverHeight
        ufo.setPosition(position, relativeTo: ufo.parent)
    }


    private func modelEntity(in root: Entity) -> Entity? {
        if root.components[ModelComponent.self] != nil { return root }
        for child in root.children {
            if let found = modelEntity(in: child) { return found }
        }
        return nil
    }
}
