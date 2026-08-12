//
//  ScannableSurfaceComponent.swift
//  AntAR
//
//  Attached by ARViewModel to the AnchorEntity(.plane(...)) that represents the detected desk.
//  RC PRO: no manual authoring needed for this component's values — MeshReconstructionSystem
//  fills them in. What RC Pro *does* own: the visual child entity (material/mesh) that should be
//  parented under the anchor once it's placed — see the comment in ARViewModel where the anchor
//  is created for exactly where that child gets added in code.
//

import RealityKit

public struct ScannableSurfaceComponent: Component {
    // RUNTIME ONLY - do not expose
    public var scanConfidence: Float = 0.0

    public init() {}
}
