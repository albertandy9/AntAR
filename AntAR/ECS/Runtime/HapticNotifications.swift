//
//  HapticNotifications.swift
//  AntAR
//
//  HapticFeedbackSystem detects an unfired HapticCueComponent and posts this instead of calling
//  UIImpactFeedbackGenerator directly — Systems run on RealityKit's own simulation loop, which
//  isn't guaranteed to be the main thread, and UIKit's feedback generators are strictly
//  main-thread/UI-actor-only. Same bridge pattern as GameStateNotifications.swift: the System
//  posts, ARExperienceViewModel (MainActor) observes and actually fires the haptic.
//

import Foundation

extension Notification.Name {
    static let hapticCueRequested = Notification.Name("antar.hapticCue.requested")
}

enum HapticNotificationKey {
    static let style = "style"
    static let intensity = "intensity"
}
