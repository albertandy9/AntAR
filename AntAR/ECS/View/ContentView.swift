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
    @State private var arView: ARView?
    @State private var hasStartedExperience = false
    @State private var isCameraAuthorized = false
    @State private var realityViewFrame: CGRect = .zero
    @State private var inventoryFrame: CGRect = .zero
    @State private var draggedPlacedBlockID: String?
    @State private var isInventoryReturnTargeted = false

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
                    .onGeometryChange(for: CGRect.self) { geometry in
                        geometry.frame(in: .global)
                    } action: { frame in
                        realityViewFrame = frame
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
            }

            if let ufoDirection = viewModel.ufoDirection {
                UFODirectionIndicatorView(direction: ufoDirection)
                    .ignoresSafeArea()
            }

            if let ufoPosition = viewModel.ufoTapScreenPosition {
                GeometryReader { _ in
                    UFOAppearsView()
                        .position(ufoPosition)
                }
                .ignoresSafeArea()
                .allowsHitTesting(false)
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

                if let lostAntGreetPhase = viewModel.lostAntGreetPhase,
                   lostAntGreetPhase == .waiting
                    || lostAntGreetPhase == .rising
                    || lostAntGreetPhase == .chatting {
                    LostAntHandOverlayView()
                        .ignoresSafeArea(edges: .bottom)
                }

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

                if viewModel.gameState.supportsRouteBuilding {
                    UFOTravelControlsView(
                        viewModel: viewModel,
                        onInspectUFO: viewModel.beginUFOInspection
                    )
                    .padding(.horizontal, 16)
                    .padding(.bottom, 24)
                }
            }

            StoryBubbleSequenceView(
                lostAntGreetPhase: viewModel.lostAntGreetPhase,
                hasTappedUFO: viewModel.hasTappedUFO,
                onUFOStoryDismissed: { viewModel.beginAntBoardingIfNeeded() },
                onAntDialogueDismissed: { viewModel.confirmAntDialogueDismissed() }
            )

            if viewModel.isShowingBoardHint {
                BoardHintBubbleView(onDismiss: viewModel.dismissBoardHint)
            }

            if viewModel.isInspectingUFO {
                GeometryReader { geometry in
                    UFOSensorInspectionView(viewModel: viewModel)
                        .position(inspectionControlPosition(in: geometry.size))
                }
                .ignoresSafeArea()
            }
        }
        .task {
            isCameraAuthorized = await AVCaptureDevice.requestAccess(for: .video)
        }
        .alert(
            viewModel.travelWarningTitle,
            isPresented: Binding(
                get: { viewModel.travelWarningMessage != nil },
                set: { isPresented in
                    if !isPresented { viewModel.dismissTravelWarning() }
                }
            )
        ) {
            if viewModel.isSensorStabilityWarning {
                Button("Atur sensor") {
                    viewModel.dismissTravelWarning()
                    viewModel.beginUFOInspection()
                }
            }
            Button(viewModel.isSensorStabilityWarning ? "Lanjutkan" : "Mengerti", role: .cancel) {
                viewModel.dismissTravelWarning()
            }
        } message: {
            Text(viewModel.travelWarningMessage ?? "")
        }
    }

    private func handlePlacedBlockDragChanged(_ value: DragGesture.Value) {
        if draggedPlacedBlockID == nil {
            guard let arView,
                  let hitEntity = arView.entity(at: value.startLocation),
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

    private func handleTap(at location: CGPoint) {
        guard let arView else { return }

        if viewModel.gameState == .ufoAppears {
            if let tappedEntity = arView.entity(at: location) {
                viewModel.handleUFOTapped(tappedEntity)
            }
            return
        }

        if viewModel.gameState.supportsRouteBuilding {
            if let tappedEntity = arView.entity(at: location) {
                if viewModel.handleTravelUFOTapped(tappedEntity) { return }
                viewModel.handleBlockTapped(tappedEntity)
            }
            return
        }

        guard viewModel.isTableReadyToPlace,
              let ray = arView.ray(through: location) else {
            return
        }
        let planeTransform = viewModel.scannedTable.transformMatrix(relativeTo: nil)
        guard let tappedPoint = Self.intersect(ray: ray, withPlane: planeTransform) else { return }
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

    private static func intersect(
        ray: (origin: SIMD3<Float>, direction: SIMD3<Float>),
        withPlane planeTransform: simd_float4x4
    ) -> SIMD3<Float>? {
        let planePoint = SIMD3<Float>(
            planeTransform.columns.3.x,
            planeTransform.columns.3.y,
            planeTransform.columns.3.z
        )
        let planeNormal = normalize(
            SIMD3<Float>(
                planeTransform.columns.1.x,
                planeTransform.columns.1.y,
                planeTransform.columns.1.z
            )
        )

        let denominator = simd_dot(ray.direction, planeNormal)
        guard abs(denominator) > 1e-6 else { return nil }

        let distance = simd_dot(planePoint - ray.origin, planeNormal) / denominator
        guard distance >= 0 else { return nil }
        return ray.origin + ray.direction * distance
    }
}

#Preview {
    ContentView()
}
