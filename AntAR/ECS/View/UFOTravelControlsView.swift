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
            if !viewModel.isInspectingUFO {
                if viewModel.sensorLearningPhase == .baseline {
                    // Placeholder untuk Label baseline
                } else if viewModel.isSensorUpgradeRecommended {
                    // Placeholder untuk Label warning
                }
            }

            // Bottom-aligned, not center — pedal reads lower than the panel's header row, matching
            // the reference more closely than sharing a vertical center did.
            HStack(alignment: .bottom, spacing: 12) {
                IRIntensityPanel(viewModel: viewModel)

                // Keep the pedal's layout slot while the sensor panel is open. Removing it from
                // the HStack changed the stack width and visibly shifted the IR panel sideways.
                GasPedal(
                    isPressed: viewModel.isGasPedalPressed,
                    isEnabled: !viewModel.isInspectingUFO,
                    onPress: { viewModel.setGasPedalPressed(true) },
                    onRelease: { viewModel.setGasPedalPressed(false) }
                )
                .opacity(viewModel.isInspectingUFO ? 0 : 1)
                .accessibilityHidden(viewModel.isInspectingUFO)
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

            if viewModel.isSensorUpgradeRecommended {
                Text("TAMBAHKAN SENSOR UNTUK MENINGKATKAN STABILITAS")
                    .font(.caption2.monospaced().weight(.bold))
                    .foregroundStyle(.yellow)
                    .multilineTextAlignment(.center)
            }

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
            .disabled(
                viewModel.isFinishingUFOInspection
            )
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

/// Round pedal button — Teks "PLAY" dipertahankan, ukuran diperkecil relatif terhadap panel,
/// dan ditambahkan efek 3D shadow solid di bawahnya sesuai gaya gambar.
private struct GasPedal: View {
    let isPressed: Bool
    let isEnabled: Bool
    let onPress: () -> Void
    let onRelease: () -> Void

    private static let diameter: CGFloat = 72 // Ukuran sedikit diperkecil
    private static let fillColor = Color(red: 0xFD / 255, green: 0xEC / 255, blue: 0xDB / 255)
    private static let borderColor = Color(red: 0xF4 / 255, green: 0x9E / 255, blue: 0x4C / 255)
    // Warna untuk efek bayangan 3D di bagian bawah tombol (orange gelap)
    private static let shadowColor = Color(red: 207 / 255, green: 120 / 255, blue: 51 / 255)
    private static let borderWidth: CGFloat = 3.5 // Dipertebal sedikit agar mirip gambar

    var body: some View {
        ZStack {
            // Efek 3D/Bayangan Solid (tetap di tempat)
            Circle()
                .fill(Self.shadowColor)
                .frame(width: Self.diameter, height: Self.diameter)
                .offset(y: 4)

            // Tombol Utama (Bisa bergerak turun saat ditekan)
            ZStack {
                Circle()
                    .fill(Self.fillColor)
                    .frame(width: Self.diameter, height: Self.diameter)
                    .overlay(Circle().stroke(Self.borderColor, lineWidth: Self.borderWidth))

                Text("PLAY")
                    .font(.system(size: 16, weight: .heavy))
                    .foregroundStyle(Self.borderColor)
            }
            .offset(y: isPressed ? 4 : 0) // Menekan tombol ke bawah menutupi bayangan
        }
        .scaleEffect(isPressed ? 0.94 : 1)
        .animation(.spring(response: 0.2, dampingFraction: 0.6), value: isPressed)
        .contentShape(Circle())
        .gesture(
            DragGesture(minimumDistance: 0)
                .onChanged { _ in onPress() }
                .onEnded { _ in onRelease() }
        )
        .allowsHitTesting(isEnabled)
        .opacity(isEnabled ? 1 : 0.48)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Pedal gas")
        .accessibilityValue(isPressed ? "Ditekan" : "Dilepas")
    }
}

private struct IRIntensityPanel: View {
    @Bindable var viewModel: ARExperienceViewModel

    private static let panelWidth: CGFloat = 278
    private static let horizontalPadding: CGFloat = 18
    private static let minimumBarSpacing: CGFloat = 4
    private static let preferredBarSpacing: CGFloat = 16
    private static let preferredBarWidth: CGFloat = 32

    // Warna disesuaikan persis dengan eyedropper dari gambar desain
    private static let cardFill = Color(red: 114 / 255, green: 69 / 255, blue: 34 / 255)
    private static let cardShadow = Color(red: 56 / 255, green: 29 / 255, blue: 12 / 255) // Bayangan bawah
    private static let titleColor = Color(red: 253 / 255, green: 242 / 255, blue: 232 / 255)

    private var routeStatus: (text: String, color: Color) {
        switch viewModel.ufoStallReason {
        case .noPath:
            return ("NO BLOCKS", .orange)
        case .lightBlockReflectsIR:
            return ("BLOCK IS LIGHT", .yellow)
        case nil where viewModel.isIRLineDetected:
            return ("LINE DETECTED", .green)
        case nil:
            // Warna merah cerah disesuaikan persis dengan gambar ("Not Detected")
            return ("Not Detected", Color(red: 249 / 255, green: 62 / 255, blue: 62 / 255))
        }
    }

    private var sensorCount: Int {
        max(viewModel.irLineActivations.count, 1)
    }

    private var barWidth: CGFloat {
        let availableWidth = Self.panelWidth - (Self.horizontalPadding * 2)
        let totalMinimumSpacing = Self.minimumBarSpacing * CGFloat(max(sensorCount - 1, 0))
        return min(
            Self.preferredBarWidth,
            (availableWidth - totalMinimumSpacing) / CGFloat(sensorCount)
        )
    }

    private var barSpacing: CGFloat {
        guard sensorCount > 1 else { return 0 }
        let availableWidth = Self.panelWidth - (Self.horizontalPadding * 2)
        let remainingWidth = availableWidth - (barWidth * CGFloat(sensorCount))
        return min(
            Self.preferredBarSpacing,
            max(Self.minimumBarSpacing, remainingWidth / CGFloat(sensorCount - 1))
        )
    }

    var body: some View {
        VStack(spacing: 20) {
            HStack {
                Text("Infrared Activation Bar")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(Self.titleColor)
                    .lineLimit(1)
                    .minimumScaleFactor(0.65)

                Spacer(minLength: 12)

                Text(routeStatus.text)
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(routeStatus.color)
                    .lineLimit(1)
                    .minimumScaleFactor(0.65)
            }

            HStack(spacing: barSpacing) {
                ForEach(viewModel.irLineActivations.indices, id: \.self) { index in
                    IRIntensityBar(
                        activation: viewModel.irLineActivations[index],
                        width: barWidth
                    )
                }
            }
        }
        .padding(EdgeInsets(top: 14, leading: 18, bottom: 14, trailing: 18))
        .frame(width: Self.panelWidth)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Self.cardFill)
                // Efek 3D tajam tanpa blur
                .shadow(color: Self.cardShadow, radius: 0, x: 0, y: 6)
        )
    }
}

/// Kapsul tebal dengan titik kecil di atasnya, sesuai bentuk dari referensi gambar.
private struct IRIntensityBar: View {
    let activation: Float
    let width: CGFloat

    // Warna gelap pekat sesuai gambar (latar kapsul)
    private static let trackColor = Color(red: 56 / 255, green: 30 / 255, blue: 11 / 255)
    private static let fillColor = Color(red: 247 / 255, green: 213 / 255, blue: 168 / 255)

    private var clampedActivation: CGFloat {
        CGFloat(min(max(activation, 0), 1))
    }

    var body: some View {
        VStack(spacing: 4) {
            // Dot di atas (Sensor Head)
            Circle()
                .fill(Self.trackColor)
                .frame(width: 11, height: 11)

            // Kapsul Utama — 95 kemarin kepanjangan, 52 lalu kependekan; 72 di tengah-tengah.
            GeometryReader { geometry in
                ZStack(alignment: .bottom) {
                    Capsule()
                        .fill(Self.trackColor)

                    Capsule()
                        .fill(Self.fillColor)
                        .frame(height: max(0, geometry.size.height * clampedActivation))
                }
            }
            .frame(width: width, height: 72)
        }
    }
}

#Preview {
    ZStack {
        Color.black.ignoresSafeArea()
        UFOTravelControlsView(viewModel: ARExperienceViewModel(), onInspectUFO: {})
            .padding()
    }
}
