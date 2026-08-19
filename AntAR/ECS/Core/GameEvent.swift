//
//  GameEvent.swift
//  AntAR
//

import Foundation

/// Facts reported by feature systems to the game director.
///
/// Systems publish one of these events; they never mutate `GameStateComponent.current` directly.
/// That rule makes all global-flow decisions visible in one transition table.
public enum GameEvent: String, CaseIterable, Codable, Sendable {
    case surfaceLocked
    case otherAntsExited
    case lostAntReachedOrigin
    case lostAntDialogueDismissed
    case ufoReachedLostAnt
    case antBoardedUFO
    case allRequiredBlocksCollected
    case requiredPathPlaced
    case ufoMoveRequested
    case ufoReachedHome
    case retryFromBlocks
}
