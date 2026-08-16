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
    @State private var realityViewFrame: CGRect = .zero
    @State private var inventoryFrame: CGRect = .zero
    @State private var draggedPlacedBlockID: String?
    @State private var isInventoryReturnTargeted = false

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
                    if viewModel.canControlUFO {
                        viewModel.refreshIRTelemetry()
                    }
                    if viewModel.isInspectingUFO, let latestContent {
                        viewModel.refreshUFOInspectionProjection(using: latestContent)
                    }
                }
            }
            .onGeometryChange(for: CGRect.self) { geometry in
                geometry.frame(in: .global)
            } action: { frame in
                realityViewFrame = frame
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
            .simultaneousGesture(
                DragGesture(minimumDistance: 12)
                    .onChanged(handlePlacedBlockDragChanged)
                    .onEnded(handlePlacedBlockDragEnded)
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

                if !viewModel.collectedBlocks.isEmpty || viewModel.hasPlacedBlocks {
                    BlockInventoryView(
                        collectedBlocks: viewModel.collectedBlocks,
                        isReturnTargeted: isInventoryReturnTargeted
                    )
                        .onGeometryChange(for: CGRect.self) { geometry in
                            geometry.frame(in: .global)
                        } action: { frame in
                            inventoryFrame = frame
                        }
                        .padding(.bottom, 24)
                }

                if viewModel.canControlUFO {
                    UFOTravelControlsView(
                        viewModel: viewModel,
                        onInspectUFO: viewModel.beginUFOInspection
                    )
                        .padding(.horizontal, 16)
                        .padding(.bottom, 24)
                }
            }

            if viewModel.isInspectingUFO {
                GeometryReader { geometry in
                    UFOSensorInspectionView(viewModel: viewModel)
                        .position(inspectionControlPosition(in: geometry.size))
                }
                .ignoresSafeArea()
            }
        }
    }

    private func handlePlacedBlockDragChanged(_ value: DragGesture.Value) {
        if draggedPlacedBlockID == nil {
            guard let content = latestContent,
                  let hitEntity = content.entity(at: value.startLocation, in: .local),
                  let blockID = viewModel.placedBlockID(containing: hitEntity) else {
                return
            }

            draggedPlacedBlockID = blockID
            viewModel.setPlacedBlockDragActive(true, blockID: blockID)
        }

        guard draggedPlacedBlockID != nil else { return }
        let globalLocation = CGPoint(
            x: realityViewFrame.minX + value.location.x,
            y: realityViewFrame.minY + value.location.y
        )
        isInventoryReturnTargeted = inventoryFrame
            .insetBy(dx: -24, dy: -24)
            .contains(globalLocation)
    }

    private func handlePlacedBlockDragEnded(_ value: DragGesture.Value) {
        guard let blockID = draggedPlacedBlockID else {
            isInventoryReturnTargeted = false
            return
        }

        let globalLocation = CGPoint(
            x: realityViewFrame.minX + value.location.x,
            y: realityViewFrame.minY + value.location.y
        )
        let shouldReturn = inventoryFrame
            .insetBy(dx: -24, dy: -24)
            .contains(globalLocation)

        viewModel.setPlacedBlockDragActive(false, blockID: blockID)
        if shouldReturn {
            viewModel.returnPlacedBlockToInventory(blockID: blockID)
        }

        draggedPlacedBlockID = nil
        isInventoryReturnTargeted = false
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

        if viewModel.gameState.supportsRouteBuilding {
            // Same 3D entity hit-test as the UFO tap above. handleBlockTapped() itself checks
            // whether the tap actually landed close enough to collect (BlockProximitySystem's
            // isInRange), so a tap on a too-far block is just ignored, not an error.
            let tappedEntity = content.entity(at: location, in: .local)
            if let tappedEntity {
                if viewModel.handleTravelUFOTapped(tappedEntity) { return }
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

    private func inspectionControlPosition(in size: CGSize) -> CGPoint {
        let ufoPosition = viewModel.ufoInspectionScreenPosition
            ?? CGPoint(x: size.width / 2, y: size.height * 0.38)
        let halfPanelWidth: CGFloat = 118
        let panelHalfHeight: CGFloat = 105
        return CGPoint(
            x: min(max(ufoPosition.x, halfPanelWidth), size.width - halfPanelWidth),
            y: min(max(ufoPosition.y + 125, panelHalfHeight), size.height - panelHalfHeight)
        )
    }
}

#Preview {
    ContentView()
}
