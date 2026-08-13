//
//  ContentView.swift
//  AntAR
//
//  SwiftUI owns the presentation layer only. AR anchors, ECS registration, and
//  game-state events are owned by ARExperienceViewModel and the ECS runtime.
//

import SwiftUI

struct ContentView: View {
    @State private var viewModel = ARExperienceViewModel()

    var body: some View {
        ZStack(alignment: .top) {
            ARPlacementView(viewModel: viewModel)
                .ignoresSafeArea()

            GameInstructionBanner(state: viewModel.gameState)
                .padding(.top, 24)

            if let prompt = viewModel.placementStatus.prompt {
                PlacementPrompt(text: prompt)
            }

            if viewModel.placementStatus == .placed,
               viewModel.gameState == .ufoTravelling || viewModel.gameState == .completed {
                UFOTestControls(viewModel: viewModel)
            }
        }
    }
}

/// State-10 learning HUD: live analog readings mirror the supplied HTML visualizer while the
/// existing controls let the team force reflection and tune the sensor-array size on device.
private struct UFOTestControls: View {
    @Bindable var viewModel: ARExperienceViewModel

    var body: some View {
        VStack(spacing: 10) {
            Spacer()

            IRIntensityPanel(viewModel: viewModel)

            HStack(alignment: .bottom, spacing: 12) {
                Button {
                    viewModel.requestUFOReset()
                } label: {
                    Label("Reset", systemImage: "arrow.counterclockwise")
                        .font(.headline)
                        .frame(height: 58)
                }
                .buttonStyle(.bordered)
                .tint(.white)

                if viewModel.gameState == .ufoTravelling {
                    GasPedal(
                        isPressed: viewModel.isGasPedalPressed,
                        onPress: { viewModel.setGasPedalPressed(true) },
                        onRelease: { viewModel.setGasPedalPressed(false) }
                    )
                } else {
                    Text("Tekan Reset untuk mengulang perjalanan UFO")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.white.opacity(0.76))
                        .multilineTextAlignment(.center)
                        .frame(maxWidth: .infinity)
                        .frame(height: 62)
                        .background(.black.opacity(0.60), in: RoundedRectangle(cornerRadius: 15))
                }
            }

            if viewModel.gameState == .ufoTravelling {
                HStack(spacing: 10) {
                    Button(viewModel.isSecondTileLight
                        ? "Jalur 2: Terang — ubah ke gelap & ulangi"
                        : "Uji IR: ubah Jalur 2 ke terang") {
                        viewModel.toggleSecondTileIRTest()
                    }
                    .buttonStyle(.bordered)

                    Stepper("Sensor: \(viewModel.sensorCount)", value: $viewModel.sensorCount, in: 2...8) { _ in
                        viewModel.setIRSensorCount(viewModel.sensorCount)
                    }
                    .fixedSize()
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.bottom, 30)
    }
}

private struct GasPedal: View {
    let isPressed: Bool
    let onPress: () -> Void
    let onRelease: () -> Void

    var body: some View {
        VStack(spacing: 2) {
            Image(systemName: "arrowtriangle.up.fill")
                .font(.caption)
            Text(isPressed ? "THROTTLE ON" : "HOLD GAS PEDAL")
                .font(.system(.caption, design: .monospaced).weight(.bold))
            Text(isPressed ? "lepas untuk pause" : "tahan untuk jalan")
                .font(.caption2)
                .foregroundStyle(.white.opacity(0.70))
        }
        .foregroundStyle(.white)
        .frame(maxWidth: .infinity)
        .frame(height: 62)
        .background(
            isPressed ? Color.orange.opacity(0.90) : Color.red.opacity(0.78),
            in: RoundedRectangle(cornerRadius: 15, style: .continuous)
        )
        .overlay {
            RoundedRectangle(cornerRadius: 15, style: .continuous)
                .stroke(.white.opacity(0.45), lineWidth: 1)
        }
        .contentShape(RoundedRectangle(cornerRadius: 15, style: .continuous))
        .gesture(
            DragGesture(minimumDistance: 0)
                .onChanged { _ in onPress() }
                .onEnded { _ in onRelease() }
        )
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Gas pedal")
        .accessibilityValue(isPressed ? "Pressed" : "Released")
        .accessibilityHint("Hold to move the UFO. Release to pause it.")
    }
}

private struct IRIntensityPanel: View {
    @Bindable var viewModel: ARExperienceViewModel

    var body: some View {
        VStack(spacing: 9) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("INTENSITAS GARIS IR")
                        .font(.caption2.monospaced().weight(.semibold))
                        .foregroundStyle(.white.opacity(0.68))
                    Text("Gelap menyerap IR → aktivasi lebih tinggi")
                        .font(.caption2)
                        .foregroundStyle(.white.opacity(0.52))
                }

                Spacer()

                Text(viewModel.isIRLineDetected ? "LINE LOCKED" : "LINE LOST")
                    .font(.caption2.monospaced().weight(.bold))
                    .foregroundStyle(viewModel.isIRLineDetected ? Color.green : Color.red)
            }

            HStack(alignment: .bottom, spacing: 7) {
                ForEach(viewModel.irLineActivations.indices, id: \.self) { index in
                    IRIntensityBar(
                        sensorIndex: index,
                        activation: viewModel.irLineActivations[index]
                    )
                }
            }
            .frame(maxWidth: .infinity)

            HStack {
                Text(String(format: "ERROR %+.2f", viewModel.irLinePosition))
                Spacer()
                Text(String(format: "MOTOR L %02.0f%%", viewModel.leftMotorPower * 100))
                Text(String(format: "R %02.0f%%", viewModel.rightMotorPower * 100))
            }
            .font(.caption2.monospaced())
            .foregroundStyle(.white.opacity(0.68))
        }
        .padding(12)
        .background(.black.opacity(0.76), in: RoundedRectangle(cornerRadius: 15))
        .overlay {
            RoundedRectangle(cornerRadius: 15)
                .stroke(.white.opacity(0.12), lineWidth: 1)
        }
    }
}

private struct IRIntensityBar: View {
    let sensorIndex: Int
    let activation: Float

    private var clampedActivation: CGFloat {
        CGFloat(min(max(activation, 0), 1))
    }

    var body: some View {
        VStack(spacing: 4) {
            Circle()
                .fill(activation >= IRLineFollowingPolicy.digitalThreshold
                    ? Color(red: 1, green: 0.25, blue: 0.12)
                    : Color.white.opacity(0.16))
                .frame(width: 6, height: 6)
                .shadow(
                    color: activation >= IRLineFollowingPolicy.digitalThreshold
                        ? .red.opacity(0.9)
                        : .clear,
                    radius: 4
                )

            GeometryReader { geometry in
                let fillHeight = max(2, geometry.size.height * clampedActivation)

                ZStack(alignment: .bottom) {
                    RoundedRectangle(cornerRadius: 5)
                        .fill(Color.white.opacity(0.08))

                    RoundedRectangle(cornerRadius: 4)
                        .fill(
                            LinearGradient(
                                colors: [
                                    Color(red: 1, green: 0.65, blue: 0.35),
                                    Color(red: 1, green: 0.18, blue: 0.08),
                                    Color(red: 0.60, green: 0.04, blue: 0.02)
                                ],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )
                        .frame(height: fillHeight)

                    Rectangle()
                        .fill(Color.cyan.opacity(0.72))
                        .frame(height: 1)
                        .position(
                            x: geometry.size.width / 2,
                            y: geometry.size.height
                                * (1 - CGFloat(IRLineFollowingPolicy.digitalThreshold))
                        )
                }
            }
            .frame(height: 70)

            Text("\(Int(clampedActivation * 100))%")
                .font(.system(size: 9, weight: .medium, design: .monospaced))
                .foregroundStyle(.white)
            Text("S\(sensorIndex + 1)")
                .font(.system(size: 9, design: .monospaced))
                .foregroundStyle(.white.opacity(0.55))
        }
        .frame(maxWidth: 34)
    }
}

private struct PlacementPrompt: View {
    let text: String

    var body: some View {
        VStack {
            Spacer()
            Text(text)
                .font(.body.weight(.semibold))
                .foregroundStyle(.white)
                .multilineTextAlignment(.center)
                .padding(16)
                .background(.black.opacity(0.68), in: RoundedRectangle(cornerRadius: 16))
                .padding(.horizontal, 24)
                .padding(.bottom, 44)
        }
        .allowsHitTesting(false)
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
