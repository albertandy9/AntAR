//
//  IRSimulationSystem.swift
//  AntAR
//

import RealityKit
import simd

/// Simulates the analog reflectance array used by a physical line-following robot.
///
/// Each sensor samples the actual visible bounds of the placed incoming block below it. The
/// displayed block color and its `IRReflectanceComponent` are therefore always consistent.
public struct IRSimulationSystem: System {
    private static let ufoQuery = EntityQuery(
        where: .has(UFOPathFollowerComponent.self) && .has(IRSensorArrayComponent.self)
    )
    private static let sensorQuery = EntityQuery(where: .has(IRSensorComponent.self))
    private static let tileQuery = EntityQuery(
        where: .has(PathTileComponent.self) && .has(IRReflectanceComponent.self)
    )
    public init(scene: RealityKit.Scene) {}

    public func update(context: SceneUpdateContext) {
        let tiles = context.entities(
            matching: Self.tileQuery,
            updatingSystemWhen: .rendering
        ).compactMap { entity -> (Entity, PathTileComponent, IRReflectanceComponent)? in
            guard let tile = entity.components[PathTileComponent.self],
                  let material = entity.components[IRReflectanceComponent.self],
                  tile.isPlaced else {
                return nil
            }
            return (entity, tile, material)
        }.sorted { $0.1.order < $1.1.order }

        for ufo in context.entities(matching: Self.ufoQuery, updatingSystemWhen: .rendering) {
            guard var readings = ufo.components[IRSensorArrayComponent.self],
                  ufo.components[UFOPathFollowerComponent.self] != nil else { continue }

            let sensors = ufo.children.compactMap { sensorEntity -> (Entity, IRSensorComponent)? in
                guard let sensor = sensorEntity.components[IRSensorComponent.self] else { return nil }
                return (sensorEntity, sensor)
            }
            .sorted { $0.1.index < $1.1.index }

            var lineSignals: [Float] = []
            var reflectances: [Float] = []
            var samplingTiles: [Bool] = []

            for (sensorEntity, sensor) in sensors {
                let sensorPosition = sensorEntity.position(relativeTo: nil)
                let sampledTile = tile(under: sensorPosition, tiles: tiles)

                let reflectance: Float
                let lineSignal: Float
                if let sampledTile {
                    reflectance = sampledTile.reflectance
                    lineSignal = sampledTile.isValidPath ? 1 - reflectance : 0
                } else {
                    reflectance = 0.96
                    lineSignal = 0
                }
                let isSamplingTile = sampledTile != nil

                lineSignals.append(lineSignal)
                reflectances.append(reflectance)
                samplingTiles.append(isSamplingTile)

                var updatedSensor = sensor
                updatedSensor.lineSignal = lineSignal
                updatedSensor.wavePhase = normalizedPhase(
                    sensor.wavePhase + Float(context.deltaTime) * 1.65
                )
                sensorEntity.components[IRSensorComponent.self] = updatedSensor
                IRSensorFactory.applyBeamAppearance(
                    to: sensorEntity,
                    lineSignal: lineSignal,
                    reflectance: reflectance,
                    isSamplingTile: isSamplingTile,
                    wavePhase: updatedSensor.wavePhase,
                    range: updatedSensor.range
                )
            }

            readings.lineSignals = lineSignals
            readings.sampledReflectance = reflectances
            readings.isSamplingTile = samplingTiles
            ufo.components[IRSensorArrayComponent.self] = readings
        }
    }

    private func tile(
        under sensorPosition: SIMD3<Float>,
        tiles: [(Entity, PathTileComponent, IRReflectanceComponent)]
    ) -> IRReflectanceComponent? {
        return tiles.first { entity, _, _ in
            let bounds = entity.visualBounds(relativeTo: nil)
            let tolerance: Float = 0.008
            return sensorPosition.x >= bounds.min.x - tolerance
                && sensorPosition.x <= bounds.max.x + tolerance
                && sensorPosition.z >= bounds.min.z - tolerance
                && sensorPosition.z <= bounds.max.z + tolerance
        }?.2
    }

    private func normalizedPhase(_ value: Float) -> Float {
        value - floor(value)
    }
}
