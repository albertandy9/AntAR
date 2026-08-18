//
//  ContentView.swift
//  AntAR
//
//  SwiftUI owns the presentation layer only. AR anchors, ECS registration, and
//  game-state events are owned by ARExperienceViewModel and the ECS runtime.
//

import AVFoundation
import RealityKit
import SwiftUI

struct ContentView: View {
    @State private var viewModel = ARExperienceViewModel()
    // Captured from ARViewContainer via binding so the tap gesture (called independently by
    // SwiftUI) can still reach entity(at:)/ray(through:).
    @State private var arView: ARView?
    // Gates the AR experience behind OnboardingView — camera permission + tracking (the .task
    // below) only start once this flips true, not on launch.
    @State private var hasStartedExperience = false
    // Gates ARViewContainer specifically (not the whole overlay UI) behind an explicit camera
    // permission result, same "don't touch the camera until we know we're allowed to" gating
    // hasStartedExperience already does at the OnboardingView level.
    @State private var isCameraAuthorized = false
    // True only 2s after .releasing begins, not the instant it begins — the ant reveal/"Turunkan
    // tanganmu"/hand overlay disappearing all happen together at the start of .releasing, but the
    // dialogue bubble should wait a beat after that before showing up. Driven by the .task(id:)
    // below rather than a direct phase check, since it needs its own delayed timer.
    @State private var showLostAntBubble = false

    var body: some View {
        if hasStartedExperience {
            arExperience
        } else {
            OnboardingView(onFinish: { hasStartedExperience = true })
        }
    }

    private var arExperience: some View {
        ZStack {
            if isCameraAuthorized {
                ARViewContainer(viewModel: viewModel, arView: $arView)
                    .gesture(
                        SpatialTapGesture()
                            .onEnded { event in
                                handleTap(at: event.location)
                            }
                    )
                    .dropDestination(for: String.self) { items, _ in
                        guard let blockID = items.first else { return false }
                        viewModel.placeBlockInFrontOfUFO(blockID: blockID)
                        return true
                    }
                    .ignoresSafeArea()
            }

            // Full-screen, not inside the VStack below — needs the whole screen's GeometryReader
            // to clamp itself to the actual screen edge, not just the VStack's content area.
            if let ufoDirection = viewModel.ufoDirection {
                UFODirectionIndicatorView(direction: ufoDirection)
                    .ignoresSafeArea()
            }

            // Top-left corner, independent of the bottom-anchored VStack below — and independent
            // of BlockInventoryNotesButton (bottom-right), which used to be bundled with this in
            // one HStack before the inventory pill moved up here.
            if !viewModel.collectedBlocks.isEmpty {
                VStack {
                    HStack {
                        BlockInventoryView(collectedBlocks: viewModel.collectedBlocks)
                        Spacer()
                    }
                    Spacer()
                }
                .padding(.top, 24)
                .padding(.leading, 16)
            }

            VStack {
                GameOverlayView(
                    state: viewModel.gameState,
                    isTableReadyToPlace: viewModel.isTableReadyToPlace,
                    lostAntGreetPhase: viewModel.lostAntGreetPhase,
                    isCoachingOverlayActive: viewModel.isCoachingOverlayActive,
                    isSurfaceTooSmall: viewModel.hasFoundUndersizedTable
                )
                .padding(.top, 24)

                Spacer()

                // Hand overlay only shows through .waiting/.rising/.chatting — it disappears the
                // instant .releasing starts (same moment the text switches to "Turunkan aku"),
                // well before the ant actually jumps back during .returning.
                if let lostAntGreetPhase = viewModel.lostAntGreetPhase,
                   lostAntGreetPhase == .waiting || lostAntGreetPhase == .rising || lostAntGreetPhase == .chatting {
                    // Bottom safe-area inset (space reserved for the home indicator) is what was
                    // leaving a gap below this image — ignored just here, not for the whole VStack,
                    // since BlockInventoryView/UFOTravelControlsView below are interactive and
                    // should stay clear of that area, unlike this purely decorative image.
                    LostAntHandOverlayView()
                        .ignoresSafeArea(edges: .bottom)
                }

                // Bottom-left, not GameOverlayView's top slot — see LostAntChatBubbleView's header.
                // Gated on showLostAntBubble (set 2s after .releasing begins, see the .task(id:)
                // below), not phase directly — the ant reveal/"Turunkan tanganmu" happen right as
                // .releasing starts, but the dialogue itself waits a beat after that.
                if showLostAntBubble {
                    LostAntChatBubbleView()
                        .padding(.bottom, 24)
                }

                if viewModel.gameState == .ufoTravelling {
                    UFOTravelControlsView(viewModel: viewModel)
                        .padding(.horizontal, 16)
                        .padding(.bottom, 24)
                }
            }
        }
        .task {
            isCameraAuthorized = await AVCaptureDevice.requestAccess(for: .video)
        }
        // Re-runs (cancelling any pending sleep) every time lostAntGreetPhase changes. Only
        // .releasing schedules the 2s delay; every other phase — including leaving .releasing —
        // resets showLostAntBubble to false immediately.
        .task(id: viewModel.lostAntGreetPhase) {
            guard viewModel.lostAntGreetPhase == .releasing else {
                showLostAntBubble = false
                return
            }
            showLostAntBubble = false
            try? await Task.sleep(for: .seconds(2))
            guard !Task.isCancelled else { return }
            showLostAntBubble = true
        }
    }

    /// Same phone-screen tap gesture handles two completely different things depending on
    /// `gameState` — not two gesture recognizers, just a branch on what the tap should mean right
    /// now.
    private func handleTap(at location: CGPoint) {
        guard let arView else { return }

        if viewModel.gameState == .ufoAppears {
            // Real 3D entity hit-test (ARView.entity(at:)) — different from the table-tap below,
            // which projects onto a known plane rather than hit-testing actual entity geometry.
            // Requires the UFO to have a CollisionComponent, which ARExperienceViewModel.spawnUFO()
            // sets up.
            let tappedEntity = arView.entity(at: location)
            if let tappedEntity {
                viewModel.handleUFOTapped(tappedEntity)
            }
            return
        }

        if viewModel.gameState == .blocksScattered {
            // Same 3D entity hit-test as the UFO tap above. handleBlockTapped() itself checks
            // whether the tap actually landed close enough to collect (BlockProximitySystem's
            // isInRange), so a tap on a too-far block is just ignored, not an error.
            let tappedEntity = arView.entity(at: location)
            if let tappedEntity {
                viewModel.handleBlockTapped(tappedEntity)
            }
            return
        }

        // Converts the tap into a 3D point on the table. ARView has no unproject(...ontoPlane:)
        // equivalent to RealityViewCameraContent's, so this casts a ray through the tapped screen
        // point (ARView.ray(through:)) and intersects it with the table's plane manually — same
        // result RealityViewCameraContent.unproject(...ontoPlane:) used to give directly. Only
        // relevant during .scanningTable; confirmPlacement no-ops once already placed.
        guard viewModel.isTableReadyToPlace else { return }
        guard let ray = arView.ray(through: location) else { return }
        let planeTransform = viewModel.scannedTable.transformMatrix(relativeTo: nil)
        guard let tappedPoint = Self.intersect(ray: ray, withPlane: planeTransform) else { return }
        viewModel.confirmPlacement(at: tappedPoint)
    }


    private static func intersect(
        ray: (origin: SIMD3<Float>, direction: SIMD3<Float>),
        withPlane planeTransform: simd_float4x4
    ) -> SIMD3<Float>? {
        let planePoint = SIMD3<Float>(planeTransform.columns.3.x, planeTransform.columns.3.y, planeTransform.columns.3.z)
        let planeNormal = normalize(SIMD3<Float>(planeTransform.columns.1.x, planeTransform.columns.1.y, planeTransform.columns.1.z))

        let denominator = simd_dot(ray.direction, planeNormal)
        guard abs(denominator) > 1e-6 else { return nil }

        let t = simd_dot(planePoint - ray.origin, planeNormal) / denominator
        guard t >= 0 else { return nil }

        return ray.origin + ray.direction * t
    }
}

#Preview {
    ContentView()
}
