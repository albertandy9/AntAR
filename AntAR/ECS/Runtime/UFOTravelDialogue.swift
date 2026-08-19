//
//  UFOTravelDialogue.swift
//  AntAR
//

import Foundation

/// Presentation events for the state-10 learning loop. The ECS systems still own movement,
/// sensing, and stall classification; the view model translates those results into dialogue.
enum UFOTravelDialogue: String, Equatable, Sendable {
    case firstPathSuccess
    case noPath
    case lightBlock
    case sensorAdjustment
    case sensorCalibrated
    case arrivedHome

    var avatarImageName: String {
        switch self {
        case .firstPathSuccess, .sensorCalibrated, .arrivedHome:
            "Group 38"
        case .noPath, .lightBlock, .sensorAdjustment:
            "Group 43"
        }
    }

    var messages: [String] {
        switch self {
        case .firstPathSuccess:
            [
                "Yeay!!~ UFO berhasil jalan...",
                "UFO bisa jalan karena sinar inframerah yang dipancarkan di serap oleh balok."
            ]
        case .noPath:
            [
                "Lanjut letakkan balok di atas permukaan untuk membuat jalur bagi UFO!"
            ]
        case .lightBlock:
            [
                "Sepertinya UFO tidak bisa jalan...",
                "Ini karena cahaya inframerah dipantulkan oleh balok berwarna terang.",
                "Coba ganti warna baloknya..."
            ]
        case .sensorAdjustment:
            [
                "Ehhhh.. kenapa UFO jalannya tidak mulus?",
                "Hmm... sepertinya UFO perlu diperbaiki. Coba lihat kebawah UFO."
            ]
        case .sensorCalibrated:
            [
                "Wahhh.... Jalannya UFO lebih mulus nih.",
                "Ternyata, semakin banyak sensor, pergerakan UFO makin mulus."
            ]
        case .arrivedHome:
            [
                "Yeayyy... Akhirnya aku sampai di rumah.",
                "Terima Kasih yaa sudah membantuku..."
            ]
        }
    }
}
