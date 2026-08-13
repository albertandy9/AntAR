//
//  SoundCueSystem.swift
//  AntAR
//
//  Step 2: Define System (Logic Class).
//  SPACE RESERVED for sound engineering — mirrors HapticFeedbackSystem's shape exactly, so it's
//  a drop-in once real audio assets exist. Currently a no-op for every entity, because
//  SoundCueComponent.resourceName is nil until something sets it.
//
//  RC PRO <-> CODE HOOKUP, once you have a clip:
//  1. `AudioFileResource.load(named:from:in:)` loads a clip authored inside a specific RC Pro
//     scene (verified in the SDK) — same idea as loading "ufo_angkat_semut" out of "Scene", e.g.
//     `try AudioFileResource.load(named: "ufo_hum", from: "Scene", in: realityKitContentBundle)`.
//     `.load(named:in:)` (no `from:`) works instead for a plain bundled audio file not tied to
//     any RC Pro scene.
//  2. `entity.playAudio(resource)` actually plays it. If the entity also has a
//     `SpatialAudioComponent` (native RealityKit — `entity.spatialAudio = SpatialAudioComponent()`),
//     playback is positioned in 3D instead of flat/non-spatial.
//  3. Replace the TODO below with that once a clip name/asset actually exists.
//
//  Golden rules: Systems don't store entity state themselves (played/not-played lives on the
//  Component above); keep update(context:) lightweight — it runs ~90 times/sec.
//

import RealityKit

public struct SoundCueSystem: System {
    private static let soundQuery = EntityQuery(where: .has(SoundCueComponent.self))

    public init(scene: RealityKit.Scene) {}

    public func update(context: SceneUpdateContext) {
        for entity in context.entities(matching: Self.soundQuery, updatingSystemWhen: .rendering) {
            guard var cue = entity.components[SoundCueComponent.self],
                  !cue.hasPlayed,
                  cue.resourceName != nil else { continue }

            cue.hasPlayed = true
            entity.components[SoundCueComponent.self] = cue

            // TODO: once a real clip exists, replace this with something like:
            // if let resource = try? AudioFileResource.load(named: cue.resourceName!, from: "Scene", in: realityKitContentBundle) {
            //     entity.playAudio(resource)
            // }
        }
    }
}
