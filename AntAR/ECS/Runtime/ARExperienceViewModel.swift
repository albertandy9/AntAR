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
    var sensorCount = 2
    var irLineActivations: [Float] = Array(repeating: 0, count: 2)
    var isIRLineDetected = false
    var irLinePosition: Float = 0
    var leftMotorPower: Float = 0
    var rightMotorPower: Float = 0
    var isGasPedalPressed = false
    private(set) var placementAnchor: Entity?

    /// Every block collected so far, in tap order — drives BlockInventoryView. Nothing in the AR
    /// scene reads this back; it exists purely for the 2D SwiftUI tray.
    private(set) var collectedBlocks: [CollectedBlock] = []
    private var collectedBlockIDs: Set<String> = []
    private var placedBlockIDsBySlot: [String?] = Array(
        repeating: nil,
        count: BlockPlacementConfig.dropSlotNames.count
    )

    var hasPlacedBlocks: Bool {
        placedBlockIDsBySlot.contains { $0 != nil }
    }

    var canControlUFO: Bool {
        hasPlacedBlocks && isTravelUFOReady && gameState.supportsRouteBuilding
    }

    // Not `private` — ContentView's tap handler needs `scannedTable.isAnchored` and its
    // transform (for `unproject(...ontoPlane:)`) to convert a 2D tap into a 3D table point.
    let scannedTable = AnchorEntity(
        .plane(.horizontal, classification: .table, minimumBounds: SIMD2<Float>(repeating: 0.25))
    )

    private let cameraAnchor = AnchorEntity(.camera)
    private let experienceRoot = AnchorEntity(world: .zero)
    private let gameDirector = Entity()
    private var trackingSession: SpatialTrackingSession?
    private var hasAddedScene = false
    private var hasPlacedAnchor = false
    private var hasSpawnedUFO = false
    private var hasRevealedAnt = false
    private var hasStartedAntBoarding = false
    private var hasStartedUFOAscend = false
    private var hasSpawnedBlocks = false
    private var hasRevealedEnvironment = false
    private var isTravelUFOReady = false
    private var hasReportedRequiredBlocksCollected = false
    private var hasReportedRequiredPathPlaced = false
    private var hasReportedUFOMoveRequested = false
    @ObservationIgnored private var lastIRTelemetryRefreshTime: TimeInterval = 0

    private var masterScene: Entity?

    /// Asset I/O starts while the learner is still scanning the table. The same prepared entity
    /// is attached after placement, avoiding a load spike at the `.ufoAppears` transition.
    private var masterSceneAssetLoadTask: Task<Entity?, Never>?
    private var masterSceneLoadTask: Task<Void, Never>?
    @ObservationIgnored
    nonisolated(unsafe) private var stateObserver: NSObjectProtocol?
    @ObservationIgnored
    nonisolated(unsafe) private var hapticObserver: NSObjectProtocol?

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
                if state == .ufoAppears {
                    self?.spawnUFOIfNeeded()
                } else if state == .antEntersUFO {
                    self?.beginAntBoardingIfNeeded()
                } else if state == .blocksScattered {
                    self?.beginUFOAscendIfNeeded()
                    self?.spawnBlocksIfNeeded()
                } else if state == .blocksCollected {
                    self?.reportRequiredPathPlacedIfReady()
                } else if state == .blocksPlaced {
                    self?.reportUFOMoveRequestedIfNeeded()
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
    }

    deinit {
        if let stateObserver {
            NotificationCenter.default.removeObserver(stateObserver)
        }
        if let hapticObserver {
            NotificationCenter.default.removeObserver(hapticObserver)
        }
    }

    func setUpScene(in content: RealityViewCameraContent) {
        guard !hasAddedScene else { return }
        content.add(experienceRoot)
        content.add(scannedTable)
        content.add(cameraAnchor)
        hasAddedScene = true
    }

    func startTracking() async {
        startMasterScenePreloadIfNeeded()

        let session = SpatialTrackingSession()
        let configuration = SpatialTrackingSession.Configuration(
            tracking: [.plane],
            camera: .back
        )

        _ = await session.run(configuration)
        trackingSession = session
    }

    private func startMasterScenePreloadIfNeeded() {
        guard masterSceneAssetLoadTask == nil else { return }

        masterSceneAssetLoadTask = Task { @MainActor in
            guard let scene = try? await Entity(named: "Scene", in: realityKitContentBundle) else {
                return nil
            }

            scene.name = "MasterScene"
            Self.prepareStaticSceneResources(in: scene)
            IRSensorFactory.prepareSharedResources()
            return scene
        }
    }

    /// Entry point for future systems/adapters that are not themselves RealityKit systems.
    func report(_ event: GameEvent) {
        guard var events = gameDirector.components[GameEventComponent.self] else { return }
        events.enqueue(event)
        gameDirector.components[GameEventComponent.self] = events
    }

    /// Call every frame from ContentView's `SceneEvents.Update` subscription. Cheap no-op once
    /// already true, so polling it every frame is fine.
    func refreshSurfaceReadiness() {
        guard !isTableReadyToPlace else { return }
        isTableReadyToPlace = scannedTable.components[SurfaceAnchorComponent.self]?.isLocked ?? false
    }

    func confirmPlacement(at worldPoint: SIMD3<Float>) {
        guard isTableReadyToPlace, !hasPlacedAnchor else { return }
        hasPlacedAnchor = true

        let anchor = Entity()
        anchor.name = "PlacementAnchor"
        // Parented to scannedTable (continuously corrected by ARKit's plane tracking), not
        // experienceRoot (raw, uncorrected world .zero) — otherwise everything built on this
        // anchor visibly drifts/reorients whenever ARKit corrects its pose estimate, which
        // happens more often in small/feature-poor rooms.
        //
        // BUG TO AVOID: addChild(_:preservingWorldTransform:) defaults to false. Calling
        // setPosition(worldPoint, relativeTo: nil) BEFORE addChild would set anchor's local
        // transform directly (since it has no parent yet), and that local offset would then get
        // applied on top of scannedTable's own real, non-identity transform once parented —
        // landing anchor in the wrong place, not at the tapped point. addChild has to happen
        // first, so relativeTo: nil below correctly resolves against true world space and
        // RealityKit computes the right local offset from scannedTable's current transform.
        scannedTable.addChild(anchor)
        anchor.setPosition(worldPoint, relativeTo: nil)
        placementAnchor = anchor

        // Kick off loading the master scene as soon as we know where it should sit (the tapped
        // anchor) — by the time any state actually needs an entity from it, it's likely already
        // loaded. loadMasterSceneIfNeeded() is itself idempotent/guarded, so this is safe even if
        // something else also triggers a load before this finishes.
        Task { await loadMasterSceneIfNeeded() }

        report(.surfaceLocked)

        // THIS IS WHAT I NEED TO CHANGED LATER — fast-forwards straight through
        // .antsLeaveFormation / .lostAntAtSurfaceOrigin / .lostAntDialogue to land on
        // .ufoAppears, since the systems that should genuinely report .otherAntsExited,
        // .lostAntReachedOrigin, and .lostAntDialogueDismissed don't exist yet. GameStateMachine
        // System only consumes one queued event per frame, so this walks the *real* transition
        // table (GameState.transition(for:), untouched) one step per frame instead of skipping
        // it — each of these three should eventually be reported by its own real system instead
        // of being queued back-to-back here.
        report(.otherAntsExited)
        report(.lostAntReachedOrigin)
        report(.lostAntDialogueDismissed)
    }


    private func loadMasterSceneIfNeeded() async {
        if let masterSceneLoadTask {
            await masterSceneLoadTask.value
            return
        }

        let task = Task { @MainActor [weak self] in
            // Requires placementAnchor to already exist — in practice it always does by the time
            // this runs, since loadMasterSceneIfNeeded() is only ever called from confirmPlacement
            // (which sets placementAnchor first) or from state-triggered spawn methods that can
            // only fire after confirmPlacement has already advanced GameState past .scanningTable.
            guard let self, let placementAnchor = self.placementAnchor else { return }

            self.startMasterScenePreloadIfNeeded()
            guard let scene = await self.masterSceneAssetLoadTask?.value else {
                return
            }

            let contentRoot = scene.findEntity(named: "Root") ?? scene
            for child in contentRoot.children {
                child.isEnabled = false
            }

            // Child of placementAnchor (not experienceRoot) — it now inherits every correction
            // placementAnchor itself inherits from scannedTable's continuous plane tracking.
            // Explicitly zeroed relative to placementAnchor rather than relying on whatever
            // default local transform the loaded "Scene" wrapper happens to carry — addChild's
            // preservingWorldTransform defaults to false, so without this, scene would keep
            // whatever local transform it loaded with instead of sitting exactly at
            // placementAnchor's origin.
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

        ufo.components.set(InputTargetComponent())
    }

    func handleUFOTapped(_ tappedEntity: Entity) {
        guard let masterScene, let ufo = masterScene.findEntity(named: "ufo_angkat_semut") else { return }
        guard isEntity(tappedEntity, partOf: ufo) else { return }
        guard ufo.components[UFODescendComponent.self] == nil else { return }
        guard let target = masterScene.findEntity(named: "finish_ufo") else { return }

        let start = ufo.position(relativeTo: nil)
        let end = target.position(relativeTo: nil)
        ufo.components.set(UFODescendComponent(startPosition: start, targetPosition: end))


        revealAntIfNeeded()
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

    /// Step 4 (Attach Component to an Entity). RC PRO <-> CODE HOOKUP: "ant_noanthena" (the lost
    /// ant — no antenna, matching the app's own premise) and "finish_ant_noanthena" (its original
    /// walking-finish marker) are both children of Root inside Scene.usda, already part of
    /// `masterScene` once loaded, both hidden like everything else in it. Called as soon as the
    /// UFO is tapped (see handleUFOTapped), not once .antEntersUFO is reached — so the ant reads
    /// as already waiting there while the UFO comes down, rather than appearing out of nowhere.
    ///
    /// THIS IS WHAT I NEED TO CHANGED LATER: this treats "finish_ant_noanthena" as simply "where
    /// the ant already is," because .antsLeaveFormation / .lostAntAtSurfaceOrigin (the phases
    /// where the ant would actually walk there) are still fast-forwarded — see
    /// confirmPlacement()'s own "CHANGED LATER" note, this is the same gap. Once those are for
    /// real built, the ant will already be visible and correctly positioned at
    /// finish_ant_noanthena from actual gameplay well before the UFO is even tapped — at that
    /// point, remove this method's `ant.isEnabled = true` / `ant.setPosition(...)` lines (they'd
    /// be redundant, and re-positioning an ant that's mid-walk-animation would visibly snap it),
    /// and beginAntBoarding() below can just read whichever ant entity that earlier phase leaves
    /// behind instead of relying on this having run first.
    ///
    /// Falls back to silently doing nothing if the scene or either named entity can't be found,
    /// so a missing/misnamed asset doesn't crash the app.
    private func revealAntIfNeeded() {
        guard !hasRevealedAnt else { return }
        hasRevealedAnt = true
        Task { await revealAnt() }
    }

    private func revealAnt() async {
        await loadMasterSceneIfNeeded()
        guard let masterScene,
              let ant = masterScene.findEntity(named: "ant_noanthena"),
              let origin = masterScene.findEntity(named: "finish_ant_noanthena") else {
            return
        }

        ant.isEnabled = true
        ant.setPosition(origin.position(relativeTo: nil), relativeTo: nil)
        ant.components.set(OpacityComponent(opacity: 1))
    }

    /// Triggered by `.antEntersUFO` (see the state observer above) — by this point the UFO has
    /// finished descending and revealAnt() (triggered earlier, at tap time) has already made the
    /// ant visible, so this only needs to attach AntBoardComponent to start the rise-and-fade.
    /// Falls back to silently doing nothing if the scene or either named entity can't be found.
    private func beginAntBoarding() async {
        await loadMasterSceneIfNeeded()
        guard let masterScene,
              let ant = masterScene.findEntity(named: "ant_noanthena"),
              let ufo = masterScene.findEntity(named: "ufo_angkat_semut") else {
            return
        }

        let start = ant.position(relativeTo: nil)
        let target = ufo.position(relativeTo: nil)
        ant.components.set(AntBoardComponent(startPosition: start, targetPosition: target))
    }

    private func beginUFOAscendIfNeeded() {
        guard !hasStartedUFOAscend else { return }
        hasStartedUFOAscend = true
        Task { await beginUFOAscend() }
    }

    /// Step 4 (Attach Component to an Entity). RC PRO <-> CODE HOOKUP: "ufo_jalan" is a separate
    /// entity from "ufo_angkat_semut" (different reference — UFO.usda vs friendly_ufo.usdz,
    /// checked directly in Scene.usda) meant for the later travelling phase. Both are already
    /// part of `masterScene`, hidden like everything else in it.
    ///
    /// Triggered by `.blocksScattered` (see the state observer above) — "ufo_angkat_semut" rises
    /// from wherever it currently is (finish_ufo, after descending) to ufo_jalan's own position
    /// and fades out (UFOAscendSystem), and only once that's actually finished does this reveal
    /// "ufo_jalan" — waiting out UFOAscendComponent.duration rather than revealing it
    /// immediately, so it reads as "ufo_jalan appears once the other one is gone," not both UFOs
    /// visible at once. No GameEvent involved here — see UFOAscendSystem's header comment for
    /// why: this moment doesn't correspond to any of the 11 story beats, so there's nothing to
    /// report to GameStateMachineSystem, and the state stays `.blocksScattered` throughout.
    ///
    /// Falls back to silently doing nothing if the scene or either named entity can't be found,
    /// so a missing/misnamed asset doesn't crash the app.
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

        // Spread environment activation across the existing ascend animation. This keeps grass,
        // terrain, and the travelling UFO from all becoming renderable on the same frame.
        let environmentRevealTask = Task { @MainActor [weak self] in
            await self?.revealEnvironment()
        }

        try? await Task.sleep(for: .seconds(Double(UFOAscendComponent.duration)))
        await environmentRevealTask.value
        target.isEnabled = true
        isTravelUFOReady = true
        if hasPlacedBlocks {
            requestUFOTravel()
        }
    }

    private func revealEnvironment() async {
        guard !hasRevealedEnvironment, let masterScene else { return }
        hasRevealedEnvironment = true

        let flatBackground = masterScene.findEntity(named: EnvironmentLayoutConfig.backgroundEntityName)

        // Prefer an authored terrain instance and preserve every material from its USDZ. The
        // simple brown plane remains a fallback for scenes that have not added env_terrain yet.
        if let terrain = masterScene.findEntity(named: EnvironmentLayoutConfig.terrainEntityName) {
            terrain.isEnabled = true
            flatBackground?.isEnabled = false
        } else if let background = flatBackground {
            background.isEnabled = true

            if let modelHolder = Self.modelEntity(in: background),
               var model = modelHolder.components[ModelComponent.self] {
                var material = PhysicallyBasedMaterial()
                material.baseColor = .init(tint: EnvironmentLayoutConfig.backgroundColor)
                material.roughness = .init(floatLiteral: 0.92)
                material.metallic = .init(floatLiteral: 0)
                model.materials = [material]
                modelHolder.components[ModelComponent.self] = model
            }
        }

        masterScene.findEntity(named: EnvironmentLayoutConfig.nestEntityName)?.isEnabled = true

        for (index, name) in EnvironmentLayoutConfig.grassEntityNames.enumerated() {
            masterScene.findEntity(named: name)?.isEnabled = true

            // Two small assets per frame is visually immediate but avoids one large activation
            // burst. Sleeping is asynchronous, so it never blocks RealityKit's render thread.
            if index.isMultiple(of: 2) {
                try? await Task.sleep(for: .milliseconds(16))
            }
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

            block.components.set(InputTargetComponent())
            block.components.set(BlockCollectibleComponent())

            let baseScale = block.scale
            block.components.set(BlockComponent(baseScale: baseScale, appearProgress: 0))
            block.scale = .zero
        }

        updatePlacementGuide()
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

            collectedBlockIDs.insert(entry.name)
            collectedBlocks.append(CollectedBlock(name: entry.name, uiColor: entry.color))
            if collectedBlockIDs.count >= BlockLayoutConfig.requiredCount,
               !hasReportedRequiredBlocksCollected {
                hasReportedRequiredBlocksCollected = true
                report(.allRequiredBlocksCollected)
            }
            return
        }
    }

    func placeBlockInFrontOfUFO(blockID: String) {
        guard let slotIndex = placedBlockIDsBySlot.firstIndex(where: { $0 == nil }) else { return }
        guard let inventoryIndex = collectedBlocks.firstIndex(where: { $0.id == blockID }) else { return }
        guard let masterScene,
              let block = masterScene.findEntity(named: blockID),
              let slot = masterScene.findEntity(named: BlockPlacementConfig.dropSlotNames[slotIndex]) else {
            return
        }

        collectedBlocks.remove(at: inventoryIndex)
        placedBlockIDsBySlot[slotIndex] = blockID

        block.setPosition(slot.position(relativeTo: nil), relativeTo: nil)

        if let entry = BlockLayoutConfig.entries.first(where: { $0.name == blockID }) {
            let bounds = block.visualBounds(relativeTo: block)
            let center = (bounds.min + bounds.max) * 0.5
            let halfExtents = (bounds.max - bounds.min) * 0.5
            block.components.set(
                PathTileComponent(
                    order: slotIndex + 1,
                    isPlaced: true,
                    footprintCenter: SIMD2<Float>(center.x, center.z),
                    footprintHalfExtents: SIMD2<Float>(halfExtents.x, halfExtents.z)
                )
            )
            block.components.set(entry.irMaterial)
        }

        // Same "grow in from zero" reveal spawnBlocks() uses originally — reuses
        // BlockComponent/BlockAppearanceSystem rather than a new animation.
        let baseScale = block.components[BlockComponent.self]?.baseScale ?? block.scale
        block.components.set(BlockComponent(baseScale: baseScale, appearProgress: 0))
        block.scale = .zero
        block.components.set(OpacityComponent(opacity: 1))
        block.isEnabled = true
        updatePlacementGuide()
        requestUFOTravel()
        reportRequiredPathPlacedIfReady()
    }

    private func reportRequiredPathPlacedIfReady() {
        guard gameState == .blocksCollected,
              placedBlockIDsBySlot.allSatisfy({ $0 != nil }),
              !hasReportedRequiredPathPlaced else {
            return
        }
        hasReportedRequiredPathPlaced = true
        report(.requiredPathPlaced)
    }

    private func reportUFOMoveRequestedIfNeeded() {
        guard gameState == .blocksPlaced, !hasReportedUFOMoveRequested else { return }
        hasReportedUFOMoveRequested = true
        report(.ufoMoveRequested)
    }

    /// Resolves a hit-tested RealityKit child back to a currently placed route block.
    func placedBlockID(containing entity: Entity) -> String? {
        guard gameState != .completed, let masterScene else { return nil }

        for blockID in placedBlockIDsBySlot.compactMap({ $0 }) {
            guard let block = masterScene.findEntity(named: blockID),
                  block.components[PathTileComponent.self]?.isPlaced == true else {
                continue
            }
            if isEntity(entity, partOf: block) { return blockID }
        }
        return nil
    }

    /// Visual acknowledgement while a placed block is being dragged toward the 2D inventory.
    func setPlacedBlockDragActive(_ active: Bool, blockID: String) {
        guard let block = masterScene?.findEntity(named: blockID) else { return }
        block.components.set(OpacityComponent(opacity: active ? 0.52 : 1))
    }

    /// Returns a placed scene entity to inventory without destroying it. Its authored entity,
    /// collision, material, and ECS appearance data are reused the next time it is placed.
    func returnPlacedBlockToInventory(blockID: String) {
        guard gameState != .completed,
              let slotIndex = placedBlockIDsBySlot.firstIndex(where: { $0 == blockID }),
              let masterScene,
              let block = masterScene.findEntity(named: blockID),
              let entry = BlockLayoutConfig.entries.first(where: { $0.name == blockID }) else {
            return
        }

        placedBlockIDsBySlot[slotIndex] = nil
        block.components.remove(PathTileComponent.self)
        block.components.remove(IRReflectanceComponent.self)
        block.components.set(OpacityComponent(opacity: 1))
        block.isEnabled = false

        if !collectedBlocks.contains(where: { $0.id == blockID }) {
            collectedBlocks.append(CollectedBlock(name: entry.name, uiColor: entry.color))
        }
        updatePlacementGuide()

        // Editing a live route safely resets the ECS-owned follower before another run.
        if isTravelUFOReady, gameState.supportsRouteBuilding {
            requestUFOReset()
        }
    }

    private func updatePlacementGuide() {
        guard let masterScene else { return }
        let nextEmptySlot = placedBlockIDsBySlot.firstIndex(where: { $0 == nil })
        BlockPlacementGuideFactory.showOnlySlot(nextEmptySlot, in: masterScene)
    }

    /// SwiftUI writes throttle intent only; the ECS systems own movement and motor state.
    func setGasPedalPressed(_ pressed: Bool) {
        guard canControlUFO,
              var control = gameDirector.components[UFOControlComponent.self] else {
            return
        }
        guard control.isPedalPressed != pressed else { return }

        control.setThrottle(pressed ? 1 : 0)
        gameDirector.components[UFOControlComponent.self] = control
        isGasPedalPressed = pressed
    }

    /// Sends a reset request to the state-10 ECS control system. The canonical global state/event
    /// table remains the incoming branch's source of truth and receives no reverse transition.
    func requestUFOReset() {
        guard isTravelUFOReady,
              gameState.supportsRouteBuilding,
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

    /// Called by the incoming RealityView update subscription; telemetry is intentionally capped
    /// at 20 Hz so changing sensor values do not invalidate the SwiftUI hierarchy every frame.
    func refreshIRTelemetry() {
        guard canControlUFO else { return }

        let now = ProcessInfo.processInfo.systemUptime
        guard now - lastIRTelemetryRefreshTime >= 1.0 / 20.0 else { return }
        lastIRTelemetryRefreshTime = now

        guard let ufo = masterScene?.findEntity(named: AntARSceneNames.travelUFO),
              let readings = ufo.components[IRSensorArrayComponent.self],
              let follower = ufo.components[UFOPathFollowerComponent.self] else {
            return
        }

        let nextActivations = readings.lineSignals.map { min(max($0, 0), 1) }
        let decision = IRLineFollowingPolicy.decide(lineSignals: readings.lineSignals)
        let nextGasState = gameDirector.components[UFOControlComponent.self]?.isPedalPressed ?? false

        if irLineActivations != nextActivations { irLineActivations = nextActivations }
        if isIRLineDetected != decision.hasLine { isIRLineDetected = decision.hasLine }
        if abs(irLinePosition - decision.lateralCorrection) > 0.005 {
            irLinePosition = decision.lateralCorrection
        }
        if abs(leftMotorPower - follower.leftMotorPower) > 0.005 {
            leftMotorPower = follower.leftMotorPower
        }
        if abs(rightMotorPower - follower.rightMotorPower) > 0.005 {
            rightMotorPower = follower.rightMotorPower
        }
        if isGasPedalPressed != nextGasState { isGasPedalPressed = nextGasState }
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
        guard isTravelUFOReady,
              gameState.supportsRouteBuilding,
              let ufo = masterScene?.findEntity(named: AntARSceneNames.travelUFO),
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
        setIRVisualsEnabled(false, on: ufo)
    }


    private static func prepareStaticSceneResources(in scene: Entity) {
        if let ufo = scene.findEntity(named: "ufo_angkat_semut") {
            prepareBoxCollision(on: ufo)
        }

        for entry in BlockLayoutConfig.entries {
            guard let block = scene.findEntity(named: entry.name) else { continue }

            if let modelHolder = modelEntity(in: block),
               var model = modelHolder.components[ModelComponent.self] {
                var material = PhysicallyBasedMaterial()
                material.baseColor = .init(tint: entry.color)
                // Painted/cardboard-like blocks should have broad, soft highlights rather than
                // behaving like polished plastic or metal.
                material.roughness = .init(floatLiteral: 0.82)
                material.metallic = .init(floatLiteral: 0)
                model.materials = [material]
                modelHolder.components[ModelComponent.self] = model
            }

            prepareBoxCollision(on: block)
        }

        BlockPlacementGuideFactory.install(in: scene)
    }

    private static func prepareBoxCollision(on entity: Entity) {
        guard entity.components[CollisionComponent.self] == nil else { return }

        let bounds = entity.visualBounds(relativeTo: entity)
        let extents = bounds.max - bounds.min
        guard extents.x > 0.0001, extents.y > 0.0001, extents.z > 0.0001 else { return }
        entity.components.set(CollisionComponent(shapes: [.generateBox(size: extents)]))
    }

    private static func modelEntity(in root: Entity) -> Entity? {
        if root.components[ModelComponent.self] != nil { return root }
        for child in root.children {
            if let found = modelEntity(in: child) { return found }
        }
        return nil
    }
}
