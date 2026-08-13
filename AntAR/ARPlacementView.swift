//
//  ARPlacementView.swift
//  AntAR
//

import ARKit
import RealityKit
import SwiftUI

/// The AR camera view for this focused state-10/11 slice.
///
/// RealityKit's automatic plane anchors do not draw a plane or let the user choose one. This
/// wrapper makes that otherwise invisible step explicit: ARCoachingOverlayView teaches the user
/// to scan a horizontal surface, then one tap becomes the sole scene anchor.
struct ARPlacementView: UIViewRepresentable {
    let viewModel: ARExperienceViewModel

    func makeCoordinator() -> Coordinator {
        Coordinator(viewModel: viewModel)
    }

    func makeUIView(context: Context) -> ARView {
        let arView = ARView(frame: .zero)
        arView.automaticallyConfigureSession = false
        context.coordinator.configure(arView)
        return arView
    }

    func updateUIView(_ uiView: ARView, context: Context) {}

    final class Coordinator: NSObject {
        private let viewModel: ARExperienceViewModel

        init(viewModel: ARExperienceViewModel) {
            self.viewModel = viewModel
        }

        func configure(_ arView: ARView) {
            let configuration = ARWorldTrackingConfiguration()
            configuration.planeDetection = [.horizontal]
            arView.session.run(configuration, options: [.resetTracking, .removeExistingAnchors])

            let coachingOverlay = ARCoachingOverlayView()
            coachingOverlay.session = arView.session
            coachingOverlay.goal = .horizontalPlane
            coachingOverlay.activatesAutomatically = true
            coachingOverlay.translatesAutoresizingMaskIntoConstraints = false
            arView.addSubview(coachingOverlay)
            NSLayoutConstraint.activate([
                coachingOverlay.leadingAnchor.constraint(equalTo: arView.leadingAnchor),
                coachingOverlay.trailingAnchor.constraint(equalTo: arView.trailingAnchor),
                coachingOverlay.topAnchor.constraint(equalTo: arView.topAnchor),
                coachingOverlay.bottomAnchor.constraint(equalTo: arView.bottomAnchor)
            ])

            let tap = UITapGestureRecognizer(target: self, action: #selector(handleTap(_:)))
            arView.addGestureRecognizer(tap)
            viewModel.setUpScene(in: arView)
        }

        @objc private func handleTap(_ recognizer: UITapGestureRecognizer) {
            guard let arView = recognizer.view as? ARView else { return }
            let location = recognizer.location(in: arView)

            // Existing geometry keeps the selected location stable. A failed raycast is an
            // actionable signal to continue scanning, not a reason to guess a world position.
            guard let result = arView.raycast(
                from: location,
                allowing: .existingPlaneGeometry,
                alignment: .horizontal
            ).first else {
                viewModel.notePlacementNeedsSurface()
                return
            }

            viewModel.placeScene(at: result, in: arView)
        }
    }
}
