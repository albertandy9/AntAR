//
//  IRSensorFactory.swift
//  AntAR
//

import RealityKit
import UIKit

/// Creates the dynamic IR emitters, incident rays, hit glows, and reflected-ray teaching visuals.
/// The UFO and route remain in the authored Reality Composer Pro scene.
@MainActor
enum IRSensorFactory {
    private static let emitterLightName = "IREmitterLight"
    private static let emittedWavePrefix = "IREmittedWave_"
    private static let returnedWavePrefix = "IRReturnedWave_"
    private static let impactGlowName = "IRImpactGlow"
    private static let wavefrontCount = 4

    static func rebuildSensors(on ufo: Entity, sensorCount: Int) {
        ufo.children
            .filter { $0.components[IRSensorComponent.self] != nil }
            .forEach { $0.removeFromParent() }

        for (index, lateralOffset) in IRSensorLayout.lateralOffsets(for: sensorCount).enumerated() {
            let sensor = Entity()
            sensor.name = "IRSensor_\(index + 1)"
            sensor.position = SIMD3<Float>(
                lateralOffset,
                0,
                IRSensorLayout.forwardOffset
            )
            sensor.components.set(
                IRSensorComponent(
                    index: index,
                    lateralOffset: lateralOffset,
                    range: UFOPathFollowerComponent.hoverHeight
                )
            )
            sensor.addChild(makeSensorLight(sensorCount: sensorCount))
            for waveIndex in 0..<wavefrontCount {
                sensor.addChild(makeWavefront(index: waveIndex, isReturn: false))
                sensor.addChild(makeWavefront(index: waveIndex, isReturn: true))
            }
            sensor.addChild(makeImpactGlow())
            ufo.addChild(sensor)
        }
    }

    static func applyBeamAppearance(
        to sensor: Entity,
        lineSignal: Float,
        reflectance: Float,
        isSamplingTile: Bool,
        wavePhase: Float,
        range: Float
    ) {
        let activation = min(max(lineSignal, 0), 1)
        let returnedIR = min(max(reflectance, 0), 1)

        for waveIndex in 0..<wavefrontCount {
            let offset = Float(waveIndex) / Float(wavefrontCount)
            let progress = normalizedPhase(wavePhase + offset)

            if let emitted = sensor.children.first(
                where: { $0.name == emittedWavePrefix + String(waveIndex) }
            ) {
                let radiusScale = 0.70 + progress * 0.80
                emitted.position.y = -range * progress
                emitted.scale = SIMD3<Float>(radiusScale, 1, radiusScale)
                setRedMaterial(on: emitted, alpha: 0.08 + (1 - progress) * 0.34)
            }

            if let returned = sensor.children.first(
                where: { $0.name == returnedWavePrefix + String(waveIndex) }
            ) {
                // The sensor measures returned energy rather than a mirror-like outgoing ray.
                // Bright surfaces make the return wave strong; the dark line absorbs most of it.
                let returnProgress = normalizedPhase(progress + 0.12)
                let radiusScale = 1.45 - returnProgress * 0.65
                returned.position.y = -range + range * returnProgress
                returned.scale = SIMD3<Float>(radiusScale, 1, radiusScale)
                returned.isEnabled = isSamplingTile || returnedIR > 0.08
                setRedMaterial(
                    on: returned,
                    alpha: returnedIR * (0.06 + (1 - returnProgress) * 0.42)
                )
            }
        }

        if let glow = sensor.children.first(where: { $0.name == impactGlowName }) {
            let glowStrength = max(returnedIR, activation * 0.45)
            let pulse = 0.88 + sin(wavePhase * .pi * 2) * 0.12
            let size = (0.70 + glowStrength * 1.15) * pulse
            glow.scale = SIMD3<Float>(size, 1, size)
            setRedMaterial(on: glow, alpha: 0.10 + glowStrength * 0.52)
        }
    }

    /// Every IR sensor owns an actual RealityKit light. It produces real red direct illumination
    /// on lit scene materials; the wavefront meshes only reveal otherwise invisible IR travel.
    private static func makeSensorLight(sensorCount: Int) -> Entity {
        let light = Entity()
        light.name = emitterLightName
        light.orientation = simd_quatf(
            angle: -.pi / 2,
            axis: SIMD3<Float>(1, 0, 0)
        )
        let perSensorIntensity = max(70, 520 / Float(max(sensorCount, 1)))
        light.components.set(
            SpotLightComponent(
                color: .red,
                intensity: perSensorIntensity,
                innerAngleInDegrees: 7,
                outerAngleInDegrees: 22,
                attenuationRadius: 0.70
            )
        )
        return light
    }

    private static func makeWavefront(index: Int, isReturn: Bool) -> ModelEntity {
        let entity = ModelEntity(
            mesh: .generateCylinder(height: 0.0012, radius: 0.010),
            materials: [redMaterial(alpha: isReturn ? 0.20 : 0.30)]
        )
        entity.name = (isReturn ? returnedWavePrefix : emittedWavePrefix) + String(index)
        entity.components.set(IRBeamVisualComponent())
        return entity
    }

    private static func makeImpactGlow() -> ModelEntity {
        let entity = ModelEntity(
            mesh: .generateCylinder(height: 0.0018, radius: 0.014),
            materials: [redMaterial(alpha: 0.38)]
        )
        entity.name = impactGlowName
        entity.position.y = -UFOPathFollowerComponent.hoverHeight
        entity.components.set(IRBeamVisualComponent())
        return entity
    }

    private static func normalizedPhase(_ value: Float) -> Float {
        value - floor(value)
    }

    private static func redMaterial(alpha: Float) -> UnlitMaterial {
        var material = UnlitMaterial(color: UIColor(red: 1, green: 0.10, blue: 0.04, alpha: 1))
        material.blending = .transparent(opacity: .init(floatLiteral: min(max(alpha, 0), 1)))
        material.readsDepth = true
        material.writesDepth = false
        return material
    }

    private static func setRedMaterial(on entity: Entity, alpha: Float) {
        guard var model = entity.components[ModelComponent.self] else { return }
        model.materials = [redMaterial(alpha: alpha)]
        entity.components[ModelComponent.self] = model
    }
}
