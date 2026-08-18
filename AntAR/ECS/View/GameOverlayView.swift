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
    let lostAntGreetPhase: LostAntGreetPhase?
    let isCoachingOverlayActive: Bool
    let isSurfaceTooSmall: Bool

    var body: some View {
        switch state {
        case .scanningTable:
            // Hidden while ARCoachingOverlayView is up so the native "move device to find a
            // surface" UI and this custom reticle are sequenced, not both visible at once.
            if !isCoachingOverlayActive {
                ScanningTableView(isReadyToPlace: isTableReadyToPlace, isSurfaceTooSmall: isSurfaceTooSmall)
            }
        case .antsLeaveFormation:
            CaptionPill(text: "Mundur sedikit, barisan semut mau lewat")
        case .lostAntDialogue:
            LostAntDialogueView(phase: lostAntGreetPhase)
        case .ufoAppears:
            EmptyView()
        case .antEntersUFO:
            AntEntersUFOView()
        case .blocksScattered:
            EmptyView()
        case .ufoTravelling:
            UFOTravellingView()
        case .completed:
            CompletedView()
        default:
            EmptyView()
        }
    }
}
