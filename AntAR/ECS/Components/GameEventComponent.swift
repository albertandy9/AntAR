//
//  GameEventComponent.swift
//  AntAR
//

import RealityKit

/// A FIFO event inbox attached to the `GameDirector` entity.
///
/// Input, AR, interaction, and simulation systems may enqueue facts here. Only
/// `GameStateMachineSystem` consumes them and changes the global game state.
public struct GameEventComponent: Component {
    private var pendingEvents: [GameEvent] = []

    public init() {}

    public var nextEvent: GameEvent? {
        pendingEvents.first
    }

    public mutating func enqueue(_ event: GameEvent) {
        // Multiple frames can report the same completion. Keeping one adjacent copy avoids an
        // unbounded queue while preserving deliberately repeated events later in the flow.
        guard pendingEvents.last != event else { return }
        pendingEvents.append(event)
    }

    mutating func consumeNextEvent() {
        guard !pendingEvents.isEmpty else { return }
        pendingEvents.removeFirst()
    }
}
