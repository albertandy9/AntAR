//
//  AntWalkSystem.swift
//  AntAR
//
//  Step 2: Define System (Logic Class).
//  Every frame, eases any AntWalkComponent entity from startPosition to targetPosition (same
//  smoothstep as AntBoardSystem/UFODescendSystem), plays that ant's own walk-cycle animation
//  (verified: Entity.availableAnimations / playAnimation / AnimationResource.repeat(duration:)
//  are all real APIs) while it's moving, and stops it once arrived. On arrival:
//  disappearsOnArrival entities (ant1...ant4) are disabled; ant_noanthena (disappearsOnArrival ==
//  false) just stops and stays visible — "stuck."
//
//  All 5 ants are started together, in the same frame, with the same fixed walkDuration (not a
//  fixed speed) — that's why they all cross progress >= 1 on the same frame, which is what makes
//  it safe to report .otherAntsExited the moment ANY disappearsOnArrival ant finishes this frame
//  (all four finish together) rather than needing separate bookkeeping to count all four.
//
//  Golden rules: Systems don't store entity state themselves (progress/flags live on the
//  Component above); keep update(context:) lightweight — it runs ~90 times/sec, and this only
//  ever walks 5 ants.
//

import RealityKit

public struct AntWalkSystem: System {
    private static let antQuery = EntityQuery(where: .has(AntWalkComponent.self))
    private static let directorQuery = EntityQuery(
        where: .has(GameDirectorComponent.self) && .has(GameEventComponent.self)
    )

    // TUNABLE — how long the walk from formation to the finish marker takes, in seconds. Real
    // walk distances here are ~2-2.4m (this scene is room-scale, not tabletop-close — measured
    // directly in Scene.usda), so this is picked for a visibly unhurried pace at that distance,
    // not validated on-device yet.
    private static let walkDuration: Float = 10.0

    public init(scene: RealityKit.Scene) {}

    public func update(context: SceneUpdateContext) {
        let deltaTime = Float(context.deltaTime)
        var formationAntJustArrived = false
        var lostAntJustArrived = false

        for ant in context.entities(matching: Self.antQuery, updatingSystemWhen: .rendering) {
            guard var walk = ant.components[AntWalkComponent.self], walk.progress < 1 else { continue }

            if !walk.hasStartedAnimation {
                walk.hasStartedAnimation = true
                if let animation = ant.availableAnimations.first {
                    ant.playAnimation(animation.repeat(), transitionDuration: 0.2, startsPaused: false)
                }
            }

            walk.progress = min(walk.progress + deltaTime / Self.walkDuration, 1)
            ant.components[AntWalkComponent.self] = walk

            let eased = Self.smoothstep(walk.progress)
            ant.setPosition(simd_mix(walk.startPosition, walk.targetPosition, SIMD3(repeating: eased)), relativeTo: nil)

            if walk.progress >= 1 {
                ant.stopAllAnimations()
                if walk.disappearsOnArrival {
                    ant.isEnabled = false
                    formationAntJustArrived = true
                } else {
                    lostAntJustArrived = true
                }
            }
        }

        guard formationAntJustArrived || lostAntJustArrived else { return }
        for director in context.entities(matching: Self.directorQuery, updatingSystemWhen: .rendering) {
            guard var events = director.components[GameEventComponent.self] else { continue }
            if formationAntJustArrived {
                events.enqueue(.otherAntsExited)
            }
            if lostAntJustArrived {
                events.enqueue(.lostAntReachedOrigin)
            }
            director.components[GameEventComponent.self] = events
        }
    }

    private static func smoothstep(_ t: Float) -> Float {
        let clamped = min(max(t, 0), 1)
        return clamped * clamped * (3 - 2 * clamped)
    }
}
