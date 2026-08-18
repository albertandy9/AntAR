//
//  UFOAppearsView.swift
//  AntAR
//

import SwiftUI

/// The "tap the UFO" instruction — shown only once the UFO is actually found (no direction arrow
/// needed to locate it anymore) and not yet tapped. A short minimum-visible-time floor covers the
/// brief window right as .ufoAppears begins where the UFO hasn't finished spawning yet (masterScene
/// entity lookup not yet resolved) — ufoDirection reads nil then too, same as "found and centered",
/// so without this floor the banner could flash on over an empty/white placeholder for a frame.
struct UFOAppearsView: View {
    let ufoDirection: CGVector?
    let hasTappedUFO: Bool

    @State private var appearedAt = Date()

    private static let minimumSpawnWait: TimeInterval = 1.0

    var body: some View {
        TimelineView(.periodic(from: .now, by: 0.1)) { timeline in
            if isReadyToShow(now: timeline.date) {
                // CaptionPill, not InstructionBanner — matches every other per-state instruction
                // (ScanningTableView's "Arahkan kamera...", "Mundur sedikit...", "Sekarang
                // turunkan tanganmu"), which all use the cream pill, not the dark banner.
                CaptionPill(text: "Ketuk UFO-nya untuk memanggilnya turun")
            }
        }
    }

    private func isReadyToShow(now: Date) -> Bool {
        guard !hasTappedUFO, ufoDirection == nil else { return false }
        return now.timeIntervalSince(appearedAt) >= Self.minimumSpawnWait
    }
}
