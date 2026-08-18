//
//  LostAntGreetSystem.swift
//  AntAR
//
//  Step 2: Define System (Logic Class).
//  Drives the .lostAntDialogue "reach your hand toward the ant" beat entirely off
//  LostAntGreetComponent.phaseElapsed — no real hand tracking, just fixed per-phase delays, per
//  the actual request ("we don't track the hand just amount of the delay").
//
//  arrived: the ant has just arrived at restPosition (from the real walk in .antsLeaveFormation)
//  and is settling — nothing shown yet (no hand overlay, no text), ant fully visible and still.
//  arrived -> waiting: the hand overlay + "Letakkan tanganmu" appear the same moment this phase
//  starts, but the ant stays visible through the whole waitDuration wait — it does NOT disappear
//  immediately with the text.
//  waiting -> rising: attaches BillboardComponent (verified real RealityKit API — rotates the
//  entity to face the camera every frame), AND fades opacity to 0 right here (after the wait, not
//  when the text first appeared) — this app never tracks the player's real hand, so RealityKit has
//  no depth information to occlude the ant behind it; rendering it while mid-rise would visibly clip
//  it through the player's real fingers, so it hides for the rise AND the chat wait, then reappears
//  once settled (see chatting -> releasing below) — it must NOT be visible before that.
//
//  risenPosition is NOT computed once and eased toward — it's recomputed every frame during
//  .rising AND .chatting (the ant is invisible through both), directly from the camera's CURRENT
//  position and forward direction (cameraPosition + cameraForward * standoffDistance), and the ant
//  is snapped straight there each frame (see updateRisenPosition(_:ant:camera:)). Since it's
//  invisible the whole time, there's nothing to see "snapping" — and it means whatever the camera's
//  current tilt/orientation is at the exact moment .releasing begins (when it fades back in) is what
//  determines where it appears, not a value snapshotted once much earlier in beginLostAntGreet(). A
//  fixed target computed early (the original approach) also only ever used the camera's horizontal
//  position, never its orientation, so it wasn't reliably centered in view even at the instant it
//  was computed. This is what "always in the center of the screen" actually requires — a static
//  world-space point can't guarantee that regardless of when it's computed, only continuously
//  tracking where the camera is actually pointed can.
//  chatting -> releasing: position tracking STOPS here (frozen at whatever .chatting's last frame
//  computed) — the ant is about to become visible, and continuously re-centering a visible object
//  under the user's finger would look like it's gluing itself to the screen rather than resting in
//  place, so "always centered" really means "centered at the instant it's revealed," not for the
//  ~6s it stays visible afterward. Opacity eases from 0 to 1 over releaseFadeInDuration right as this
//  phase starts, at the same moment "Turunkan tanganmu" appears and the hand overlay disappears
//  (LostAntDialogueView/ContentView key off this same phase change) — the ant reveal, the caption
//  switch, and the hand overlay vanishing are all one simultaneous beat. LostAntChatBubbleView only
//  starts showing dialogue 2s after that reveal, not immediately (ContentView's own delayed
//  .task(id:), not this phase directly) — the ant must sit visible for a beat before it starts
//  talking. The ant stays visible and in place for the rest of releaseDuration.
//  releasing -> returning: eases the ant back down to restPosition ("jump to his origin place" —
//  noticeably quicker than the rise, see returnDuration).
//  returning -> done: reports .lostAntDialogueDismissed directly into GameDirector's
//  GameEventComponent — same direct-write pattern AntWalkSystem/AntBoardSystem already use, no
//  notification bridge needed for this (that's only for calls that specifically require the main
//  thread, like UIKit).
//
//  Every phase transition also posts .lostAntGreetPhaseDidChange so ARExperienceViewModel can
//  mirror the phase into @Observable state for LostAntDialogueView (banner text + hand overlay).
//
//  Golden rules: Systems don't store entity state themselves (phase/timers live on the Component
//  above); keep update(context:) lightweight — it runs ~90 times/sec, and this only ever drives
//  one ant.
//

import Foundation
import RealityKit

public struct LostAntGreetSystem: System {
    private static let greetQuery = EntityQuery(where: .has(LostAntGreetComponent.self))
    private static let directorQuery = EntityQuery(
        where: .has(GameDirectorComponent.self) && .has(GameEventComponent.self)
    )
    private static let cameraQuery = EntityQuery(where: .has(PlayerCameraComponent.self))

    // TUNABLE — all in seconds. arrivedDuration, waitDuration, and chatDuration are the explicitly
    // requested values (5s, 3s, and 5s); riseDuration/returnDuration are reasonable starting points,
    // unvalidated on-device. releaseFadeInDuration is the "small animation" for the ant reappearing
    // (at the START of .releasing — see header comment), instead of an instant pop. releaseDuration
    // is 6s (not the original 5s) to exactly fit ContentView's 2s post-reveal delay before
    // LostAntChatBubbleView appears plus its two dialogue lines at 2s each (2 + 2 + 2 = 6) — see
    // ContentView's .task(id:) and LostAntChatBubbleView.lineDuration.
    private static let arrivedDuration: Float = 3.0
    private static let waitDuration: Float = 3.0
    private static let riseDuration: Float = 1.5
    private static let chatDuration: Float = 5.0
    private static let releaseDuration: Float = 6.0
    private static let releaseFadeInDuration: Float = 0.4
    private static let returnDuration: Float = 0.8
    // How far in front of the camera, along its actual current forward direction, the ant sits
    // once risen — replaces the old fixed vertical lift (no longer needed: the camera's own
    // forward vector already carries whatever vertical tilt it has).
    private static let standoffDistance: Float = 0.35

    public init(scene: RealityKit.Scene) {}

    public func update(context: SceneUpdateContext) {
        let deltaTime = Float(context.deltaTime)
        var camera: Entity?
        for entity in context.entities(matching: Self.cameraQuery, updatingSystemWhen: .rendering) {
            camera = entity
            break
        }

        for ant in context.entities(matching: Self.greetQuery, updatingSystemWhen: .rendering) {
            guard var greet = ant.components[LostAntGreetComponent.self], greet.phase != .done else { continue }

            greet.phaseElapsed += deltaTime

            switch greet.phase {
            case .arrived:
                if greet.phaseElapsed >= Self.arrivedDuration {
                    advance(&greet, to: .waiting, on: ant)
                }

            case .waiting:
                if greet.phaseElapsed >= Self.waitDuration {
                    advance(&greet, to: .rising, on: ant)
                }

            case .rising:
                updateRisenPosition(&greet, ant: ant, camera: camera)
                if greet.phaseElapsed >= Self.riseDuration {
                    advance(&greet, to: .chatting, on: ant)
                }

            case .chatting:
                updateRisenPosition(&greet, ant: ant, camera: camera)
                if greet.phaseElapsed >= Self.chatDuration {
                    advance(&greet, to: .releasing, on: ant)
                }

            case .releasing:
                // Position is NOT updated here — frozen at whatever .chatting's last frame set,
                // since the ant is now visible (fading in below) and continuously re-centering a
                // visible object would look like it's gluing itself to the screen.
                let fadeT = Self.smoothstep(min(greet.phaseElapsed / Self.releaseFadeInDuration, 1))
                if var opacity = ant.components[OpacityComponent.self] {
                    opacity.opacity = fadeT
                    ant.components[OpacityComponent.self] = opacity
                }
                // Also requires isDialogueDismissed (set externally once the player has tapped
                // through both dialogue lines) — releaseDuration alone is a floor, not enough on
                // its own if the player is still reading past it.
                if greet.phaseElapsed >= Self.releaseDuration && greet.isDialogueDismissed {
                    advance(&greet, to: .returning, on: ant)
                }

            case .returning:
                let t = Self.smoothstep(min(greet.phaseElapsed / Self.returnDuration, 1))
                ant.setPosition(simd_mix(greet.risenPosition, greet.restPosition, SIMD3(repeating: t)), relativeTo: nil)
                if greet.phaseElapsed >= Self.returnDuration {
                    advance(&greet, to: .done, on: ant)
                    reportDismissed(context: context)
                }

            case .done:
                break
            }

            ant.components[LostAntGreetComponent.self] = greet
        }
    }

    // Snaps risenPosition (and the invisible ant itself) directly onto wherever the camera is
    // CURRENTLY pointed, every frame — not eased toward a fixed target, since there's nothing to
    // see easing while opacity is 0. See this file's header comment for why this is what "always
    // centered" actually requires.
    private func updateRisenPosition(_ greet: inout LostAntGreetComponent, ant: Entity, camera: Entity?) {
        guard let camera else { return }
        let cameraPosition = camera.position(relativeTo: nil)
        let cameraForward = camera.convert(direction: SIMD3<Float>(0, 0, -1), to: nil)
        greet.risenPosition = cameraPosition + cameraForward * Self.standoffDistance
        ant.setPosition(greet.risenPosition, relativeTo: nil)
    }

    private func advance(_ greet: inout LostAntGreetComponent, to phase: LostAntGreetPhase, on ant: Entity) {
        greet.phase = phase
        greet.phaseElapsed = 0

        if phase == .rising {
            ant.components.set(BillboardComponent())
            // Ant stays visible through the whole .waiting wait (3s — "letakkan tanganmu"
            // appears, THEN a delay, THEN it disappears, not instantly) and only fades out here,
            // right as it starts rising.
            if var opacity = ant.components[OpacityComponent.self] {
                opacity.opacity = 0
                ant.components[OpacityComponent.self] = opacity
            }
        }
        // .releasing's opacity fade-in is progressive (see the .releasing case in update(context:)
        // above), not an instant snap here — that's the "small animation" for the reappearance.

        NotificationCenter.default.post(
            name: .lostAntGreetPhaseDidChange,
            object: nil,
            userInfo: [LostAntGreetNotificationKey.phase: phase.rawValue]
        )
    }

    private func reportDismissed(context: SceneUpdateContext) {
        for director in context.entities(matching: Self.directorQuery, updatingSystemWhen: .rendering) {
            guard var events = director.components[GameEventComponent.self] else { continue }
            events.enqueue(.lostAntDialogueDismissed)
            director.components[GameEventComponent.self] = events
        }
    }

    private static func smoothstep(_ t: Float) -> Float {
        let clamped = min(max(t, 0), 1)
        return clamped * clamped * (3 - 2 * clamped)
    }
}
