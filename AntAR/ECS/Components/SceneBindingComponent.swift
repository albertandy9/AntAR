//
//  SceneBindingComponent.swift
//  AntAR
//

import RealityKit

/// Makes an entity from the single Reality Composer Pro scene discoverable by its stable role.
///
/// The `SceneBindingSystem` attaches these at runtime from the authored entity names. When the
/// final scene is ready, the same component can instead be authored directly in RC Pro.
public struct SceneBindingComponent: Component, Codable {
    public var role: SceneEntityRole

    public init(role: SceneEntityRole) {
        self.role = role
    }
}

/// Names used in the authored `Scene.usda`. Keep all string names here, rather than scattering
/// them through systems, so a scene rename has one explicit migration point.
public enum SceneEntityRole: String, CaseIterable, Codable, Sendable {
    case travelUFO
    case home
    case pathTile1
    case pathTile2
    case pathTile3
    case pathTile4
    case completionGroup

    var authoredName: String {
        switch self {
        case .travelUFO: return "ufo_jalan"
        case .home: return "ant_nest"
        case .pathTile1: return "PathTile_1"
        case .pathTile2: return "PathTile_2"
        case .pathTile3: return "PathTile_3"
        case .pathTile4: return "PathTile_4"
        case .completionGroup: return "Phase_Complete"
        }
    }
}
