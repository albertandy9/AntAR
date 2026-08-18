//
//  IRSensorFactory.swift
//  AntAR
//

import RealityKit
import UIKit

/// Binds the two RCP-authored sensor children and duplicates their asset for sensors 3...8.
/// Lights, incident waves, hit glows, and reflected waves are attached beneath each real sensor,
/// so every projection follows the sensor's authored or duplicated transform.
@MainActor
enum IRSensorFactory {
    private static let sceneSensorPrefix = "IR_"
    private static let legacySensorPrefix = "IRSensor_"
    private static let ufoModelName = "friendly_ufo"
    private static let projectionRootName = "IRProjectionRoot"
    private static let emitterLightName = "IREmitterLight"
    private static let emittedWavePrefix = "IREmittedWave_"
    private static let returnedWavePrefix = "IRReturnedWave_"
    private static let impactGlowName = "IRImpactGlow"
    private static let authoredSensorCount = 2
    private static let maximumArraySpan: Float = 0.19
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
        let count = min(
            max(sensorCount, IRSensorLayout.minimumCount),
            IRSensorLayout.maximumCount
        )

        removeCodeGeneratedSensors(from: ufo)

        // `ufo_jalan` is the ECS movement root, while `friendly_ufo` is the authored visual
        // chassis. The sensors must live beneath the chassis so any model animation or authored
        // transform also carries the physical sensor array and its projection rigs.
        let sensorParent = ufo.antarDescendant(named: ufoModelName) ?? ufo
        let authoredEntities = ufo.antarDescendants().filter { entity in
            guard let ordinal = sensorOrdinal(named: entity.name) else { return false }
            return ordinal <= authoredSensorCount
        }

        // Some third-party USDZ converters author every exported model as its own horizontal
        // plane anchor. An anchored descendant ignores the moving UFO hierarchy at runtime and
        // appears to be left behind. Sensors are ordinary model children here, never anchors.
        authoredEntities.forEach(removeIndependentAnchoring)

        for sensor in authoredEntities where sensor.parent !== sensorParent {
            sensorParent.addChild(sensor, preservingWorldTransform: true)
        }

        let authoredSensors = authoredEntities.compactMap { entity -> (Entity, SIMD3<Float>)? in
            guard let ordinal = sensorOrdinal(named: entity.name),
                  ordinal <= authoredSensorCount else {
                return nil
            }
            let sourcePosition = entity.components[IRSensorComponent.self]?.sourceLocalPosition
                ?? entity.position
            return (entity, sourcePosition)
        }
        .sorted { $0.1.x < $1.1.x }

        guard authoredSensors.count == authoredSensorCount else {
            rebuildLegacySensors(
                on: sensorParent,
                within: ufo,
                sensorCount: count,
                sensorRange: sensorRange
            )
            return
        }

        let leftSource = authoredSensors[0].1
        let rightSource = authoredSensors[1].1
        let arrayCenterX = (leftSource.x + rightSource.x) * 0.5
        let authoredSpacing = max(abs(rightSource.x - leftSource.x), 0.018)
        let spacing = min(
            authoredSpacing,
            maximumArraySpan / Float(max(count - 1, 1))
        )
        let baseY = (leftSource.y + rightSource.y) * 0.5
        let baseZ = (leftSource.z + rightSource.z) * 0.5
        let startX = arrayCenterX - spacing * Float(count - 1) * 0.5

        var sensors = authoredSensors.map(\.0)
        let prototype = authoredEntities.first(where: { $0.name == "IR_1" })
            ?? authoredSensors[0].0

        if count > authoredSensorCount {
            for ordinal in (authoredSensorCount + 1)...count {
                let clone = prototype.clone(recursive: true)
                clone.name = sceneSensorPrefix + String(ordinal)
                removeRuntimeConfiguration(from: clone)
                removeIndependentAnchoring(from: clone)
                sensorParent.addChild(clone)
                sensors.append(clone)
            }
        }

        for (index, sensor) in sensors.enumerated() {
            let localPosition = SIMD3<Float>(
                startX + Float(index) * spacing,
                baseY,
                baseZ
            )
            let sourcePosition = index < authoredSensorCount
                ? authoredSensors[index].1
                : localPosition

            sensor.position = localPosition
            let effectiveRange = projectionRange(
                from: sensor,
                toRouteBelow: ufo,
                baseRange: sensorRange
            )
            sensor.components.set(
                IRSensorComponent(
                    index: index,
                    lateralOffset: localPosition.x - arrayCenterX,
                    range: effectiveRange,
                    sourceLocalPosition: sourcePosition,
                    isSceneAuthored: index < authoredSensorCount
                )
            )
            installProjectionRig(
                on: sensor,
                sensorCount: count,
                sensorRange: effectiveRange
            )
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

        guard let projectionRoot = sensor.children.first(where: {
            $0.name == projectionRootName
        }) else {
            return
        }

        for visual in projectionRoot.children {
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

    /// Projection geometry follows the sensor position but cancels the imported model-correction
    /// rotation and the RCP-authored model scale. This preserves the designer's sensor size while
    /// keeping the projection range expressed in real scene metres and aimed at the route.
    private static func installProjectionRig(
        on sensor: Entity,
        sensorCount: Int,
        sensorRange: Float
    ) {
        sensor.children
            .filter { $0.name == projectionRootName }
            .forEach { $0.removeFromParent() }

        let projectionRoot = Entity()
        projectionRoot.name = projectionRootName
        projectionRoot.orientation = sensor.orientation.inverse
        projectionRoot.scale = inverseScale(sensor.scale)
        projectionRoot.addChild(makeSensorLight(sensorCount: sensorCount))
        for waveIndex in 0..<wavefrontCount {
            projectionRoot.addChild(makeWavefront(index: waveIndex, isReturn: false))
            projectionRoot.addChild(makeWavefront(index: waveIndex, isReturn: true))
        }
        projectionRoot.addChild(makeImpactGlow(range: sensorRange))
        sensor.addChild(projectionRoot)
    }

    private static func rebuildLegacySensors(
        on sensorParent: Entity,
        within ufo: Entity,
        sensorCount: Int,
        sensorRange: Float
    ) {
        // This fallback keeps the app usable if a scene is temporarily exported without IR_1 or
        // IR_2, while making the missing authored hookup obvious through legacy entity names.
        ufo.antarDescendants()
            .filter { $0.components[IRSensorComponent.self] != nil }
            .forEach { $0.removeFromParent() }

        for (index, lateralOffset) in IRSensorLayout.lateralOffsets(for: sensorCount).enumerated() {
            let sensor = Entity()
            sensor.name = legacySensorPrefix + String(index + 1)
            sensorParent.addChild(sensor)

            // The fallback sensor still needs the same UFO-root-relative placement as the old
            // procedural array, even when `friendly_ufo` has an authored transform of its own.
            let desiredPositionInUFO = SIMD3<Float>(
                lateralOffset,
                0,
                IRSensorLayout.forwardOffset
            )
            sensor.position = sensorParent.convert(position: desiredPositionInUFO, from: ufo)
            let effectiveRange = projectionRange(
                from: sensor,
                toRouteBelow: ufo,
                baseRange: sensorRange
            )
            sensor.components.set(
                IRSensorComponent(
                    index: index,
                    lateralOffset: lateralOffset,
                    range: effectiveRange,
                    sourceLocalPosition: sensor.position
                )
            )
            installProjectionRig(
                on: sensor,
                sensorCount: sensorCount,
                sensorRange: effectiveRange
            )
        }
    }

    /// `sensorRange` is measured from the moving UFO root to the route surface. Authored sensor
    /// models sit above that root, so their beam must also cover that local height offset; using
    /// the root range alone makes the wave and impact glow visibly stop in mid-air.
    private static func projectionRange(
        from sensor: Entity,
        toRouteBelow ufo: Entity,
        baseRange: Float
    ) -> Float {
        max(baseRange + sensor.position(relativeTo: ufo).y, 0.01)
    }

    private static func removeCodeGeneratedSensors(from ufo: Entity) {
        for child in ufo.antarDescendants() {
            if child.name.hasPrefix(legacySensorPrefix) {
                child.removeFromParent()
                continue
            }
            if let ordinal = sensorOrdinal(named: child.name), ordinal > authoredSensorCount {
                child.removeFromParent()
            }
        }
    }

    private static func removeRuntimeConfiguration(from entity: Entity) {
        entity.components.remove(IRSensorComponent.self)
        entity.children
            .filter { $0.name == projectionRootName }
            .forEach { $0.removeFromParent() }
    }

    private static func removeIndependentAnchoring(from entity: Entity) {
        entity.components.remove(AnchoringComponent.self)
        for descendant in entity.antarDescendants() {
            descendant.components.remove(AnchoringComponent.self)
        }
    }

    private static func sensorOrdinal(named name: String) -> Int? {
        guard name.hasPrefix(sceneSensorPrefix) else { return nil }
        return Int(name.dropFirst(sceneSensorPrefix.count))
    }

    private static func inverseScale(_ scale: SIMD3<Float>) -> SIMD3<Float> {
        SIMD3<Float>(
            abs(scale.x) > 0.0001 ? 1 / scale.x : 1,
            abs(scale.y) > 0.0001 ? 1 / scale.y : 1,
            abs(scale.z) > 0.0001 ? 1 / scale.z : 1
        )
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
