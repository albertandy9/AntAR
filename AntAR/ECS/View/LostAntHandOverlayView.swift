//
//  LostAntHandOverlayView.swift
//  AntAR
//
//  Placed at the bottom of the screen by ContentView (same pattern as BlockInventoryView), shown
//  for every LostAntGreetPhase except .done. Deliberately large — this is meant to read as a
//  prominent visual instruction, not a small icon.
//

import SwiftUI

struct LostAntHandOverlayView: View {
    var body: some View {
        Image("hand_overlay")
            .resizable()
            .scaledToFit()
            .frame(maxWidth: .infinity)
            .frame(height: 500)
            // 1. Ekspansi frame setinggi mungkin, lalu posisikan konten di bawah
            .frame(maxHeight: .infinity, alignment: .bottom)
            // 2. (Opsional) Tambahkan ini jika ingin benar-benar mentok ujung layar
            //    dan mengabaikan area aman (safe area/home indicator).
            .ignoresSafeArea(.all, edges: .bottom)
    }
}

