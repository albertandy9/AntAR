//
//  AntARSceneNames.swift
//  AntAR
//

/// The scene designer's contract for `Scene.usda`.
///
/// These are authored entity names, not class names. Keep them stable so code only binds to the
/// one complete Reality Composer Pro scene and never builds a second procedural scene.
enum AntARSceneNames {
    static let pickupUFO = "ufo_angkat_semut"
    static let pickupUFOFinishMarker = "finish_ufo"
    static let travelUFO = "ufo_jalan"
    static let home = "ant_nest"
    static let pathTiles = ["PathTile_1", "PathTile_2", "PathTile_3", "PathTile_4"]
    static let completionGroup = "Phase_Complete"
    static let legacyCompletionEntities = [
        "finish_ant1", "finish_ant2", "finish_ant3", "finish_ant4", "finish_ant_noanthena"
    ]

    /// The only authored root entities shown while the focused state-10 route is running.
    /// Everything else in `Scene.usda` belongs to earlier story phases and is explicitly gated
    /// off by `SceneBindingSystem`, rather than relying on its current USD `active` value.
    static let ufoTravelRootEntities = Set([
        travelUFO,
        home,
        "PathTile_1", "PathTile_2", "PathTile_3", "PathTile_4"
    ])
}
