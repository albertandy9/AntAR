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

    var avatarImageName: String {
        switch self {
        case .firstPathSuccess, .sensorCalibrated:
            "Group 38"
        case .noPath, .lightBlock, .sensorAdjustment:
            "Group 43"
        }
    }

    var messages: [String] {
        switch self {
        case .firstPathSuccess:
            [
                "Yey, UFO berhasil jalan...",
                "UFO bisa jalan karena sinar inframerah yang dipancarkan berhasil diserap oleh papan."
            ]
        case .noPath:
            [
                "Sepertinya UFO belum bisa melanjutkan perjalanan...",
                "Sensor tidak menemukan balok di depan UFO. Yuk tambahkan balok jalur lagi."
            ]
        case .lightBlock:
            [
                "Sepertinya UFO tidak bisa jalan...",
                "Ini karena cahaya inframerah dipantulkan oleh balok berwarna terang."
            ]
        case .sensorAdjustment:
            [
                "Eh... tadi kok jalannya UFO oleng...",
                "Sepertinya jumlah sensornya perlu disesuaikan. Coba lihat ke bawah UFO."
            ]
        case .sensorCalibrated:
            [
                "Jalannya UFO lebih mulus nih.",
                "Ternyata, semakin banyak sensor, pergerakan UFO makin mulus."
            ]
        }
    }
}
