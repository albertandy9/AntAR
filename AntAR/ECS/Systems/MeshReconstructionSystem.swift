//
//  MeshReconstructionSystem.swift
//  AntAR
//
//  ARViewModel creates one AnchorEntity(.plane(.horizontal, classification: .table, ...)) and
//  tags it with ScannableSurfaceComponent (see ARViewModel.setUpScanning()). This System just
//  watches that entity: once RealityKit actually resolves the anchor against a real table
//  (`isAnchored == true`), it marks scanConfidence = 1.0 and posts `.surfaceScanned` once.
//
//  RC PRO: the anchor entity itself has no visual — it's purely a transform. If you want scan
//  feedback (grid/wireframe overlay on the detected table), design that mesh/material in
//  RealityKitContent and add it as a child of `scannedSurfaceAnchor` in ARViewModel once it's
//  anchored (see the comment there).
//

import RealityKit
import Foundation

public struct MeshReconstructionSystem: System {
    private static let query = EntityQuery(where: .has(ScannableSurfaceComponent.self))

    nonisolated(unsafe) private static var notifiedEntityIDs: Set<UInt64> = []

    public init(scene: RealityKit.Scene) {}

    public func update(context: SceneUpdateContext) {
        for entity in context.entities(matching: Self.query, updatingSystemWhen: .rendering) {
            guard entity.isAnchored,
                  var surface = entity.components[ScannableSurfaceComponent.self],
                  surface.scanConfidence < 1.0 else { continue }

            surface.scanConfidence = 1.0
            entity.components[ScannableSurfaceComponent.self] = surface

            if !Self.notifiedEntityIDs.contains(entity.id) {
                Self.notifiedEntityIDs.insert(entity.id)
                NotificationCenter.default.post(name: .surfaceScanned, object: nil, userInfo: ["entityID": entity.id])
            }
        }
    }
}
