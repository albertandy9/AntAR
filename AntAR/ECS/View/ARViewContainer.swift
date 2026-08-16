//
//  ARViewContainer.swift
//  AntAR
//

import ARKit
import Combine
import RealityKit
import SwiftUI
import UIKit

struct ARViewContainer: UIViewRepresentable {
    let viewModel: ARExperienceViewModel
    @Binding var arView: ARView?

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    func makeUIView(context: Context) -> ARView {
        if let existing = context.coordinator.arView {
            return existing
        }

        let view = ARView(frame: .zero)
        context.coordinator.arView = view


        let coachingOverlay = ARCoachingOverlayView()
        coachingOverlay.session = view.session
        coachingOverlay.goal = .tracking
        coachingOverlay.activatesAutomatically = false
        coachingOverlay.delegate = context.coordinator
        context.coordinator.viewModel = viewModel
        context.coordinator.coachingOverlay = coachingOverlay
        coachingOverlay.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(coachingOverlay)
        NSLayoutConstraint.activate([
            coachingOverlay.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            coachingOverlay.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            coachingOverlay.topAnchor.constraint(equalTo: view.topAnchor),
            coachingOverlay.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])

        let configuration = ARWorldTrackingConfiguration()
        configuration.planeDetection = [.horizontal]
        // .meshWithClassification, not plain .mesh — TableScanOverlayBuilder needs per-face
        // classification (ARMeshGeometry.classification) to find .table-classified triangles.
        // Plain .mesh gives geometry with no classification source at all. Support for the two can
        // differ per device, so each is checked independently rather than assumed from the other.
        if ARWorldTrackingConfiguration.supportsSceneReconstruction(.meshWithClassification) {
            configuration.sceneReconstruction = .meshWithClassification
            print("[ARViewContainer] sceneReconstruction = .meshWithClassification")
        } else if ARWorldTrackingConfiguration.supportsSceneReconstruction(.mesh) {
            configuration.sceneReconstruction = .mesh
            print("[ARViewContainer] sceneReconstruction = .mesh — no per-face classification available, TableScanOverlayBuilder will never find .table faces")
        } else {
            print("[ARViewContainer] sceneReconstruction unsupported on this device — no LiDAR mesh at all")
        }
        view.session.run(configuration)
        context.coordinator.configuration = configuration

        // Autofocus toggles off for the "letakkan tanganmu" hand-catching beat (see the
        // .lostAntGreetPhaseDidChange observer below) — a hand suddenly filling the frame close to
        // the lens otherwise triggers a distracting refocus hunt. Re-running session.run with just
        // isAutoFocusEnabled changed doesn't reset tracking or drop existing anchors.
        context.coordinator.lostAntGreetObserver = NotificationCenter.default.addObserver(
            forName: .lostAntGreetPhaseDidChange,
            object: nil,
            queue: .main
        ) { [weak coordinator = context.coordinator] notification in
            guard let coordinator,
                  let arView = coordinator.arView,
                  let configuration = coordinator.configuration,
                  let rawValue = notification.userInfo?[LostAntGreetNotificationKey.phase] as? String,
                  let phase = LostAntGreetPhase(rawValue: rawValue) else { return }

            // Same phase range LostAntHandOverlayView itself is visible for.
            let wantsAutoFocus = !(phase == .waiting || phase == .rising || phase == .chatting)
            guard configuration.isAutoFocusEnabled != wantsAutoFocus else { return }
            configuration.isAutoFocusEnabled = wantsAutoFocus
            arView.session.run(configuration)
        }

        coachingOverlay.setActive(true, animated: false)
        viewModel.isCoachingOverlayActive = true

        viewModel.setUpScene(in: view.scene)


        context.coordinator.updateSubscription = view.scene.subscribe(to: SceneEvents.Update.self) { [weak viewModel, coordinator = context.coordinator] _ in
            viewModel?.refreshSurfaceReadiness()
            viewModel?.refreshUndersizedTableDetected()
            viewModel?.refreshIRTelemetry()
            viewModel?.refreshUFODirectionIndicator()

            if !coordinator.hasHandedOffFromCoaching,
               let trackingState = coordinator.arView?.session.currentFrame?.camera.trackingState,
               case .normal = trackingState {
                coordinator.hasHandedOffFromCoaching = true
                coordinator.coachingOverlay?.setActive(false, animated: true)
                viewModel?.isCoachingOverlayActive = false
            }


            if !coordinator.hasBuiltTableScanOverlay, viewModel?.isTableReadyToPlace == true {
                coordinator.framesSinceLastOverlayAttempt += 1
                if coordinator.framesSinceLastOverlayAttempt >= 30,
                   let viewModel, let anchors = coordinator.arView?.session.currentFrame?.anchors {
                    coordinator.framesSinceLastOverlayAttempt = 0
                    if let overlay = TableScanOverlayBuilder.build(
                        from: anchors,
                        planeTransform: viewModel.scannedTable.transformMatrix(relativeTo: nil),
                        nearPoint: viewModel.scannedTable.position(relativeTo: nil)
                    ) {
                        coordinator.hasBuiltTableScanOverlay = true
                        viewModel.addTableScanOverlay(overlay)
                    }
                }
            }
        }

        DispatchQueue.main.async {
            self.arView = view
        }

        return view
    }

    func updateUIView(_ uiView: ARView, context: Context) {}

    final class Coordinator: NSObject, ARCoachingOverlayViewDelegate {
        var arView: ARView?
        var coachingOverlay: ARCoachingOverlayView?
        var configuration: ARWorldTrackingConfiguration?
        var updateSubscription: Cancellable?
        var lostAntGreetObserver: NSObjectProtocol?
        var hasHandedOffFromCoaching = false
        var hasBuiltTableScanOverlay = false
        // Starts at 30 (the throttle threshold), not 0, so the very first qualifying frame
        // attempts immediately instead of waiting a full 30 frames before the first try.
        var framesSinceLastOverlayAttempt = 30
        weak var viewModel: ARExperienceViewModel?

        deinit {
            if let lostAntGreetObserver {
                NotificationCenter.default.removeObserver(lostAntGreetObserver)
            }
        }

        // Not load-bearing for the hand-off (that's driven by tracking state in the update
        // subscription above) — kept only so viewModel.isCoachingOverlayActive stays accurate if
        // anything else ever calls setActive on this overlay.
        func coachingOverlayViewDidDeactivate(_ coachingOverlayView: ARCoachingOverlayView) {
            viewModel?.isCoachingOverlayActive = false
        }
    }
}
