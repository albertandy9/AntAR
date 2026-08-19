//
//  EnvironmentLayoutConfig.swift
//  AntAR
//

enum EnvironmentLayoutConfig {
    /// Every authored environmental decoration currently placed in the RCP scene. Keeping these
    /// names explicit makes state-driven visibility deterministic without recreating any asset or
    /// material in Swift.
    static let decorativeEntityNames: [String] = [
        "env_grass_tuft",
        "env_grass_tuft_2",
        "env_grass_tuft_3",
        "env_grass_tuft_4",
        "env_grass_tuft_5",
        "env_grass_tuft_6",
        "env_grass_tuft_7",
        "env_grass_flowers",
        "env_grass_flowers_1",
        "env_grass_flowers_2",
        "env_grass_flowers_3",
        "env_grass_mushrooms",
        "env_grass_rock",
        "env_grass_rock_1",
        "env_grass_tall",
        "env_grass_wide",
        "env_leaf_patch",
        "env_rock_cluster",
        "env_rock_single",
    ]

    static let nestEntityName = "ant_nest"

    /// Preferred authored surface instance. `bakcground` is the legacy serialized name currently
    /// present in Scene.usda; it is still the textured terrain, never a generated-color fallback.
    static let authoredSurfaceEntityNames = [
        "background",
        "bakcground",
        "env_terrain_1",
        "env_terrain",
    ]

    /// Old untextured planes are used only when no authored surface exists.
    static let fallbackBackgroundEntityNames = [
        "background_white",
        "bakcground_white",
    ]
}
