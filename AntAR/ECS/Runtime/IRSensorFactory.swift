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
    // Three rings still communicate the travelling/returning wave clearly while removing 25%
    // of the animated beam entities and transparent draws from every sensor.
    private static let wavefrontCount = 3
    private static let sharedWavefrontMesh = MeshResource.generateCylinder(
        height: 0.0012,
        radius: 0.010
    )
    private static let sharedImpactGlowMesh = MeshResource.generateCylinder(
        height: 0.0018,
        radius: 0.014
    )
    private static let sharedRedMaterial = redMaterial()

    /// Forces one-time mesh/material creation while the authored scene is preloading instead of
    /// paying that cost on the frame where the travelling UFO becomes visible.
    static func prepareSharedResources() {
        _ = sharedWavefrontMesh
        _ = sharedImpactGlowMesh
        _ = sharedRedMaterial
    }

    static func rebuildSensors(on ufo: Entity, sensorCount: Int, sensorRange: Float) {
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
                    range: sensorRange
                )
            )
            sensor.addChild(makeSensorLight(sensorCount: sensorCount))
            for waveIndex in 0..<wavefrontCount {
                sensor.addChild(makeWavefront(index: waveIndex, isReturn: false))
                sensor.addChild(makeWavefront(index: waveIndex, isReturn: true))
            }
            sensor.addChild(makeImpactGlow(range: sensorRange))
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

        for visual in sensor.children {
            guard let beam = visual.components[IRBeamVisualComponent.self] else { continue }

            switch beam.kind {
            case .emittedWave:
                let progress = normalizedPhase(wavePhase + beam.phaseOffset)
                let radiusScale = 0.70 + progress * 0.80
                visual.position.y = -range * progress
                visual.scale = SIMD3<Float>(radiusScale, 1, radiusScale)
                setOpacity(on: visual, to: 0.08 + (1 - progress) * 0.34)

            case .returnedWave:
                // The sensor measures returned energy rather than a mirror-like outgoing ray.
                // Bright surfaces make the return wave strong; the dark line absorbs most of it.
                let progress = normalizedPhase(wavePhase + beam.phaseOffset)
                let returnProgress = normalizedPhase(progress + 0.12)
                let radiusScale = 1.45 - returnProgress * 0.65
                visual.position.y = -range + range * returnProgress
                visual.scale = SIMD3<Float>(radiusScale, 1, radiusScale)
                visual.isEnabled = isSamplingTile
                setOpacity(
                    on: visual,
                    to: returnedIR * (0.06 + (1 - returnProgress) * 0.42)
                )

            case .impactGlow:
                let glowStrength = max(returnedIR, activation * 0.45)
                let pulse = 0.88 + sin(wavePhase * .pi * 2) * 0.12
                let size = (0.70 + glowStrength * 1.15) * pulse
                visual.scale = SIMD3<Float>(size, 1, size)
                visual.isEnabled = isSamplingTile
                setOpacity(on: visual, to: 0.10 + glowStrength * 0.52)
            }
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
            mesh: sharedWavefrontMesh,
            materials: [sharedRedMaterial]
        )
        entity.name = (isReturn ? returnedWavePrefix : emittedWavePrefix) + String(index)
        entity.components.set(
            IRBeamVisualComponent(
                kind: isReturn ? .returnedWave : .emittedWave,
                phaseOffset: Float(index) / Float(wavefrontCount)
            )
        )
        entity.components.set(OpacityComponent(opacity: isReturn ? 0.20 : 0.30))
        return entity
    }

    private static func makeImpactGlow(range: Float) -> ModelEntity {
        let entity = ModelEntity(
            mesh: sharedImpactGlowMesh,
            materials: [sharedRedMaterial]
        )
        entity.name = impactGlowName
        entity.position.y = -range
        entity.components.set(IRBeamVisualComponent(kind: .impactGlow))
        entity.components.set(OpacityComponent(opacity: 0.38))
        return entity
    }

    private static func normalizedPhase(_ value: Float) -> Float {
        value - floor(value)
    }

    private static func redMaterial() -> UnlitMaterial {
        var material = UnlitMaterial(color: UIColor(red: 1, green: 0.10, blue: 0.04, alpha: 1))
        material.blending = .transparent(opacity: .init(floatLiteral: 1))
        material.readsDepth = true
        material.writesDepth = false
        return material
    }

    private static func setOpacity(on entity: Entity, to requestedOpacity: Float) {
        let opacity = min(max(requestedOpacity, 0), 1)
        if var component = entity.components[OpacityComponent.self] {
            guard abs(component.opacity - opacity) > 0.005 else { return }
            component.opacity = opacity
            entity.components[OpacityComponent.self] = component
        } else {
            entity.components.set(OpacityComponent(opacity: opacity))
        }
    }
}
