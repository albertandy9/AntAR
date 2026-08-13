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
    // Captured from RealityView's make closure so the tap gesture (called independently by
    // SwiftUI) can still reach `unproject(...)`. Lightweight proxy struct, not a heavy object.
    @State private var latestContent: RealityViewCameraContent?

    var body: some View {
        ZStack {
            RealityView { content in
                content.camera = .spatialTracking
                viewModel.setUpScene(in: content)
                latestContent = content
                // Polls scannedTable.isAnchored into viewModel.isTableReadyToPlace every frame —
                // Systems can't write @Observable state directly, so this is the bridge.
                _ = content.subscribe(to: SceneEvents.Update.self) { _ in
                    viewModel.refreshSurfaceReadiness()
                }
            }
            .task {
                guard await AVCaptureDevice.requestAccess(for: .video) else { return }
                await viewModel.startTracking()
            }
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

            VStack {
                GameOverlayView(state: viewModel.gameState, isTableReadyToPlace: viewModel.isTableReadyToPlace)
                    .padding(.top, 24)

                Spacer()

                if !viewModel.collectedBlocks.isEmpty {
                    BlockInventoryView(collectedBlocks: viewModel.collectedBlocks)
                        .padding(.bottom, 24)
                }
            }
        }
    }

    /// Same phone-screen tap gesture handles two completely different things depending on
    /// `gameState` — not two gesture recognizers, just a branch on what the tap should mean right
    /// now.
    private func handleTap(at location: CGPoint) {
        guard let content = latestContent else { return }

        if viewModel.gameState == .ufoAppears {
            // Real 3D entity hit-test (content.entity(at:in:), iOS 18+) — different from the
            // table-tap below, which projects onto a known plane rather than hit-testing actual
            // entity geometry. Requires the UFO to have a CollisionComponent, which
            // ARExperienceViewModel.spawnUFO() sets up.
            let tappedEntity = content.entity(at: location, in: .local)
            if let tappedEntity {
                viewModel.handleUFOTapped(tappedEntity)
            }
            return
        }

        if viewModel.gameState == .blocksScattered {
            // Same 3D entity hit-test as the UFO tap above. handleBlockTapped() itself checks
            // whether the tap actually landed close enough to collect (BlockProximitySystem's
            // isInRange), so a tap on a too-far block is just ignored, not an error.
            let tappedEntity = content.entity(at: location, in: .local)
            if let tappedEntity {
                viewModel.handleBlockTapped(tappedEntity)
            }
            return
        }

        // Converts the tap into a 3D point on the table. `unproject(_:from:to:ontoPlane:)`
        // (RealityViewCameraContent, iOS 18+) casts a ray through the tapped screen point and
        // intersects it with the given plane transform — exactly what's needed here, since we
        // already know the table's plane (scannedTable) and just want where on it the user
        // tapped. Only relevant during .scanningTable; confirmPlacement no-ops once already placed.
        guard viewModel.isTableReadyToPlace else { return }
        let planeTransform = viewModel.scannedTable.transformMatrix(relativeTo: nil)
        guard let tappedPoint = content.unproject(location, from: .local, to: .scene, ontoPlane: planeTransform) else {
            return
        }
        viewModel.confirmPlacement(at: tappedPoint)
    }
}

#Preview {
    ContentView()
}
