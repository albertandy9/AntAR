//
//  HapticFeedbackSystem.swift
//  AntAR
//
//  Step 2: Define System (Logic Class).
//  Fires a one-shot haptic tap the first time it sees an entity with an unfired
//  HapticCueComponent, then marks it fired so it never repeats. Knows nothing about WHY an
//  entity got the component — any feature can reuse this by attaching HapticCueComponent to the
//  right entity at the right moment (see ARExperienceViewModel.spawnUFO() for the first use).
//
//  BUG FIXED: this used to call UIImpactFeedbackGenerator directly from update(context:). That
//  silently didn't work (or was unreliable) because Systems run on RealityKit's own simulation
//  loop, not guaranteed to be the main thread — and UIKit's feedback generators are strictly
//  main-thread/UI-actor-only. Now this only posts a notification with the requested
//  style/intensity; ARExperienceViewModel (MainActor) is what actually calls UIKit. Same reason
//  Systems bridge to @Observable state via notifications/polling elsewhere in this app instead
//  of writing it directly.
//
//  Golden rules: Systems don't store entity state themselves (fired/not-fired lives on the
//  Component above); keep update(context:) lightweight — it runs ~90 times/sec.
//

import Foundation
import RealityKit

public struct HapticFeedbackSystem: System {
    private static let hapticQuery = EntityQuery(where: .has(HapticCueComponent.self))

    public init(scene: RealityKit.Scene) {}

    public func update(context: SceneUpdateContext) {
        for entity in context.entities(matching: Self.hapticQuery, updatingSystemWhen: .rendering) {
            guard var cue = entity.components[HapticCueComponent.self], !cue.hasFired else { continue }

            cue.hasFired = true
            entity.components[HapticCueComponent.self] = cue

            NotificationCenter.default.post(
                name: .hapticCueRequested,
                object: nil,
                userInfo: [
                    HapticNotificationKey.style: cue.style.rawValue,
                    HapticNotificationKey.intensity: cue.intensity
                ]
            )
        }
    }
}
