//
//  ARViewModel.swift
//  AntAR
//

import RealityKit
import Observation
import SwiftUI
import Foundation
import RealityKitContent

@MainActor
@Observable
final class ARViewModel {

    let rootAnchor = AnchorEntity(world: .zero)
    let scannedSurfaceAnchor: Entity

    let cameraAnchor: Entity

    var isSurfaceScanned = false
    var hasPlacedAnts = false
    var isReadyForHandJump = false
    var hasJumped = false

    private var trackingSession: SpatialTrackingSession?

    var antEntity: Entity?
    private var didSpawnAnt = false

    init() {
        AntBehaviorComponent.registerComponent()
        NavigationComponent.registerComponent()
        ScannableSurfaceComponent.registerComponent()

        MeshReconstructionSystem.registerSystem()
        AntNavigationSystem.registerSystem()

        cameraAnchor = AnchorEntity(.camera)
        cameraAnchor.name = "CameraAnchor"
        rootAnchor.name = "RootAnchor"

        scannedSurfaceAnchor = AnchorEntity(.plane(.horizontal, classification: .table, minimumBounds: [0.25, 0.25]))
        scannedSurfaceAnchor.name = "ScannedSurface"
        scannedSurfaceAnchor.components.set(ScannableSurfaceComponent())

        NotificationCenter.default.addObserver(forName: .surfaceScanned, object: nil, queue: .main) { [weak self] _ in
            Task { @MainActor in
                self?.handleSurfaceScanned()
            }
        }
        NotificationCenter.default.addObserver(forName: .antReached, object: nil, queue: .main) { [weak self] _ in
            Task { @MainActor in
                self?.isReadyForHandJump = true
                // TUNABLE — how long the "ulurkan tanganmu" prompt shows before the ant jumps.
                try? await Task.sleep(for: .seconds(3))
                self?.jumpAntOntoHand()
            }
        }
    }

    func setUpScene(content: RealityViewCameraContent) {
        content.add(cameraAnchor)
        content.add(scannedSurfaceAnchor)
        content.add(rootAnchor)
    }

    func startTracking() async {
        let session = SpatialTrackingSession()
        let configuration = SpatialTrackingSession.Configuration(tracking: [.plane, .camera], camera: .back)
        _ = await session.run(configuration)
        trackingSession = session
    }

    private func handleSurfaceScanned() {
        isSurfaceScanned = true
        // No longer auto-spawns here — ContentView's tap gesture calls spawnAntGroup(at:) once
        // the user taps the table, using the tapped point as the anchor instead of the plane's
        // own detected center.
    }

    /// Called from ContentView's tap gesture once `isSurfaceScanned` is true. `tappedPoint` is a
    /// world-space point on the table (computed via `RealityViewCameraContent.unproject(...)` in
    /// ContentView — see its comment for why that's the right tool here). Guarded so only the
    /// first tap spawns anything; later taps are ignored.
    func spawnAntGroup(atTappedPoint tappedPoint: SIMD3<Float>) {
        guard !didSpawnAnt else { return }
        didSpawnAnt = true
        hasPlacedAnts = true
        Task { await spawnAntOnTable(anchorPoint: tappedPoint) }
    }

    private func spawnAntOnTable(anchorPoint: SIMD3<Float>) async {
        let tableCenter = anchorPoint
        let cameraForward = cameraAnchor.convert(direction: SIMD3<Float>(0, 0, -1), to: nil)
        var cameraRight = simd_cross(cameraForward, SIMD3<Float>(0, 1, 0))
        cameraRight.y = 0
        if simd_length(cameraRight) < 0.0001 {
            cameraRight = SIMD3<Float>(1, 0, 0)
        }
        let rightDirection = simd_normalize(cameraRight)
        let leftDirection = -rightDirection


        // BUG FIXED: the lost ant used to share the same `lateralOffsets` array as the other 3
        // (at index 0, offset -0.18), so it stopped 18cm to the side of the exact tapped point,
        // not on it. It now always gets lateral offset 0 — dead center on the tap — while the 3
        // antenna ants take the non-zero offsets around it.
        let antennaLateralOffsets: [Float] = [-0.18, -0.06, 0.18]

        // The lost ant: stops exactly at the tapped point.
        let lostAntStart = tableCenter + leftDirection * 0.9
        await spawnOneAnt(start: lostAntStart, waypoints: [tableCenter], hasAntenna: false)

        // The 3 antenna ants: spread to the sides, continue past center, then fade.
        for lateralOffset in antennaLateralOffsets {
            let lateral = rightDirection * lateralOffset
            let start = tableCenter + leftDirection * 0.9 + lateral
            let centerPoint = tableCenter + lateral
            // This target just needs to be far enough that the ant never actually reaches it —
            // AntNavigationSystem now fades these out mid-stride (fadeOutDuration × speed below
            // ≈ how far they actually get before vanishing, not this number).
            let waypoints = [centerPoint, tableCenter + rightDirection * 0.6 + lateral]
            // TUNABLE — faster than the lost ant's own speed (left as whatever you tuned it to)
            // so it covers noticeable ground during the ~2s fade window instead of barely
            // moving. At 0.3 m/s × 2.0s fade duration, that's ~0.6m of travel past center.
            await spawnOneAnt(start: start, waypoints: waypoints, hasAntenna: true, speed: 0.3)
        }
    }
    private func spawnOneAnt(start: SIMD3<Float>, waypoints: [SIMD3<Float>], hasAntenna: Bool, speed: Float? = nil) async {
        let sceneName = "Scene"
        let ant: Entity
        if let loaded = try? await Entity(named: sceneName, in: realityKitContentBundle) {
            ant = loaded
        } else {
            ant = Entity()
        }
        ant.name = "FriendlyAntScene"

        ant.scale = SIMD3<Float>(repeating: 0.4)
        ant.setPosition(start, relativeTo: nil)

        let direction = waypoints[0] - start
        if simd_length(direction) > 0.0001 {
            let angle = atan2(direction.x, direction.z)
            ant.orientation = simd_quatf(angle: angle, axis: SIMD3<Float>(0, 1, 0))
        }

        var behavior = AntBehaviorComponent()
        behavior.state = .walk
        behavior.hasAntenna = hasAntenna
        if let speed {
            behavior.speed = speed
        }
        ant.components.set(behavior)

        var navigation = NavigationComponent()
        navigation.waypoints = waypoints
        ant.components.set(navigation)


        if hasAntenna {
            ant.components.set(OpacityComponent(opacity: 1.0))
        }

        rootAnchor.addChild(ant)

        if !hasAntenna {
            antEntity = ant
        }
    }
    func jumpAntOntoHand() {
        guard let ant = antEntity, !hasJumped else { return }
        hasJumped = true

        let targetPosition = cameraAnchor.convert(position: SIMD3<Float>(0, -0.08, -0.45), to: nil)

        var behavior = ant.components[AntBehaviorComponent.self] ?? AntBehaviorComponent()
        behavior.state = .onHand
        ant.components[AntBehaviorComponent.self] = behavior

        let cameraPosition = cameraAnchor.position(relativeTo: nil)
        let facingDirection = SIMD3<Float>(cameraPosition.x - targetPosition.x, 0, cameraPosition.z - targetPosition.z)
        var targetRotation = ant.orientation(relativeTo: nil)
        if simd_length(facingDirection) > 0.0001 {
            let angle = atan2(facingDirection.x, facingDirection.z)
            targetRotation = simd_quatf(angle: angle, axis: SIMD3<Float>(0, 1, 0))
        }

        let targetTransform = Transform(
            scale: ant.scale(relativeTo: nil),
            rotation: targetRotation,
            translation: targetPosition
        )
        _ = ant.move(to: targetTransform, relativeTo: nil, duration: 0.45)
    }
}
