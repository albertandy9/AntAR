//
//  StoryBubbleSequence.swift
//  AntAR
//
//  Created by Albert Tandy Harison on 18/08/26.
//

//
//  StoryBubbleSequenceView.swift
//  AntAR
//
//  Single source of truth for every speech-bubble beat in the story (ant dialogue, UFO story,
//  board-finding hint) — replaces three independently-gated overlays (LostAntChatBubbleView,
//  UFOStoryOverlayView, BoardNeededBubbleView) that could end up on screen at the same time,
//  since each only knew about its own trigger condition. This view owns one shared
//  `currentIndex` across all beats: only the beat at that index is ever shown, and only once its
//  own gate condition is met — advancing to the next beat happens strictly on tap, never by
//  timer, so two beats can never overlap and a beat can never appear out of order.
//
//  Pacing delays (ant dialogue after the hand-drop beat, UFO story after the tap) are implemented
//  with onChange + TimelineView, NOT `.task(id:)` — that pattern was tried earlier for the same
//  purpose and was cancelled/restarted on every phase change, occasionally losing the race
//  entirely and leaving a beat stuck permanently unavailable (reported: ant + caption showed
//  fine, the dialogue bubble silently never did). onChange fires exactly once per transition and
//  can't be cancelled mid-flight; TimelineView re-evaluates on its own schedule regardless of
//  what else is changing, so the elapsed-time check is always working off a fresh clock read.
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

    @State private var currentIndex = 0
    // Set once, the instant each trigger condition first becomes true — the anchor a TimelineView
    // tick measures elapsed time against, not a cancellable timer.
    @State private var releasingStartedAt: Date?
    @State private var ufoTappedAt: Date?
    @State private var blocksScatteredStartedAt: Date?

    var body: some View {
        TimelineView(.periodic(from: .now, by: 0.1)) { timeline in
            content(now: timeline.date)
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

    private func advance() {
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
        let dismissedBeat = Self.beats[currentIndex]
        currentIndex += 1

        let leavingUFOStory = dismissedBeat.kind == .ufoStory
            && (currentIndex >= Self.beats.count || Self.beats[currentIndex].kind != .ufoStory)
        if leavingUFOStory {
            onUFOStoryDismissed()
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
            onUFOStoryDismissed: {}
        )
    }
}
