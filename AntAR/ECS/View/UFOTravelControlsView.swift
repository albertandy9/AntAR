//
//  UFOTravelControlsView.swift
//  AntAR
//

import SwiftUI

/// Presentation-only controls for state 10. Every action writes ECS intent through the view
/// model; this view never changes a RealityKit entity transform or follower component directly.
struct UFOTravelControlsView: View {
    @Bindable var viewModel: ARExperienceViewModel

    var body: some View {
        VStack(spacing: 10) {
            IRIntensityPanel(viewModel: viewModel)

            HStack(spacing: 12) {
                Button {
                    viewModel.requestUFOReset()
                } label: {
                    Label("Reset", systemImage: "arrow.counterclockwise")
                        .font(.headline)
                        .frame(height: 58)
                }
                .buttonStyle(.bordered)
                .tint(.white)

                GasPedal(
                    isPressed: viewModel.isGasPedalPressed,
                    onPress: { viewModel.setGasPedalPressed(true) },
                    onRelease: { viewModel.setGasPedalPressed(false) }
                )
            }

            Stepper(
                "Sensor: \(viewModel.sensorCount)",
                value: $viewModel.sensorCount,
                in: IRSensorLayout.minimumCount...IRSensorLayout.maximumCount
            ) { _ in
                viewModel.setIRSensorCount(viewModel.sensorCount)
            }
            .foregroundStyle(.white)
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
            .background(.black.opacity(0.62), in: Capsule())
            .fixedSize()
        }
    }
}

/// Round pedal button — same cream/bronze palette as BlockInventoryView's slot container
/// (containerFill/containerBorder there), reusing the "Pedal" asset already added to the catalog.
/// isPressed is shown by scaling down slightly rather than swapping text, since the reference
/// design has no label at all, just the icon.
private struct GasPedal: View {
    let isPressed: Bool
    let onPress: () -> Void
    let onRelease: () -> Void

    private static let diameter: CGFloat = 92
    private static let fillColor = Color(red: 247 / 255, green: 213 / 255, blue: 168 / 255)
    private static let borderColor = Color(red: 201 / 255, green: 140 / 255, blue: 68 / 255)

    var body: some View {
        Image("Pedal")
            .resizable()
            .scaledToFit()
            .padding(Self.diameter * 0.26)
            .frame(width: Self.diameter, height: Self.diameter)
            .background(Self.fillColor, in: Circle())
            .overlay(Circle().stroke(Self.borderColor, lineWidth: 3))
            .scaleEffect(isPressed ? 0.92 : 1)
            .animation(.spring(response: 0.2, dampingFraction: 0.6), value: isPressed)
            .contentShape(Circle())
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { _ in onPress() }
                    .onEnded { _ in onRelease() }
            )
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("Gas pedal")
            .accessibilityValue(isPressed ? "Pressed" : "Released")
    }
}

private struct IRIntensityPanel: View {
    @Bindable var viewModel: ARExperienceViewModel

    var body: some View {
        VStack(spacing: 9) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("AKTIVASI GARIS IR")
                        .font(.caption2.monospaced().weight(.semibold))
                        .foregroundStyle(.white.opacity(0.68))
                    Text("Gelap menyerap IR → aktivasi tinggi")
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

            HStack {
                Text(String(format: "ERROR %+.2f", viewModel.irLinePosition))
                Spacer()
                Text(String(format: "MOTOR L %02.0f%% R %02.0f%%", viewModel.leftMotorPower * 100, viewModel.rightMotorPower * 100))
            }
            .font(.caption2.monospaced())
            .foregroundStyle(.white.opacity(0.68))
        }
        .padding(12)
        .background(.black.opacity(0.76), in: RoundedRectangle(cornerRadius: 15))
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

            GeometryReader { geometry in
                ZStack(alignment: .bottom) {
                    RoundedRectangle(cornerRadius: 5)
                        .fill(Color.white.opacity(0.08))
                    RoundedRectangle(cornerRadius: 4)
                        .fill(
                            LinearGradient(
                                colors: [.orange, .red, Color(red: 0.60, green: 0.04, blue: 0.02)],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )
                        .frame(height: max(2, geometry.size.height * clampedActivation))
                }
            }
            .frame(height: 60)

            Text("\(Int(clampedActivation * 100))%")
                .font(.system(size: 9, weight: .medium, design: .monospaced))
            Text("S\(sensorIndex + 1)")
                .font(.system(size: 9, design: .monospaced))
                .foregroundStyle(.white.opacity(0.55))
        }
        .foregroundStyle(.white)
        .frame(maxWidth: 34)
    }
}

#Preview {
    ZStack {
        Color.black.ignoresSafeArea()
        UFOTravelControlsView(viewModel: ARExperienceViewModel())
            .padding()
    }
}
