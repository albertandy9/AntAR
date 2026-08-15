//
//  IRSimulationSystem.swift
//  AntAR
//

import RealityKit
import simd

/// Simulates the analog reflectance array used by a physical line-following robot.
///
/// Each sensor samples the cached local footprint of the placed incoming block below it. The
/// displayed block color and its `IRReflectanceComponent` remain consistent without traversing
/// rendered geometry in the per-frame update loop.
public struct IRSimulationSystem: System {
    private struct SampleTile {
        let entity: Entity
        let tile: PathTileComponent
        let material: IRReflectanceComponent
    }

    private static let directorQuery = EntityQuery(where: .has(GameStateComponent.self))
    private static let cameraQuery = EntityQuery(where: .has(PlayerCameraComponent.self))
    private static let ufoQuery = EntityQuery(
        where: .has(UFOPathFollowerComponent.self) && .has(IRSensorArrayComponent.self)
    )
    private static let tileQuery = EntityQuery(
        where: .has(PathTileComponent.self) && .has(IRReflectanceComponent.self)
    )
    private static let visualRefreshInterval: Float = 1.0 / 24.0
    private static let maximumVisualDistance: Float = 2.5

    public init(scene: RealityKit.Scene) {}

    public func update(context: SceneUpdateContext) {
        guard context.entities(
            matching: Self.directorQuery,
            updatingSystemWhen: .rendering
        ).contains(where: {
            $0.components[GameStateComponent.self]?.current.supportsRouteBuilding == true
        }) else {
            return
        }

        let cameraPosition = context.entities(
            matching: Self.cameraQuery,
            updatingSystemWhen: .rendering
        ).first(where: { $0.isAnchored })?.position(relativeTo: nil)

        let tiles = context.entities(
            matching: Self.tileQuery,
            updatingSystemWhen: .rendering
        ).compactMap { entity -> SampleTile? in
            guard let tile = entity.components[PathTileComponent.self],
                  let material = entity.components[IRReflectanceComponent.self],
                  tile.isPlaced else {
                return nil
            }
            return SampleTile(entity: entity, tile: tile, material: material)
        }.sorted { $0.tile.order < $1.tile.order }

        for ufo in context.entities(matching: Self.ufoQuery, updatingSystemWhen: .rendering) {
            guard var readings = ufo.components[IRSensorArrayComponent.self] else { continue }

            let sensors = ufo.children.compactMap { sensorEntity -> (Entity, IRSensorComponent)? in
                guard let sensor = sensorEntity.components[IRSensorComponent.self] else { return nil }
                return (sensorEntity, sensor)
            }
            .sorted { $0.1.index < $1.1.index }

            if readings.lineSignals.count != sensors.count {
                readings = IRSensorArrayComponent(sensorCount: sensors.count)
            }

            let shouldRenderVisuals = ufo.isEnabled && cameraPosition.map {
                simd_distance($0, ufo.position(relativeTo: nil)) <= Self.maximumVisualDistance
            } ?? true
            readings.visualUpdateAccumulator += Float(context.deltaTime)
            let shouldRefreshVisuals = shouldRenderVisuals
                && readings.visualUpdateAccumulator >= Self.visualRefreshInterval
            let visualDelta = readings.visualUpdateAccumulator

            if shouldRefreshVisuals {
                readings.visualUpdateAccumulator.formTruncatingRemainder(
                    dividingBy: Self.visualRefreshInterval
                )
            } else if !shouldRenderVisuals {
                // Keep one refresh queued so visuals are correct immediately when they re-enter
                // the useful camera range.
                readings.visualUpdateAccumulator = Self.visualRefreshInterval
            }

            for (arrayIndex, pair) in sensors.enumerated() {
                let (sensorEntity, sensor) = pair
                if sensorEntity.isEnabled != shouldRenderVisuals {
                    sensorEntity.isEnabled = shouldRenderVisuals
                }

                let sensorPosition = sensorEntity.position(relativeTo: nil)
                let sampledTile = tile(under: sensorPosition, tiles: tiles)

                let reflectance: Float
                let lineSignal: Float
                if let sampledTile {
                    reflectance = sampledTile.material.reflectance
                    lineSignal = sampledTile.material.isValidPath ? 1 - reflectance : 0
                } else {
                    reflectance = 0.96
                    lineSignal = 0
                }
                let isSamplingTile = sampledTile != nil

                readings.lineSignals[arrayIndex] = lineSignal
                readings.sampledReflectance[arrayIndex] = reflectance
                readings.isSamplingTile[arrayIndex] = isSamplingTile

                var updatedSensor = sensor
                updatedSensor.lineSignal = lineSignal
                if shouldRefreshVisuals {
                    updatedSensor.wavePhase = normalizedPhase(
                        sensor.wavePhase + visualDelta * 1.65
                    )
                    IRSensorFactory.applyBeamAppearance(
                        to: sensorEntity,
                        lineSignal: lineSignal,
                        reflectance: reflectance,
                        isSamplingTile: isSamplingTile,
                        wavePhase: updatedSensor.wavePhase,
                        range: updatedSensor.range
                    )
                }
                if updatedSensor != sensor {
                    sensorEntity.components[IRSensorComponent.self] = updatedSensor
                }
            }

            ufo.components[IRSensorArrayComponent.self] = readings
        }
    }

    private func tile(
        under sensorPosition: SIMD3<Float>,
        tiles: [SampleTile]
    ) -> SampleTile? {
        tiles.first { sample in
            let localPosition = sample.entity.convert(position: sensorPosition, from: nil)
            let tolerance: Float = 0.008
            let center = sample.tile.footprintCenter
            let halfExtents = sample.tile.footprintHalfExtents
            return abs(localPosition.x - center.x) <= halfExtents.x + tolerance
                && abs(localPosition.z - center.y) <= halfExtents.y + tolerance
        }
    }

    private func normalizedPhase(_ value: Float) -> Float {
        value - floor(value)
    }
}
