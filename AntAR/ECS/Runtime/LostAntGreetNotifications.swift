//
//  LostAntGreetNotifications.swift
//  AntAR
//
//  Same bridge pattern as GameStateNotifications/HapticNotifications: LostAntGreetSystem posts
//  here (Systems run on RealityKit's own loop, not guaranteed the main thread) instead of writing
//  to @Observable state directly; ARExperienceViewModel observes on queue: .main.
//

import Foundation

extension Notification.Name {
    static let lostAntGreetPhaseDidChange = Notification.Name("antar.lostAntGreet.phaseDidChange")
}

enum LostAntGreetNotificationKey {
    static let phase = "phase"
}
