//
//  NotificationNames.swift
//  AntAR
//
//  Every Notification.Name posted by a System, in one place, so code and RC Pro/tech-artist
//  comments never drift. Extended milestone-by-milestone.
//

import Foundation

extension Notification.Name {
    /// Posted by MeshReconstructionSystem once the desk anchor is confirmed (`isAnchored`).
    /// userInfo: ["entityID": UInt64].
    static let surfaceScanned = Notification.Name("surface.scanned")

    /// Posted by AntNavigationSystem when an entity's NavigationComponent finishes its waypoint
    /// list. userInfo: ["entityID": UInt64, "entityName": String].
    static let antReached = Notification.Name("ant.reached")
}
