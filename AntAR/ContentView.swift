//
//  ContentView.swift
//  AntAR
//
//  View layer (MVVM). Owns no ECS/AR logic itself — that all lives in ARViewModel. This view's
//  jobs: turn on camera pass-through, fill the whole screen with it, hand RealityViewContent to
//  the ViewModel, kick off tracking, and show the scan instruction/done overlay driven by
//  `viewModel.isSurfaceScanned`.
//

import SwiftUI
import RealityKit
import RealityKitContent
import AVFoundation   // for explicit camera permission request

struct ContentView: View {
    @State private var viewModel = ARViewModel()
    // Captured from RealityView's make/update closures so the tap gesture below (which SwiftUI
    // calls independently of those closures) can still reach `unproject(...)`. This is a
    // lightweight proxy/handle struct, not a heavy object — storing and reusing it like this is
    // the standard pattern for RealityView + gesture code.
    @State private var latestContent: RealityViewCameraContent?

    var body: some View {
        ZStack(alignment: .top) {
            RealityView { content in
                // This is what actually turns on the camera background — without it, RealityView
                // renders a plain (black) 3D scene with no camera pass-through.
                content.camera = .spatialTracking
                viewModel.setUpScene(content: content)
                latestContent = content
                // REVERTED: tried `renderingEffects.depthOfField = .enabled` + `cameraTarget` to
                // keep the ant sharp while blurring the background/hand. In practice it blurred
                // the ANT instead — the opposite of what was wanted — so backed out rather than
                // keep guessing at an effect that's making things worse. See the blur explanation
                // in ARViewModel.jumpAntOntoHand()'s header comment for why the hand blur itself
                // is very likely just the phone's real camera autofocus, not something a
                // rendering setting can fix.
            } update: { content in
                latestContent = content
            }
            // Request camera permission as soon as the RealityView appears, THEN start tracking.
            // Without NSCameraUsageDescription in Info.plist, this call is silent and the AR
            // feed never shows — make sure that key exists with a description string.
            .task {
                await AVCaptureDevice.requestAccess(for: .video)
                await viewModel.startTracking()
            }
            .gesture(
                SpatialTapGesture()
                    .onEnded { event in
                        handleTap(at: event.location)
                    }
            )
            .edgesIgnoringSafeArea(.all)

            // MARK: - HUD
            ScanStatusBanner(
                isSurfaceScanned: viewModel.isSurfaceScanned,
                hasPlacedAnts: viewModel.hasPlacedAnts,
                isReadyForHandJump: viewModel.isReadyForHandJump,
                hasJumped: viewModel.hasJumped
            )
            .padding(.top, 24)

            // Purely illustrative guide (not functional hand tracking — see the blur/detection
            // explanations elsewhere in this file and in ARViewModel.jumpAntOntoHand()'s header
            // comment for why real detection isn't in play here). Just shows the user roughly
            // how to hold their hand while `isReadyForHandJump` is true. Wrapped in its own
            // Spacer-padded VStack (rather than relying on the outer ZStack's `.top` alignment)
            // so it actually sits lower on screen, matching the reference image.
            if viewModel.isReadyForHandJump && !viewModel.hasJumped {
                VStack {
                    Spacer()
                    HandGuideOverlay()
                    Spacer().frame(height: 120)
                }
            }
        }
    }

    /// Converts a 2D tap into a 3D point on the detected table, then hands it to the ViewModel.
    /// `unproject(_:from:to:ontoPlane:)` (RealityViewCameraContent, iOS 18+) casts a ray through
    /// the tapped screen point and intersects it with the given plane transform — exactly what's
    /// needed here, since we already know the table's plane (scannedSurfaceAnchor) and just want
    /// where on it the user tapped, without needing a full scene-mesh raycast.
    private func handleTap(at location: CGPoint) {
        guard viewModel.isSurfaceScanned, !viewModel.hasPlacedAnts else { return }
        guard let content = latestContent else { return }
        let planeTransform = viewModel.scannedSurfaceAnchor.transformMatrix(relativeTo: nil)
        guard let tappedPoint = content.unproject(location, from: .local, to: .scene, ontoPlane: planeTransform) else {
            return
        }
        viewModel.spawnAntGroup(atTappedPoint: tappedPoint)
    }
}

/// RC PRO: purely a placeholder guide graphic. Replace the SF Symbol with real hand-outline
/// artwork (matching the reference look — thin outline, glowing fingertip dots) once art
/// direction is ready; this isn't meant to be final UI.
private struct HandGuideOverlay: View {
    @State private var isPulsing = false

    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: "hand.raised")
                .resizable()
                .scaledToFit()
                .frame(width: 140, height: 140)
                .foregroundStyle(.white.opacity(0.85))
                .shadow(color: .white.opacity(0.6), radius: isPulsing ? 18 : 6)
                .scaleEffect(isPulsing ? 1.06 : 0.94)

            Text("telapak menghadap ke kamera")
                .font(.caption.weight(.medium))
                .foregroundStyle(.white.opacity(0.85))
        }
        .allowsHitTesting(false)
        .onAppear {
            withAnimation(.easeInOut(duration: 1.1).repeatForever(autoreverses: true)) {
                isPulsing = true
            }
        }
    }
}

/// RC PRO: purely a placeholder banner so there's *some* instruction on screen for M0. Replace
/// with real copy/visual design once art direction is ready — this isn't meant to be final UI.
private struct ScanStatusBanner: View {
    let isSurfaceScanned: Bool
    let hasPlacedAnts: Bool
    let isReadyForHandJump: Bool
    let hasJumped: Bool

    var body: some View {
        Text(text)
            .font(.callout.weight(.semibold))
            .foregroundStyle(.white)
            .multilineTextAlignment(.center)
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .background(.black.opacity(0.55), in: Capsule())
            .animation(.default, value: isSurfaceScanned)
            .animation(.default, value: hasPlacedAnts)
            .animation(.default, value: isReadyForHandJump)
    }

    private var text: String {
        if hasJumped {
            return "Semut naik ke tanganmu! 🐜"
        } else if isReadyForHandJump {
            return "Ulurkan tanganmu ke depan kamera"
        } else if hasPlacedAnts {
            return "Semut sedang berjalan..."
        } else if isSurfaceScanned {
            return "Meja terdeteksi ✓ — tap di tengah meja"
        } else {
            return "Arahkan kamera ke meja untuk memulai scan"
        }
    }
}

#Preview {
    ContentView()
}
