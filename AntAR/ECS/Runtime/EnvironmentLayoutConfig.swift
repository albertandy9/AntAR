//
//  EnvironmentLayoutConfig.swift
//  AntAR
//

import UIKit

enum EnvironmentLayoutConfig {
    // TUNABLE — every grass tuft to reveal alongside ufo_jalan.
    static let grassEntityNames: [String] = [
        "env_grass_tuft",
        "env_grass_tuft_1",
        "env_grass_tuft_2",
        "env_grass_tuft_3",
        "env_grass_tuft_4",
        "env_grass_tuft_5",
        "env_grass_tuft_6",
    ]

    static let nestEntityName = "ant_nest"

    /// Preferred authored terrain instance. The aliases keep existing RCP exports working while
    /// Reality Composer Pro finishes serializing the scene-hierarchy rename to `background`.
    static let terrainEntityNames = [
        "background",
        "env_terrain_1",
        "env_terrain",
    ]

    /// The original flat plane is only a fallback and is hidden whenever authored terrain exists.
    static let fallbackBackgroundEntityNames = [
        "background_white",
        "bakcground_white",
        "bakcground",
    ]

    // TUNABLE — fallback plane color. The authored terrain keeps its own USDZ materials.
    static let backgroundColor: UIColor = .systemBrown
}
