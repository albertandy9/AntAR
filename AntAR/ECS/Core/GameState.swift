//
//  GameState.swift
//  AntAR
//
//  The canonical, story-level state machine. Keep this enum intentionally small: it describes
//  what the player is doing in the narrative, not the moment-to-moment state of an ant, UFO,
//  block, animation, or IR sensor.
//

import Foundation

/// The 11 mentor-defined beats of the AntAR experience.
///
/// The raw values are stable scene/content identifiers. Do not use display copy as an identifier;
/// narration and UI copy can change without breaking saved state or RC Pro notification names.
public enum GameState: String, CaseIterable, Codable, Sendable {
    /// 1. Intro — scan the desk and establish the AR play surface.
    case scanningTable
    /// 2. The four ants have left the formation, leaving the final ant behind.
    case antsLeaveFormation
    /// 3. The lost ant stops at the scanned surface's local origin `(0, 0)`.
    case lostAntAtSurfaceOrigin
    /// 4. The lost ant tells its story / asks for help.
    case lostAntDialogue
    /// 5. The UFO appears and becomes the next interactable object.
    case ufoAppears
    /// 6. The ant boards the UFO.
    case antEntersUFO
    /// 7. Collectible path blocks are scattered in the environment.
    case blocksScattered
    /// 8. Required blocks have been collected into inventory.
    case blocksCollected
    /// 9. The player has placed the required path blocks on the desk.
    case blocksPlaced
    /// 10. The UFO follows the authored path.
    case ufoTravelling
    /// 11. The ant reaches home and the experience is complete.
    case completed

    /// Pure transition table. It is deliberately independent of RealityKit, making the story
    /// order straightforward to unit-test without an AR session.
    public func transition(for event: GameEvent) -> GameState? {
        switch (self, event) {
        case (.scanningTable, .surfaceLocked):
            .antsLeaveFormation
        case (.antsLeaveFormation, .otherAntsExited):
            .lostAntAtSurfaceOrigin
        case (.lostAntAtSurfaceOrigin, .lostAntReachedOrigin):
            .lostAntDialogue
        case (.lostAntDialogue, .lostAntDialogueDismissed):
            .ufoAppears
        case (.ufoAppears, .ufoReachedLostAnt):
            .antEntersUFO
        case (.antEntersUFO, .antBoardedUFO):
            .blocksScattered
        case (.blocksScattered, .allRequiredBlocksCollected):
            .blocksCollected
        case (.blocksCollected, .requiredPathPlaced):
            .blocksPlaced
        case (.blocksPlaced, .ufoMoveRequested):
            .ufoTravelling
        case (.ufoTravelling, .ufoReachedHome):
            .completed
        default:
            nil
        }
    }
}
