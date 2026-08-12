//
//  GameStateNotifications.swift
//  AntAR
//

import Foundation

extension Notification.Name {
    static let gameStateDidChange = Notification.Name("antar.gameState.didChange")
}

enum GameStateNotificationKey {
    static let previous = "previous"
    static let current = "current"
    static let event = "event"
}
