//
//  BlockPlacementConfig.swift
//  AntAR
//
//  Not a Component — same reasoning as BlockLayoutConfig/EnvironmentLayoutConfig: one-time
//  configuration read by ARExperienceViewModel.placeBlockInFrontOfUFO(blockID:), not per-frame
//  gameplay state.
//
//  RC PRO <-> CODE HOOKUP (checked directly in Scene.usda): "finish_block_1" through
//  "finish_block_4" are 4 Cube markers authored in a straight evenly-spaced line in front of the
//  UFO — same kind of hidden position-only marker as finish_ufo/finish_ant_noanthena, not meant to
//  be visible themselves. Dropped blocks fill these in order (see dropSlotNames' ordering).
//

enum BlockPlacementConfig {
    static let requiredPathBlockCount = 4

    static let dropSlotNames: [String] = [
        "finish_block_1",
        "finish_block_2",
        "finish_block_3",
        "finish_block_4",
    ]
}
