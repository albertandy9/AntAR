//
//  ContentView.swift
//  AntAR
//
//  SwiftUI owns the presentation layer only. AR anchors, ECS registration, and
//  game-state events are owned by ARExperienceViewModel and the ECS runtime.
//

import AVFoundation
import ARKit
import RealityKit
import SwiftUI

struct ContentView: View {
    @State private var viewModel = ARExperienceViewModel()
    @State private var arView: ARView?
    @State private var hasStartedExperience = false
    @State private var isCameraAuthorized = false
    @State private var realityViewFrame: CGRect = .zero
    @State private var inventoryFrame: CGRect = .zero
    @State private var draggedInventoryBlockID: String?
    @State private var draggedPlacedBlockID: String?
    @State private var isInventoryReturnTargeted = false
    @State private var isStoryDialoguePresented = false

    private var isInteractionBlockedByDialogue: Bool {
        isStoryDialoguePresented
            || viewModel.isShowingBoardHint
            || viewModel.activeTravelDialogue != nil
    }

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
                        DragGesture(minimumDistance: 0)
                            .onChanged(handlePlacedBlockDragChanged)
                            .onEnded(handlePlacedBlockDragEnded)
                    )
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

            if viewModel.gameState.supportsRouteBuilding {
                VStack {
                    HStack {
                        BlockInventoryView(
                            collectedBlocks: viewModel.collectedBlocks,
                            isReturnTargeted: isInventoryReturnTargeted,
                            selectedBlockID: draggedInventoryBlockID,
                            onBlockDragChanged: handleInventoryBlockDragChanged,
                            onBlockDragEnded: handleInventoryBlockDragEnded
                        )
                        .onGeometryChange(for: CGRect.self) { geometry in
                            geometry.frame(in: .global)
                        } action: { frame in
                            inventoryFrame = frame
                        }
                        Spacer()
                    }
                    Spacer()
                }
                .padding(.top, 150)
                .padding(.leading, 16)
            }

            VStack {
                GameOverlayView(
                    state: viewModel.gameState,
                    isTableReadyToPlace: viewModel.isTableReadyToPlace,
                    lostAntGreetPhase: viewModel.lostAntGreetPhase,
                    isCoachingOverlayActive: viewModel.isCoachingOverlayActive,
                    isSurfaceTooSmall: viewModel.hasFoundUndersizedTable,
                    surfaceDistanceStatus: viewModel.surfaceDistanceStatus,
                    isGasPedalPressed: viewModel.isGasPedalPressed
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

                if viewModel.isBlockTooFarWarning {
                    BlockOutOfRangeBanner()
                        .transition(.opacity)
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
            .animation(.easeInOut(duration: 0.2), value: viewModel.isBlockTooFarWarning)

            if isInteractionBlockedByDialogue {
                Color.clear
                    .contentShape(Rectangle())
                    .ignoresSafeArea()
                    .onTapGesture { }
                    .accessibilityHidden(true)
            }

            StoryBubbleSequenceView(
                lostAntGreetPhase: viewModel.lostAntGreetPhase,
                hasTappedUFO: viewModel.hasTappedUFO,
                isPresentingDialogue: $isStoryDialoguePresented,
                onUFOStoryDismissed: { viewModel.beginAntBoardingIfNeeded() },
                onAntDialogueDismissed: { viewModel.confirmAntDialogueDismissed() },
                onAntDialogueStarted: { viewModel.playInitialAntTalkingSound() }
            )

            if viewModel.isShowingBoardHint {
                BoardHintBubbleView(
                    message: viewModel.boardHintMessage,
                    onDismiss: viewModel.dismissBoardHint
                )
            }

            if let dialogue = viewModel.activeTravelDialogue {
                UFOTravelDialogueView(
                    dialogue: dialogue,
                    onComplete: { viewModel.completeTravelDialogue(dialogue) }
                )
                .id(dialogue)
            }

            if viewModel.isInspectingUFO {
                VStack {
                    HStack {
                        Spacer()
                        UFOSensorInspectionView(viewModel: viewModel)
                    }
                    Spacer()
                }
                .padding(.top, 72)
                .padding(.trailing, 16)
                .ignoresSafeArea()
            }

            if viewModel.isShowingSensorCountHint {
                SensorCountHintView(onDismiss: viewModel.dismissSensorCountHint)
            }

            if viewModel.isCompletionCardPresented,
               let cardPosition = viewModel.completionCardScreenPosition {
                GeometryReader { _ in
                    LevelCompletedView(
                        onHome: returnToHome,
                        onRestart: viewModel.restartFromBlockFinding
                    )
                    .scaleEffect(viewModel.completionCardScale)
                    .position(cardPosition)
                }
                .ignoresSafeArea()
                .transition(.scale(scale: 0.8).combined(with: .opacity))
            }
        }
        .task {
            isCameraAuthorized = await AVCaptureDevice.requestAccess(for: .video)
        }
        .onChange(of: isInteractionBlockedByDialogue) { _, isBlocked in
            guard isBlocked else { return }
            cancelGameplayInteractions()
        }
        .animation(.easeInOut(duration: 0.2), value: viewModel.activeTravelDialogue)
        .animation(.spring(duration: 0.45), value: viewModel.isCompletionCardPresented)
    }

    private func returnToHome() {
        arView?.session.pause()
        arView = nil
        viewModel = ARExperienceViewModel()
        realityViewFrame = .zero
        inventoryFrame = .zero
        draggedInventoryBlockID = nil
        draggedPlacedBlockID = nil
        isInventoryReturnTargeted = false
        isStoryDialoguePresented = false
        hasStartedExperience = false
    }

    private func handlePlacedBlockDragChanged(_ value: DragGesture.Value) {
        guard !isInteractionBlockedByDialogue else { return }

        if draggedPlacedBlockID == nil {
            guard let arView,
                  let hitEntity = arView.entity(at: value.startLocation),
                  let blockID = viewModel.placedBlockID(containing: hitEntity),
                  viewModel.canReturnPlacedBlockToInventory(blockID: blockID) else {
                return
            }

            draggedPlacedBlockID = blockID
            viewModel.setPlacedBlockHoldActive(true, blockID: blockID)
        }

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

        viewModel.setPlacedBlockHoldActive(false, blockID: blockID)
        if shouldReturn {
            viewModel.returnPlacedBlockToInventory(blockID: blockID)
        }

        draggedPlacedBlockID = nil
        isInventoryReturnTargeted = false
    }

    private func handleInventoryBlockDragChanged(blockID: String, location: CGPoint) {
        guard !isInteractionBlockedByDialogue else { return }
        draggedInventoryBlockID = blockID
    }

    private func handleInventoryBlockDragEnded(
        blockID: String,
        location: CGPoint,
        translation: CGSize
    ) {
        defer { draggedInventoryBlockID = nil }
        guard !isInteractionBlockedByDialogue else { return }

        let dragDistance = hypot(translation.width, translation.height)
        guard dragDistance >= 8,
              realityViewFrame.contains(location),
              !inventoryFrame.insetBy(dx: -12, dy: -12).contains(location) else {
            return
        }
        viewModel.placeBlockInFrontOfUFO(blockID: blockID)
    }

    private func cancelGameplayInteractions() {
        if let blockID = draggedPlacedBlockID {
            viewModel.setPlacedBlockHoldActive(false, blockID: blockID)
        }
        draggedPlacedBlockID = nil
        draggedInventoryBlockID = nil
        isInventoryReturnTargeted = false
        viewModel.forceGasPedalNeutral()
    }

    private func handleTap(at location: CGPoint) {
        guard !isInteractionBlockedByDialogue, let arView else { return }

        if viewModel.gameState == .ufoAppears {
            if let tappedEntity = arView.entity(at: location) {
                viewModel.handleUFOTapped(tappedEntity)
            }
            return
        }

        if viewModel.gameState.supportsRouteBuilding {
            if let tappedEntity = arView.entity(at: location) {
                if viewModel.handleTravelUFOTapped(tappedEntity) { return }
                if viewModel.placedBlockID(containing: tappedEntity) != nil { return }
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
