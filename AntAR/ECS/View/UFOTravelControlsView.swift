//
//  UFOTravelControlsView.swift
//  AntAR
//

import SwiftUI

/// Presentation-only controls for state 10. Every action writes ECS intent through the view
/// model; this view never changes a RealityKit entity transform or follower component directly.
struct UFOTravelControlsView: View {
    @Bindable var viewModel: ARExperienceViewModel
    let onInspectUFO: () -> Void

    var body: some View {
        VStack(spacing: 10) {
            IRIntensityPanel(viewModel: viewModel)

            if !viewModel.isInspectingUFO {
                HStack(spacing: 12) {
                    Button {
                        viewModel.requestUFOReset()
                    } label: {
                        Label("Atur ulang", systemImage: "arrow.counterclockwise")
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

                Button(action: onInspectUFO) {
                    Label("Atur sensor di bawah UFO", systemImage: "rotate.3d")
                        .font(.subheadline.weight(.semibold))
                        .frame(maxWidth: .infinity)
                        .frame(height: 42)
                }
                .buttonStyle(.borderedProminent)
                .tint(.cyan.opacity(0.76))
            }
        }
    }
}

/// A readable screen-space control that follows the projected UFO while its ECS inspection pose
/// exposes the physical sensors underneath. This is used instead of tiny 3D text/buttons, which
/// are difficult to hit reliably through an iPhone AR camera.
struct UFOSensorInspectionView: View {
    @Bindable var viewModel: ARExperienceViewModel

    var body: some View {
        VStack(spacing: 9) {
            Image(systemName: "arrowtriangle.up.fill")
                .font(.caption)
                .foregroundStyle(.cyan)

            Text("SENSOR IR DI BAWAH UFO")
                .font(.caption2.monospaced().weight(.bold))
                .foregroundStyle(.white.opacity(0.72))

            HStack(spacing: 10) {
                sensorButton(systemImage: "minus") {
                    viewModel.setIRSensorCount(viewModel.sensorCount - 1)
                }
                .disabled(viewModel.sensorCount <= IRSensorLayout.minimumCount)

                VStack(spacing: 0) {
                    Text("\(viewModel.sensorCount)")
                        .font(.title2.monospacedDigit().weight(.bold))
                    Text("sensor")
                        .font(.caption2)
                        .foregroundStyle(.white.opacity(0.62))
                }
                .frame(minWidth: 58)

                sensorButton(systemImage: "plus") {
                    viewModel.setIRSensorCount(viewModel.sensorCount + 1)
                }
                .disabled(viewModel.sensorCount >= IRSensorLayout.maximumCount)
            }

            Button {
                viewModel.finishUFOInspection()
            } label: {
                Text(viewModel.isFinishingUFOInspection ? "Mengembalikan…" : "Selesai")
                    .font(.subheadline.weight(.bold))
                    .frame(maxWidth: .infinity)
                    .frame(height: 34)
            }
            .buttonStyle(.borderedProminent)
            .tint(.cyan)
            .disabled(viewModel.isFinishingUFOInspection)
        }
        .foregroundStyle(.white)
        .padding(12)
        .frame(width: 220)
        .background(.black.opacity(0.82), in: RoundedRectangle(cornerRadius: 18))
        .overlay {
            RoundedRectangle(cornerRadius: 18)
                .stroke(.cyan.opacity(0.65), lineWidth: 1)
        }
        .shadow(color: .black.opacity(0.35), radius: 10, y: 5)
    }

    private func sensorButton(
        systemImage: String,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            Image(systemName: systemImage)
                .font(.headline.weight(.bold))
                .frame(width: 42, height: 38)
        }
        .buttonStyle(.borderedProminent)
        .tint(.white.opacity(0.20))
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
            Text(isPressed ? "PEDAL AKTIF" : "TAHAN PEDAL GAS")
                .font(.system(.caption, design: .monospaced).weight(.bold))
            Text(isPressed ? "lepas untuk berhenti" : "tahan untuk jalan")
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
        .contentShape(RoundedRectangle(cornerRadius: 15, style: .continuous))
        .gesture(
            DragGesture(minimumDistance: 0)
                .onChanged { _ in onPress() }
                .onEnded { _ in onRelease() }
        )
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Pedal gas")
        .accessibilityValue(isPressed ? "Ditekan" : "Dilepas")
    }
}

private struct IRIntensityPanel: View {
    @Bindable var viewModel: ARExperienceViewModel

    private var routeStatus: (text: String, color: Color) {
        switch viewModel.ufoStallReason {
        case .noPath:
            ("TIDAK ADA BALOK", .orange)
        case .lightBlockReflectsIR:
            ("BALOK TIDAK GELAP", .yellow)
        case nil where viewModel.isIRLineDetected:
            ("JALUR TERDETEKSI", .green)
        case nil:
            ("JALUR HILANG", .red)
        }
    }

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
                Text(routeStatus.text)
                    .font(.caption2.monospaced().weight(.bold))
                    .foregroundStyle(routeStatus.color)
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
                Text(String(format: "GALAT %+.2f", viewModel.irLinePosition))
                Spacer()
                Text(String(format: "MOTOR Ki %02.0f%% Ka %02.0f%%", viewModel.leftMotorPower * 100, viewModel.rightMotorPower * 100))
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
