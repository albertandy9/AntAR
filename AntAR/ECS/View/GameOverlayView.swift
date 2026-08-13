//
//  GameOverlayView.swift
//  AntAR
//
//  Created by Albert Tandy Harison on 12/08/26.
//
import SwiftUI

struct GameOverlayView: View {
    let state: GameState
    let isTableReadyToPlace: Bool

    var body: some View {
        switch state {
        case .scanningTable:
            ScanningTableView(isReadyToPlace: isTableReadyToPlace)
        case .ufoAppears:
            UFOAppearsView()
        case .antEntersUFO:
            AntEntersUFOView()
        case .blocksScattered:
            BlocksScatteredView()
        case .ufoTravelling:
            UFOTravellingView()
        case .completed:
            CompletedView()
        default:
            EmptyView()
        }
    }
}
