//
//  SceneEntityLookup.swift
//  AntAR
//

import RealityKit

extension Entity {
    /// Depth-first lookup that also succeeds for disabled authored children.
    ///
    /// RealityKit system queries deliberately omit disabled entities. The one-scene approach
    /// needs to find a phase group again when a later `GameState` reveals it, so this walks the
    /// hierarchy instead of relying on a render-query result.
    func antarDescendant(named name: String) -> Entity? {
        if self.name == name { return self }
        for child in children {
            if let result = child.antarDescendant(named: name) {
                return result
            }
        }
        return nil
    }

    /// Includes disabled descendants and is intended for scene-level concerns such as phase
    /// visibility. Gameplay systems should continue using `EntityQuery` for their live entities.
    func antarDescendants() -> [Entity] {
        children.flatMap { child in
            [child] + child.antarDescendants()
        }
    }
}
