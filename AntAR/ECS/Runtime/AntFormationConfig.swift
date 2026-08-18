//
//  AntFormationConfig.swift
//  AntAR
//
//  Not a Component — one-time spawn configuration read by
//  ARExperienceViewModel.beginAntsLeaveFormation(), same reasoning as BlockLayoutConfig.
//
//  RC PRO <-> CODE HOOKUP (checked directly in Scene.usda): ant1...ant4 and ant_noanthena are
//  each already positioned at their own "formation" spot, and finish_ant1...finish_ant4 /
//  finish_ant_noanthena are the hidden marker entities the artist authored as their destinations.
//

enum AntFormationConfig {
    struct Entry {
        let antName: String
        let finishName: String
        let disappearsOnArrival: Bool
    }

    static let entries: [Entry] = [
        Entry(antName: "ant1", finishName: "finish_ant1", disappearsOnArrival: true),
        Entry(antName: "ant2", finishName: "finish_ant2", disappearsOnArrival: true),
        Entry(antName: "ant3", finishName: "finish_ant3", disappearsOnArrival: true),
        Entry(antName: "ant4", finishName: "finish_ant4", disappearsOnArrival: true),
        Entry(antName: "ant_noanthena", finishName: "finish_ant_noanthena", disappearsOnArrival: false),
    ]
}
