//
//  SoundCueComponent.swift
//  AntAR
//

import RealityKit

/// Pure data — the sound-engineering equivalent of HapticCueComponent. `resourceName` is left
/// `nil` until a real audio clip exists; `SoundCueSystem` no-ops while it's nil, so attaching
/// this component ahead of time (as ARExperienceViewModel.spawnUFO() already does) is harmless —
/// it's just reserved space until you set a name. `hasPlayed` guards against playing more than
/// once, same idea as the haptic cue.
public struct SoundCueComponent: Component, Codable {
    public var resourceName: String?
    public var hasPlayed: Bool

    public init(resourceName: String? = nil, hasPlayed: Bool = false) {
        self.resourceName = resourceName
        self.hasPlayed = hasPlayed
    }
}
