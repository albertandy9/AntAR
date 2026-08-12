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

    var body: some View {
        ZStack(alignment: .top) {
            RealityView { content in
                content.camera = .spatialTracking
                viewModel.setUpScene(in: content)
            }
            .task {
                guard await AVCaptureDevice.requestAccess(for: .video) else { return }
                await viewModel.startTracking()
            }
            .ignoresSafeArea()

            GameInstructionBanner(state: viewModel.gameState)
                .padding(.top, 24)
        }
    }
}

/// Temporary state-driven copy for the vertical slice. Move these strings into the content
/// system/localization layer once narration and final UI are authored.
private struct GameInstructionBanner: View {
    let state: GameState

    var body: some View {
        Text(state.instruction)
            .font(.callout.weight(.semibold))
            .foregroundStyle(.white)
            .multilineTextAlignment(.center)
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .background(.black.opacity(0.58), in: Capsule())
            .animation(.default, value: state)
    }
}

#Preview {
    ContentView()
}
