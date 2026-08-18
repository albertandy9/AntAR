//
//  StoryBubbleSequence.swift
//  AntAR
//
//  Created by Albert Tandy Harison on 18/08/26.
//

import SwiftUI
import UIKit

struct StoryBubbleSequenceView: View {
    let gameState: GameState
    let lostAntGreetPhase: LostAntGreetPhase?
    let hasTappedUFO: Bool
    // Called exactly once, the moment the player dismisses the second UFO story line — the ant
    // boarding animation is meant to start only after that, not automatically the instant the UFO
    // lands. See ARExperienceViewModel.beginAntBoardingIfNeeded's header comment.
    let onUFOStoryDismissed: () -> Void
    // Called exactly once, the moment the player dismisses the second ant-dialogue line — the ant
    // doesn't shrink back down (LostAntGreetSystem's .releasing -> .returning transition) and the
    // player can't start searching for the UFO until this fires. See
    // ARExperienceViewModel.confirmAntDialogueDismissed's header comment.
    let onAntDialogueDismissed: () -> Void
    // Called exactly once, the moment the player dismisses the board-finding hint — ContentView
    // uses this to keep the inventory panel and travel-controls HUD fully hidden until then.
    let onBoardHintDismissed: () -> Void
    // Both already exposed by ARExperienceViewModel for the travel-controls HUD/warning alert —
    // reused here as-is, not new state, to drive the two gas-pedal-result bubbles below.
    let isGasPedalPressed: Bool
    let ufoStallReason: UFOStallReason?

    private struct Beat {
        let text: String
        let position: Position
        let kind: Kind
    }

    private enum Position {
        case bottom // near the ant / general dialogue, safe-area anchored
        case top    // reserved for future top-anchored beats
    }

    private enum Kind {
        case antDialogue
        case ufoStory
        case boardHint
    }

    private static let antDialogueDelay: TimeInterval = 1.5
    private static let ufoStoryDelay: TimeInterval = 1.5
    // The state machine reaches .blocksScattered the instant the ant finishes boarding, but the
    // scene isn't actually ready yet at that exact moment — beginUFOAscendIfNeeded() only starts
    // there, and revealEnvironment() (ground, blocks, grass) doesn't run until UFOAscendComponent
    // finishes rising (UFOAscendComponent.duration, read-only reference to the friend's existing
    // constant — not a new tunable). Gating the board hint on .blocksScattered alone showed it
    // during that ~2s window, telling the player to go find a board before the board-finding world
    // had actually finished revealing itself. A small buffer on top covers the last bit of settle.
    private static let boardHintDelay: TimeInterval = TimeInterval(UFOAscendComponent.duration) + 0.5

    private static let beats: [Beat] = [
        Beat(
            text: "Aku tidak bisa pulang mengikuti rombongan karena antena ku copot",
            position: .bottom,
            kind: .antDialogue
        ),
        Beat(
            text: "Aku memerlukan antena ku untuk mendeteksi jalur perjalananku pulang",
            position: .bottom,
            kind: .antDialogue
        ),
        Beat(
            text: "UFO ini sepertinya bukan UFO biasa...",
            position: .bottom,
            kind: .ufoStory
        ),
        Beat(
            text: "UFO ini memancarkan cahaya inframerah tidak terlihat yang bisa mendeteksi benda.",
            position: .bottom,
            kind: .ufoStory
        ),
        Beat(
            text: "UFO nya belum bisa jalan nih karena memerlukan papan. Yuk coba cari papan dulu.",
            position: .bottom,
            kind: .boardHint
        )
    ]

    // Not part of the sequential `beats`/currentIndex queue above — that queue is a one-time,
    // in-order onboarding sequence. This is reactive gameplay feedback that can legitimately fire
    // again on every retry (place board, hold gas pedal, release), so it's tracked independently.
    // Each case is its own 2-line tap-to-advance sequence (what happened, then why).
    private enum GasPedalResult {
        case success
        case failure

        var lines: [String] {
            switch self {
            case .success:
                return [
                    "Yey UFO berhasil jalan...",
                    "UFO bisa jalan karena sinar inframerah yang dipancarkan berhasil di serap oleh papan."
                ]
            case .failure:
                return [
                    "Eh.. tadi kok jalannya UFO oleng...",
                    "Sepertinya jumlah sensornya perlu disesuaikan. Coba lihat kebawah UFO."
                ]
            }
        }
    }

    @State private var currentIndex = 0
    // Set once, the instant each trigger condition first becomes true — the anchor a TimelineView
    // tick measures elapsed time against, not a cancellable timer.
    @State private var releasingStartedAt: Date?
    @State private var ufoTappedAt: Date?
    @State private var blocksScatteredStartedAt: Date?
    @State private var gasPedalResult: GasPedalResult?
    @State private var gasPedalResultStep = 0
    @State private var wasGasPedalPressed = false
    // True the moment a stall is actually observed during the current hold — read at release
    // time, ufoStallReason was almost always still nil (ARExperienceViewModel only updates it
    // from a ~20Hz ECS refresh, so it regularly lagged behind setGasPedalPressed(false), which
    // fires synchronously the instant the finger lifts). Catching the stall in real time via its
    // own onChange below, instead of re-reading it at release, is what actually fixes that race.
    @State private var stalledDuringThisHold = false

    var body: some View {
        ZStack {
            TimelineView(.periodic(from: .now, by: 0.1)) { timeline in
                content(now: timeline.date)
            }

            if let gasPedalResult {
                gasPedalResultBubble(for: gasPedalResult)
            }
        }
        .onChange(of: lostAntGreetPhase, initial: true) { _, newPhase in
            if releasingStartedAt == nil, Self.hasReached(.releasing, newPhase) {
                releasingStartedAt = Date()
            }
        }
        .onChange(of: hasTappedUFO, initial: true) { _, tapped in
            if tapped, ufoTappedAt == nil {
                ufoTappedAt = Date()
            }
        }
        .onChange(of: gameState, initial: true) { _, newState in
            if blocksScatteredStartedAt == nil, Self.hasReached(.blocksScattered, newState) {
                blocksScatteredStartedAt = Date()
            }
        }
        .onChange(of: isGasPedalPressed) { _, isPressed in
            if isPressed {
                // A fresh attempt — clear any old result and stop tracking the previous hold's
                // stall so it can't leak into this one's outcome.
                stalledDuringThisHold = false
                gasPedalResult = nil
                gasPedalResultStep = 0
            } else if wasGasPedalPressed, !stalledDuringThisHold {
                // Released, and nothing stalled while it was down — that's a clean success.
                gasPedalResult = .success
            }
            wasGasPedalPressed = isPressed
        }
        // The failure case is caught here, in real time, the instant it happens — not by
        // re-reading ufoStallReason at release (see stalledDuringThisHold's comment above).
        .onChange(of: ufoStallReason) { _, reason in
            guard reason != nil, wasGasPedalPressed else { return }
            stalledDuringThisHold = true
            gasPedalResult = .failure
        }
    }

    private func content(now: Date) -> some View {
        Group {
            if currentIndex < Self.beats.count {
                let beat = Self.beats[currentIndex]
                if isAvailable(beat, now: now) {
                    VStack {
                        if beat.position == .top {
                            bubble(for: beat)
                                .padding(.top, 40)
                            Spacer()
                        } else {
                            Spacer()
                            bubble(for: beat)
                                .padding(.bottom, 100)
                        }
                    }
                }
            }
        }
    }

    private func isAvailable(_ beat: Beat, now: Date) -> Bool {
        switch beat.kind {
        case .antDialogue:
            guard let releasingStartedAt else { return false }
            return now.timeIntervalSince(releasingStartedAt) >= Self.antDialogueDelay
        case .ufoStory:
            guard let ufoTappedAt else { return false }
            return now.timeIntervalSince(ufoTappedAt) >= Self.ufoStoryDelay
        case .boardHint:
            guard let blocksScatteredStartedAt else { return false }
            return now.timeIntervalSince(blocksScatteredStartedAt) >= Self.boardHintDelay
        }
    }

    private func bubble(for beat: Beat) -> some View {
        HStack {
            Spacer(minLength: 0)

            // "Group 44" (the fainted ant with its own white oval shadow baked in) only for the
            // ant's own dialogue — the UFO story and board hint beats aren't the ant talking, so
            // they get no avatar at all.
            SpeechBubbleView(
                text: beat.text,
                avatarImageName: beat.kind == .antDialogue ? "Group 44" : nil
            )
            .contentShape(Rectangle())
            .onTapGesture(perform: advance)

            Spacer(minLength: 0)
        }
        // The avatar overlaps outside SpeechBubbleView's own bounds on its top-leading side (see
        // that file's avatarSize/offset math) — a flat margin so it doesn't get clipped by the
        // screen edge on narrower phones/centered layouts.
        .padding(.leading, 24)
        .padding(.trailing, 15)
    }

    /// Same SpeechBubbleView + avatar language as the ant-dialogue beats above, not a separate
    /// popup style — two lines, tap to advance from "what happened" to "why", then tap again to
    /// dismiss. Positioned by screen-height fraction (not a fixed .padding(.bottom, N)) so it
    /// consistently lands just above the Infrared Activation Bar panel regardless of the travel
    /// HUD's actual height, which varies with sensor count/warnings.
    //
    // NOTE: reuses "Group 44" for both outcomes — there's no separate happy/confused ant-bust
    // asset in Assets.xcassets to match the two different expressions shown in the reference
    // images. If those get added (same way the Figma exports like "Group 44" itself were), swap
    // the name below per case.
    private func gasPedalResultBubble(for result: GasPedalResult) -> some View {
        GeometryReader { geometry in
            HStack {
                Spacer(minLength: 0)
                SpeechBubbleView(text: result.lines[gasPedalResultStep], avatarImageName: "Group 44")
                    .contentShape(Rectangle())
                    .onTapGesture { advanceGasPedalResult(result) }
                Spacer(minLength: 0)
            }
            .padding(.leading, 24)
            .padding(.trailing, 15)
            .position(x: geometry.size.width / 2, y: geometry.size.height * 0.44)
        }
    }

    private func advanceGasPedalResult(_ result: GasPedalResult) {
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
        if gasPedalResultStep < result.lines.count - 1 {
            gasPedalResultStep += 1
        } else {
            gasPedalResult = nil
            gasPedalResultStep = 0
        }
    }

    private func advance() {
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
        let dismissedBeat = Self.beats[currentIndex]
        currentIndex += 1

        let leavingUFOStory = dismissedBeat.kind == .ufoStory
            && (currentIndex >= Self.beats.count || Self.beats[currentIndex].kind != .ufoStory)
        if leavingUFOStory {
            onUFOStoryDismissed()
        }

        let leavingAntDialogue = dismissedBeat.kind == .antDialogue
            && (currentIndex >= Self.beats.count || Self.beats[currentIndex].kind != .antDialogue)
        if leavingAntDialogue {
            onAntDialogueDismissed()
        }

        if dismissedBeat.kind == .boardHint {
            onBoardHintDismissed()
        }
    }

    // GameState is already CaseIterable, so its declaration order can be read directly off
    // allCases without touching GameState.swift itself.
    private static func hasReached(_ target: GameState, _ current: GameState) -> Bool {
        guard let targetIndex = GameState.allCases.firstIndex(of: target),
              let currentIndex = GameState.allCases.firstIndex(of: current) else { return false }
        return currentIndex >= targetIndex
    }

    // LostAntGreetPhase isn't CaseIterable, so its declaration order is copied here (read-only,
    // matching LostAntGreetComponent.swift's case list) rather than editing that file.
    private static let lostAntGreetPhaseOrder: [LostAntGreetPhase] = [
        .arrived, .waiting, .rising, .chatting, .releasing, .returning, .done
    ]

    private static func hasReached(_ target: LostAntGreetPhase, _ current: LostAntGreetPhase?) -> Bool {
        guard let current,
              let targetIndex = lostAntGreetPhaseOrder.firstIndex(of: target),
              let currentIndex = lostAntGreetPhaseOrder.firstIndex(of: current) else { return false }
        return currentIndex >= targetIndex
    }
}

#Preview {
    // All three gates already satisfied at appear (.blocksScattered/.releasing/hasTappedUFO:
    // true), so every beat's own delay starts counting immediately instead of waiting on a real
    // game-state transition — tap through to walk all 5 beats: antDialogue (Group 44 avatar) ->
    // ufoStory (no avatar) -> boardHint (no avatar, ~2.5s wait for UFOAscendComponent.duration).
    ZStack {
        Color.gray.ignoresSafeArea()
        StoryBubbleSequenceView(
            gameState: .blocksScattered,
            lostAntGreetPhase: .releasing,
            hasTappedUFO: true,
            onUFOStoryDismissed: {},
            onAntDialogueDismissed: {},
            onBoardHintDismissed: {},
            isGasPedalPressed: false,
            ufoStallReason: nil
        )
    }
}
