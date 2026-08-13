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

    static let backgroundEntityName = "bakcground"
    // TUNABLE — bakcground's color. Change this to whatever fits the scene.
    static let backgroundColor: UIColor = .systemBrown
}
