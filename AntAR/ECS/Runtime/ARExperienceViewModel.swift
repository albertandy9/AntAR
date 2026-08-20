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
    private(set) var surfaceDistanceStatus: SurfaceDistanceStatus = .unavailable
    var sensorCount = 2
    var irLineActivations: [Float] = Array(repeating: 0, count: 2)
    var isIRLineDetected = false
    var irLinePosition: Float = 0
    var leftMotorPower: Float = 0
    var rightMotorPower: Float = 0
    var isGasPedalPressed = false
    var sensorLearningPhase: SensorLearningPhase = .baseline
    var isInspectingUFO = false
    var isFinishingUFOInspection = false
    var ufoStallReason: UFOStallReason?
    var isBlockTooFarWarning = false
    private(set) var activeTravelDialogue: UFOTravelDialogue?
    private(set) var isCompletionCardPresented = false
    private(set) var completionCardScreenPosition: CGPoint?
    private(set) var completionCardScale: CGFloat = 1
    private(set) var isAwaitingSensorInspectionTap = false
    private(set) var isShowingSensorCountHint = false
    var isShowingBoardHint = false
    private(set) var boardHintMessage = "UFO belum bisa bergerak. Yuk cari balok di sekitar terlebih dahulu!"
    private(set) var lostAntGreetPhase: LostAntGreetPhase?
    private(set) var placementAnchor: Entity?
    private(set) var ufoDirection: CGVector?
    private(set) var ufoTapScreenPosition: CGPoint?
    // Additive, read-only signal for StoryBubbleSequenceView: the UFO story beats should only
    // show once the player has actually found and tapped the UFO, not the instant it spawns.
    // Doesn't change any existing control flow — set once, alongside where UFODescendComponent
    // already gets attached below, never read by anything else in this file.
    private(set) var hasTappedUFO = false


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

    var isSensorUpgradeRecommended: Bool {
        sensorLearningPhase == .upgradeRecommended
    }

    var canUseGasPedal: Bool {
        // The pedal is also the intentional trigger for the two pre-route conversations:
        // no block collected yet, and blocks collected but none placed. Actual UFO movement
        // remains protected by `canControlUFO` inside the ECS request path.
        isTravelUFOReady
            && gameState.supportsRouteBuilding
            && !isAwaitingSensorInspectionTap
            && !isInspectingUFO
            && !isFinishingUFOInspection
    }

    // Not `private` — ContentView's tap handler needs `scannedTable.isAnchored` and its transform
    // to ray-plane-intersect a 2D tap into a 3D table point (ContentView.intersect(ray:withPlane:)).
    let scannedTable = AnchorEntity(
        .plane(
            .horizontal,
            classification: .table,
            minimumBounds: SurfaceAnchorRequirements.minimumBounds
        )
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
    private var isTravelUFOReady = false
    private var hasReportedRequiredBlocksCollected = false
    private var hasReportedRequiredPathPlaced = false
    private var hasReportedUFOMoveRequested = false
    @ObservationIgnored private var lastIRTelemetryRefreshTime: TimeInterval = 0
    @ObservationIgnored private var lastObservedUFOStallReason: UFOStallReason?
    @ObservationIgnored private var pendingTravelDialogues: [UFOTravelDialogue] = []
    @ObservationIgnored private var shouldPromptSensorInspectionWhenDialoguesFinish = false
    @ObservationIgnored private var hasShownFirstPathDialogue = false
    @ObservationIgnored private var hasShownSensorAdjustmentDialogue = false
    @ObservationIgnored private var hasShownSensorCalibratedDialogue = false
    @ObservationIgnored private var hasPlayedSurfaceDetectedFeedback = false

    private var masterScene: Entity?

    /// Asset I/O starts while the learner is still scanning the table. The same prepared entity
    /// is attached after placement, avoiding a load spike at the `.ufoAppears` transition.
    private var masterSceneAssetLoadTask: Task<Entity?, Never>?
    private var masterSceneLoadTask: Task<Void, Never>?
    @ObservationIgnored
    nonisolated(unsafe) private var stateObserver: NSObjectProtocol?
    @ObservationIgnored
    nonisolated(unsafe) private var hapticObserver: NSObjectProtocol?
    @ObservationIgnored
    nonisolated(unsafe) private var lostAntGreetObserver: NSObjectProtocol?

    init() {
        AntARECSRegistry.register()
        ExperienceFeedback.shared.setUFOMoving(false)
        ExperienceFeedback.shared.startBackgroundMusic()

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
                    ExperienceFeedback.shared.setUFOMoving(false)
                    self?.presentCompletedExperience()
                    self?.enqueueTravelDialogue(.arrivedHome)
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

            Task { @MainActor in
                ExperienceFeedback.shared.impact(uiKitStyle, intensity: CGFloat(intensity))
            }
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
            Task { @MainActor [weak self] in
                self?.lostAntGreetPhase = phase
            }
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


    func refreshSurfaceReadiness() {
        guard !hasPlacedAnchor else { return }

        let isSurfaceLocked = scannedTable.components[SurfaceAnchorComponent.self]?.isLocked ?? false
        let distanceStatus = currentSurfaceDistanceStatus()
        if surfaceDistanceStatus != distanceStatus {
            surfaceDistanceStatus = distanceStatus
        }

        let isReady = isSurfaceLocked && distanceStatus == .valid
        if isTableReadyToPlace != isReady {
            isTableReadyToPlace = isReady
        }
        if isReady, !hasPlayedSurfaceDetectedFeedback {
            hasPlayedSurfaceDetectedFeedback = true
            ExperienceFeedback.shared.success()
        }
    }


    func refreshUndersizedTableDetected() {
        guard !hasPlacedAnchor else { return }
        let isOnlySmallSurfaceAvailable = looselySizedTable.isAnchored && !scannedTable.isAnchored
        if hasFoundUndersizedTable != isOnlySmallSurfaceAvailable {
            hasFoundUndersizedTable = isOnlySmallSurfaceAvailable
        }
    }

    func confirmPlacement(at worldPoint: SIMD3<Float>) {
        let distanceStatus = currentSurfaceDistanceStatus()
        surfaceDistanceStatus = distanceStatus
        guard isTableReadyToPlace,
              distanceStatus == .valid,
              !hasPlacedAnchor else {
            isTableReadyToPlace = false
            return
        }
        hasPlacedAnchor = true

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

    private func currentSurfaceDistanceStatus() -> SurfaceDistanceStatus {
        guard scannedTable.isAnchored, cameraAnchor.isAnchored else { return .unavailable }

        // Horizontal planes are gravity-aligned, so the world-space Y difference is the true
        // perpendicular phone-to-surface distance even when the plane center is off-screen.
        let cameraY = cameraAnchor.position(relativeTo: nil).y
        let surfaceY = scannedTable.position(relativeTo: nil).y
        let distance = abs(cameraY - surfaceY)

        if distance < SurfaceAnchorRequirements.validCameraDistance.lowerBound {
            return .tooClose
        }
        if distance > SurfaceAnchorRequirements.validCameraDistance.upperBound {
            return .tooFar
        }
        return .valid
    }


    private func loadMasterSceneIfNeeded() async {
        if let masterSceneLoadTask {
            await masterSceneLoadTask.value
            return
        }

        let task = Task { @MainActor [weak self] in

            guard let self, let placementAnchor = self.placementAnchor else { return }

            self.startMasterScenePreloadIfNeeded()
            guard let scene = await self.masterSceneAssetLoadTask?.value else {
                return
            }

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

        ufo.components.set(InputTargetComponent())
    }

    func refreshUFODirectionIndicator(using arView: ARView) {
        if gameState.supportsRouteBuilding {
            ufoDirection = nil
            guard isAwaitingSensorInspectionTap,
                  !isInspectingUFO,
                  let ufo = masterScene?.findEntity(named: AntARSceneNames.travelUFO),
                  ufo.isEnabled,
                  let position = arView.project(ufo.position(relativeTo: nil)),
                  arView.bounds.insetBy(dx: -24, dy: -24).contains(position) else {
                ufoTapScreenPosition = nil
                return
            }

            ufoTapScreenPosition = position
            return
        }

        guard gameState == .ufoAppears,
              let masterScene,
              let ufo = masterScene.findEntity(named: "ufo_angkat_semut"),
              ufo.components[UFODescendComponent.self] == nil else {
            ufoDirection = nil
            ufoTapScreenPosition = nil
            return
        }

        let cameraPosition = cameraAnchor.position(relativeTo: nil)
        let toUFO = ufo.position(relativeTo: nil) - cameraPosition
        guard simd_length(toUFO) > 0.0001 else {
            ufoDirection = nil
            ufoTapScreenPosition = nil
            return
        }
        let direction = normalize(toUFO)


        let cameraForward = cameraAnchor.convert(direction: SIMD3<Float>(0, 0, -1), to: nil)
        let onScreenCosThreshold: Float = cos(28 * .pi / 180)
        guard dot(direction, cameraForward) <= onScreenCosThreshold else {
            ufoDirection = nil
            if ufo.components[UFOComponent.self]?.appearProgress == 1,
               let position = arView.project(ufo.position(relativeTo: nil)),
               arView.bounds.insetBy(dx: -24, dy: -24).contains(position) {
                ufoTapScreenPosition = position
            } else {
                ufoTapScreenPosition = nil
            }
            return
        }

        ufoTapScreenPosition = nil

        let cameraRight = cameraAnchor.convert(direction: SIMD3<Float>(1, 0, 0), to: nil)
        let cameraUp = cameraAnchor.convert(direction: SIMD3<Float>(0, 1, 0), to: nil)
        // SwiftUI screen space is y-down; camera "up" is y-up, hence the negation.
        var dx = Double(dot(direction, cameraRight))
        let dy = Double(-dot(direction, cameraUp))
        if abs(dx) < 0.0001, abs(dy) < 0.0001 {

            dx = 1
        }
        ufoDirection = CGVector(dx: dx, dy: dy)
    }

    /// Keeps the completion card attached to a point above the authored ant nest. The card stays
    /// interactive SwiftUI, while its position and apparent scale respond like a world object as
    /// the learner moves the phone around the AR scene.
    func refreshCompletionCardPlacement(using arView: ARView) {
        guard gameState == .completed,
              isCompletionCardPresented,
              let home = masterScene?.findEntity(named: AntARSceneNames.home) else {
            completionCardScreenPosition = nil
            return
        }

        var cardWorldPosition = home.position(relativeTo: nil)
        cardWorldPosition.y += 0.28
        guard let projectedPosition = arView.project(cardWorldPosition) else {
            completionCardScreenPosition = nil
            return
        }

        if completionCardScreenPosition.map({ hypot($0.x - projectedPosition.x, $0.y - projectedPosition.y) > 0.5 }) != false {
            completionCardScreenPosition = projectedPosition
        }

        let cameraDistance = simd_distance(cameraAnchor.position(relativeTo: nil), cardWorldPosition)
        let newScale = min(max(CGFloat(0.72 / max(cameraDistance, 0.01)), 0.68), 1.15)
        if abs(completionCardScale - newScale) > 0.005 {
            completionCardScale = newScale
        }
    }

    func handleUFOTapped(_ tappedEntity: Entity) {
        guard let masterScene, let ufo = masterScene.findEntity(named: "ufo_angkat_semut") else { return }
        guard isEntity(tappedEntity, partOf: ufo) else { return }
        guard ufo.components[UFODescendComponent.self] == nil else { return }
        guard let target = masterScene.findEntity(named: "finish_ufo") else { return }

        let start = ufo.position(relativeTo: nil)
        let end = target.position(relativeTo: nil)
        ExperienceFeedback.shared.play(.ufoDescends)
        ufo.components.set(UFODescendComponent(startPosition: start, targetPosition: end))
        hasTappedUFO = true
    }

    /// The travelling UFO remains tappable while a route is being built. Returning `true` lets
    /// ContentView stop the tap from falling through to block collection.
    @discardableResult
    func handleTravelUFOTapped(_ tappedEntity: Entity) -> Bool {
        guard canControlUFO,
              let ufo = masterScene?.findEntity(named: AntARSceneNames.travelUFO),
              isEntity(tappedEntity, partOf: ufo) else {
            return false
        }

        beginUFOInspection()
        if isInspectingUFO {
            isAwaitingSensorInspectionTap = false
            ufoTapScreenPosition = nil
        }
        return true
    }


    private func isEntity(_ entity: Entity, partOf root: Entity) -> Bool {
        var current: Entity? = entity
        while let node = current {
            if node == root { return true }
            current = node.parent
        }
        return false
    }

    // Not private — StoryBubbleSequenceView calls this once the player has tapped through both
    // UFO story beats, rather than this firing automatically the instant state reaches
    // .antEntersUFO. Idempotent via hasStartedAntBoarding either way, so this is safe to call
    // from a UI event instead of the state observer without changing anything else about how
    // boarding itself plays out once started.
    func beginAntBoardingIfNeeded() {
        guard !hasStartedAntBoarding else { return }
        hasStartedAntBoarding = true
        ExperienceFeedback.shared.play(.antBoardsUFO)
        Task { await beginAntBoarding() }
    }

    func playInitialAntTalkingSound() {
        ExperienceFeedback.shared.play(.antTalking)
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

    // Not private — StoryBubbleSequenceView calls this once the player has tapped through both
    // ant-dialogue lines. See LostAntGreetComponent.isDialogueDismissed's header comment for why
    // LostAntGreetSystem needs this signal before it lets the ant shrink back down.
    func confirmAntDialogueDismissed() {
        ExperienceFeedback.shared.stop(.antTalking)
        guard let masterScene, let ant = masterScene.findEntity(named: "ant_noanthena"),
              var greet = ant.components[LostAntGreetComponent.self] else {
            return
        }
        greet.isDialogueDismissed = true
        ant.components[LostAntGreetComponent.self] = greet
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
        ExperienceFeedback.shared.play(.ufoAscends)
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

        let authoredSurface = EnvironmentLayoutConfig.authoredSurfaceEntityNames.lazy.compactMap {
            masterScene.findEntity(named: $0)
        }.first

        // The scene-authored background is the complete surface: geometry, dimensions, and all
        // PBR materials come directly from RCP. Swift only controls visibility and never replaces
        // its material with a generated color.
        if let authoredSurface {
            authoredSurface.isEnabled = true
            for name in EnvironmentLayoutConfig.fallbackBackgroundEntityNames {
                masterScene.findEntity(named: name)?.isEnabled = false
            }
        } else if let fallback = EnvironmentLayoutConfig.fallbackBackgroundEntityNames.lazy.compactMap({
            masterScene.findEntity(named: $0)
        }).first {
            fallback.isEnabled = true
        }

        masterScene.findEntity(named: EnvironmentLayoutConfig.nestEntityName)?.isEnabled = true

        for (index, name) in EnvironmentLayoutConfig.decorativeEntityNames.enumerated() {
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
            guard !collectible.isCollected else { return }
            guard collectible.isInRange else {
                presentBlockTooFarWarning()
                return
            }

            collectible.isCollected = true
            block.components[BlockCollectibleComponent.self] = collectible
            block.isEnabled = false

            collectedBlockIDs.insert(entry.name)
            collectedBlocks.append(CollectedBlock(name: entry.name, uiColor: entry.color))
            ExperienceFeedback.shared.play(.blockPickedUp)
            ExperienceFeedback.shared.impact(.medium)
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
        ExperienceFeedback.shared.play(.blockPlaced)
        ExperienceFeedback.shared.impact(.medium)
        updatePlacementGuide()
        if masterScene.findEntity(named: AntARSceneNames.travelUFO)?
            .components[UFOPathFollowerComponent.self]?.state == .stalled {
            requestRouteReevaluation()
        }
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

    /// A route is a contiguous sequence, so only its exposed end can be removed. Removing an
    /// earlier tile while a later one is still installed would leave a gap behind the UFO and
    /// make the placement guide/order ambiguous.
    func canReturnPlacedBlockToInventory(blockID: String) -> Bool {
        guard let blockSlot = placedBlockIDsBySlot.firstIndex(where: { $0 == blockID }),
              let lastOccupiedSlot = placedBlockIDsBySlot.lastIndex(where: { $0 != nil }) else {
            return false
        }
        return blockSlot == lastOccupiedSlot
    }

    /// Immediate visual acknowledgement while a placed block is being touched and dragged.
    func setPlacedBlockHoldActive(_ active: Bool, blockID: String) {
        guard placedBlockIDsBySlot.contains(where: { $0 == blockID }),
              let block = masterScene?.findEntity(named: blockID) else {
            return
        }
        block.components.set(OpacityComponent(opacity: active ? 0.52 : 1))
    }

    /// Returns a placed scene entity to inventory without destroying it. Its authored entity,
    /// collision, material, and ECS appearance data are reused the next time it is placed.
    func returnPlacedBlockToInventory(blockID: String) {
        guard gameState != .completed,
              canReturnPlacedBlockToInventory(blockID: blockID),
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
        ExperienceFeedback.shared.play(.blockPickedUp)
        ExperienceFeedback.shared.impact(.medium)
        updatePlacementGuide()

        // Editing a live route asks ECS to sample it again without changing the UFO's transform
        // or current target. The dedicated reset button remains the only full route reset.
        if isTravelUFOReady, gameState.supportsRouteBuilding {
            requestRouteReevaluation()
        }
    }

    private func updatePlacementGuide() {
        guard let masterScene else { return }
        let nextEmptySlot = placedBlockIDsBySlot.firstIndex(where: { $0 == nil })
        BlockPlacementGuideFactory.showOnlySlot(nextEmptySlot, in: masterScene)
    }

    /// SwiftUI writes throttle intent only; the ECS systems own movement and motor state.
    func setGasPedalPressed(_ pressed: Bool) {
        // Releasing must always win, even if a dialogue or state transition has made the pedal
        // ineligible since the gesture began.
        if !pressed {
            releaseGasPedal()
            return
        }

        // An already-active DragGesture may continue delivering `.onChanged(true)` after a
        // dialogue overlay appears. Reject those stale events so the UFO cannot resume behind it.
        guard activeTravelDialogue == nil,
              !isShowingBoardHint,
              !isCompletionCardPresented else {
            releaseGasPedal()
            return
        }

        if !hasPlacedBlocks {
            presentBoardHint(
                collectedBlocks.isEmpty
                    ? "UFO belum bisa bergerak. Yuk cari balok di sekitar terlebih dahulu!"
                    : "Letakkan balok di atas permukaan untuk membuat jalur bagi UFO!"
            )
            return
        }

        if let follower = masterScene?.findEntity(named: AntARSceneNames.travelUFO)?
            .components[UFOPathFollowerComponent.self],
           follower.state == .stalled,
           follower.stallReason == .noPath {
            presentBoardHint(
                "Lanjut letakkan balok di atas permukaan untuk membuat jalur bagi UFO!"
            )
            return
        }

        guard canUseGasPedal,
              masterScene?.findEntity(named: AntARSceneNames.travelUFO)?
                .components[UFOInspectionComponent.self]?.isActive != true,
              var control = gameDirector.components[UFOControlComponent.self] else {
            return
        }
        guard control.isPedalPressed != pressed else { return }

        control.setThrottle(pressed ? 1 : 0)
        gameDirector.components[UFOControlComponent.self] = control
        isGasPedalPressed = pressed
    }

    func dismissBoardHint() {
        isShowingBoardHint = false
    }

    private func presentBoardHint(_ message: String) {
        releaseGasPedal()
        boardHintMessage = message
        guard !isShowingBoardHint else { return }
        ExperienceFeedback.shared.play(.ufoCannotMove)
        ExperienceFeedback.shared.failure()
        isShowingBoardHint = true
    }

    func requestUFOReset() {
        guard isTravelUFOReady,
              gameState.supportsRouteBuilding,
              var control = gameDirector.components[UFOControlComponent.self] else {
            return
        }

        control.requestReset()
        gameDirector.components[UFOControlComponent.self] = control
        isGasPedalPressed = false
        ExperienceFeedback.shared.setUFOMoving(false)
        ufoStallReason = nil
        activeTravelDialogue = nil
        pendingTravelDialogues.removeAll()
        shouldPromptSensorInspectionWhenDialoguesFinish = false
        isAwaitingSensorInspectionTap = false
        ufoTapScreenPosition = nil
    }

    private func requestRouteReevaluation() {
        guard isTravelUFOReady,
              gameState.supportsRouteBuilding,
              var control = gameDirector.components[UFOControlComponent.self] else {
            return
        }

        control.requestRouteReevaluation()
        gameDirector.components[UFOControlComponent.self] = control
        isGasPedalPressed = false
        ExperienceFeedback.shared.setUFOMoving(false)
        ufoStallReason = nil
    }

    /// Requests the ECS inspection pose. Billboard is initialized only as a one-shot camera-facing
    /// request; UFOInspectionSystem removes it after capturing the fixed underside orientation.
    func beginUFOInspection() {
        guard canControlUFO,
              !isInspectingUFO,
              let ufo = masterScene?.findEntity(named: AntARSceneNames.travelUFO),
              var inspection = ufo.components[UFOInspectionComponent.self],
              inspection.phase == .resting else {
            return
        }

        releaseGasPedal()
        ExperienceFeedback.shared.play(.ufoTurn)
        ufo.components.set(BillboardComponent())
        inspection.present()
        ufo.components[UFOInspectionComponent.self] = inspection
        isAwaitingSensorInspectionTap = false
        ufoTapScreenPosition = nil
        isInspectingUFO = true
        isFinishingUFOInspection = false
        isShowingSensorCountHint = true
    }

    func dismissSensorCountHint() {
        isShowingSensorCountHint = false
    }

    /// Returns the UFO to the exact orientation captured before inspection. Normal travel
    /// controls remain hidden until the ECS transition has had time to finish.
    func finishUFOInspection() {
        isShowingSensorCountHint = false
        guard isInspectingUFO,
              !isFinishingUFOInspection,
              let ufo = masterScene?.findEntity(named: AntARSceneNames.travelUFO),
              var inspection = ufo.components[UFOInspectionComponent.self] else {
            return
        }

        ExperienceFeedback.shared.play(.ufoTurn)
        inspection.dismiss()
        ufo.components[UFOInspectionComponent.self] = inspection
        isFinishingUFOInspection = true

        Task { [weak self] in
            try? await Task.sleep(
                for: .seconds(Double(UFOInspectionComponent.transitionDuration) + 0.05)
            )
            guard let self else { return }
            self.isInspectingUFO = false
            self.isFinishingUFOInspection = false
        }
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
        if var learning = ufo.components[SensorLearningComponent.self] {
            learning.updateSensorCount(count)
            ufo.components[SensorLearningComponent.self] = learning
            sensorLearningPhase = learning.phase
        }
        ufo.components[IRSensorArrayComponent.self] = IRSensorArrayComponent(sensorCount: count)
        IRSensorFactory.rebuildSensors(
            on: ufo,
            sensorCount: count,
            sensorRange: follower.hoverHeight
        )
    }

    /// Called by the ARView update subscription; telemetry is intentionally capped
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

        if let learning = ufo.components[SensorLearningComponent.self] {
            if sensorLearningPhase != learning.phase {
                sensorLearningPhase = learning.phase
            }
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
        ExperienceFeedback.shared.setUFOMoving(
            follower.state == .following
                && follower.stallReason == nil
                && nextGasState
                && max(abs(follower.leftMotorPower), abs(follower.rightMotorPower)) > 0.01
        )
        updateTravelDialogue(for: follower.stallReason)
        presentFirstPathDialogueIfNeeded(for: follower)
        presentSensorAdjustmentDialogueIfNeeded(for: follower)
        presentSensorCalibratedDialogueIfNeeded(for: follower)
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
        let learning = SensorLearningComponent(sensorCount: sensorCount)
        ufo.components.set(learning)
        sensorLearningPhase = learning.phase
        ufo.components.set(UFOInspectionComponent())
        ufo.components.set(InputTargetComponent())
        Self.prepareBoxCollision(on: ufo)
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
              var follower = ufo.components[UFOPathFollowerComponent.self] else {
            return
        }
        let canRequestMovement = follower.state == .idle
            || (follower.state == .stalled && follower.stallReason == .noPath)
        guard canRequestMovement else { return }

        ufo.isEnabled = true
        setIRVisualsEnabled(true, on: ufo)
        follower.moveRequested = true
        ufo.components[UFOPathFollowerComponent.self] = follower
    }

    func completeTravelDialogue(_ dialogue: UFOTravelDialogue) {
        guard activeTravelDialogue == dialogue else { return }

        if dialogue == .sensorAdjustment {
            shouldPromptSensorInspectionWhenDialoguesFinish = true
        }

        activeTravelDialogue = pendingTravelDialogues.isEmpty
            ? nil
            : pendingTravelDialogues.removeFirst()

        if dialogue == .arrivedHome {
            isCompletionCardPresented = true
            ExperienceFeedback.shared.play(.levelCompleted)
        }

        if activeTravelDialogue == nil, shouldPromptSensorInspectionWhenDialoguesFinish {
            shouldPromptSensorInspectionWhenDialoguesFinish = false
            isAwaitingSensorInspectionTap = true
        }
    }

    private func presentBlockTooFarWarning() {
        releaseGasPedal()
        isBlockTooFarWarning = true
        Task { [weak self] in
            try? await Task.sleep(for: .seconds(2.2))
            guard let self, self.isBlockTooFarWarning else { return }
            self.isBlockTooFarWarning = false
        }
    }

    private func presentFirstPathDialogueIfNeeded(
        for follower: UFOPathFollowerComponent
    ) {
        guard !hasShownFirstPathDialogue,
              follower.state == .following,
              follower.stallReason == nil,
              isGasPedalPressed,
              follower.elapsedTravelTime >= 0.25 else {
            return
        }

        hasShownFirstPathDialogue = true
        enqueueTravelDialogue(.firstPathSuccess)
    }

    private func presentSensorAdjustmentDialogueIfNeeded(
        for follower: UFOPathFollowerComponent
    ) {
        guard sensorLearningPhase == .upgradeRecommended,
              !hasShownSensorAdjustmentDialogue,
              follower.stallReason == nil,
              follower.state != .arrived else {
            return
        }

        hasShownSensorAdjustmentDialogue = true
        releaseGasPedal()
        enqueueTravelDialogue(.sensorAdjustment)
    }

    private func presentSensorCalibratedDialogueIfNeeded(
        for follower: UFOPathFollowerComponent
    ) {
        guard let learning = masterScene?
                .findEntity(named: AntARSceneNames.travelUFO)?
                .components[SensorLearningComponent.self],
              sensorLearningPhase == .calibrated,
              learning.calibratedDriveDuration
                >= SensorLearningComponent.calibratedDemonstrationDuration,
              !hasShownSensorCalibratedDialogue,
              follower.state == .following,
              !isInspectingUFO,
              isGasPedalPressed,
              follower.stallReason == nil else {
            return
        }

        hasShownSensorCalibratedDialogue = true
        enqueueTravelDialogue(.sensorCalibrated)
    }

    private func updateTravelDialogue(for reason: UFOStallReason?) {
        if ufoStallReason != reason { ufoStallReason = reason }
        guard !isBlockTooFarWarning else { return }
        guard reason != lastObservedUFOStallReason else { return }
        lastObservedUFOStallReason = reason

        switch reason {
        case .noPath:
            releaseGasPedal()
            ExperienceFeedback.shared.play(.ufoCannotMove)
            ExperienceFeedback.shared.failure()
            enqueueTravelDialogue(.noPath)
        case .lightBlockReflectsIR:
            releaseGasPedal()
            ExperienceFeedback.shared.play(.ufoCannotMove)
            ExperienceFeedback.shared.failure()
            enqueueTravelDialogue(.lightBlock)
        case nil:
            break
        }
    }

    private func enqueueTravelDialogue(_ dialogue: UFOTravelDialogue) {
        guard activeTravelDialogue != dialogue,
              !pendingTravelDialogues.contains(dialogue) else {
            return
        }

        // Dialogue presentation owns the interaction until dismissed. Neutralize ECS throttle
        // synchronously, before SwiftUI has to observe and render the overlay.
        releaseGasPedal()

        if activeTravelDialogue == nil {
            activeTravelDialogue = dialogue
        } else {
            pendingTravelDialogues.append(dialogue)
        }
    }

    private func releaseGasPedal() {
        if var control = gameDirector.components[UFOControlComponent.self] {
            control.setThrottle(0)
            gameDirector.components[UFOControlComponent.self] = control
        }
        isGasPedalPressed = false
        ExperienceFeedback.shared.setUFOMoving(false)
    }

    /// Cancels an in-flight UI gesture without consulting the current gameplay eligibility.
    func forceGasPedalNeutral() {
        releaseGasPedal()
    }

    /// Restarts only the learning loop. The existing placement anchor is preserved, while the
    /// authored scene is reloaded so every scattered block regains its original RCP transform.
    func restartFromBlockFinding() {
        guard gameState == .completed, placementAnchor != nil else { return }

        isCompletionCardPresented = false
        completionCardScreenPosition = nil
        completionCardScale = 1
        activeTravelDialogue = nil
        pendingTravelDialogues.removeAll()
        shouldPromptSensorInspectionWhenDialoguesFinish = false
        isAwaitingSensorInspectionTap = false
        isShowingSensorCountHint = false
        isShowingBoardHint = false
        isInspectingUFO = false
        isFinishingUFOInspection = false
        isBlockTooFarWarning = false
        ufoStallReason = nil
        lastObservedUFOStallReason = nil
        ufoTapScreenPosition = nil
        ufoDirection = nil

        collectedBlocks.removeAll()
        collectedBlockIDs.removeAll()
        placedBlockIDsBySlot = Array(repeating: nil, count: BlockPlacementConfig.dropSlotNames.count)
        hasSpawnedBlocks = false
        hasRevealedEnvironment = false
        isTravelUFOReady = false
        hasReportedRequiredBlocksCollected = false
        hasReportedRequiredPathPlaced = false
        hasReportedUFOMoveRequested = false
        hasShownFirstPathDialogue = false
        hasShownSensorAdjustmentDialogue = false
        hasShownSensorCalibratedDialogue = false
        ExperienceFeedback.shared.setUFOMoving(false)

        sensorCount = IRSensorLayout.minimumCount
        irLineActivations = Array(repeating: 0, count: sensorCount)
        isIRLineDetected = false
        irLinePosition = 0
        leftMotorPower = 0
        rightMotorPower = 0
        sensorLearningPhase = .baseline
        gameDirector.components.set(UFOControlComponent())

        masterScene?.removeFromParent()
        masterScene = nil
        masterSceneLoadTask = nil
        masterSceneAssetLoadTask = nil

        // Keep the boarding/ascent story from replaying; the retry begins directly at block
        // discovery, then reveals the authored environment and travel UFO below.
        hasStartedUFOAscend = true
        report(.retryFromBlocks)

        Task { [weak self] in
            guard let self else { return }
            await self.prepareBlockFindingRetryScene()
        }
    }

    private func prepareBlockFindingRetryScene() async {
        await loadMasterSceneIfNeeded()
        guard let masterScene,
              let travelUFO = masterScene.findEntity(named: AntARSceneNames.travelUFO) else {
            return
        }

        await revealEnvironment()
        travelUFO.isEnabled = true
        setIRVisualsEnabled(false, on: travelUFO)
        isTravelUFOReady = true
    }

    private func setIRVisualsEnabled(_ enabled: Bool, on ufo: Entity) {
        for child in ufo.antarDescendants() where child.components[IRSensorComponent.self] != nil {
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
