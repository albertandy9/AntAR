//
//  IRSimulationSystem.swift
//  AntAR
//

import RealityKit
import simd

/// Simulates the analog reflectance array used by a physical line-following robot.
///
/// The authored tile centers define a continuous route polyline. Each sensor measures its
/// horizontal distance from that line, producing a smooth activation near the line edge instead
/// of giving every sensor the same value for an entire square tile.
public struct IRSimulationSystem: System {
    public static let dependencies: [SystemDependency] = [.after(SceneBindingSystem.self)]

    private static let ufoQuery = EntityQuery(
        where: .has(UFOPathFollowerComponent.self) && .has(IRSensorArrayComponent.self)
    )
    private static let sensorQuery = EntityQuery(where: .has(IRSensorComponent.self))
    private static let tileQuery = EntityQuery(
        where: .has(PathTileComponent.self) && .has(IRReflectanceComponent.self)
    )
    private static let homeQuery = EntityQuery(where: .has(HomeComponent.self))

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

        let home = context.entities(
            matching: Self.homeQuery,
            updatingSystemWhen: .rendering
        ).first(where: { _ in true })

        for ufo in context.entities(matching: Self.ufoQuery, updatingSystemWhen: .rendering) {
            guard var readings = ufo.components[IRSensorArrayComponent.self],
                  let follower = ufo.components[UFOPathFollowerComponent.self] else { continue }

            var routePoints = tiles.map { $0.0.position(relativeTo: nil) }
            if let routeStart = follower.routeStartPosition {
                routePoints.insert(routeStart, at: 0)
            }
            if let home {
                routePoints.append(home.position(relativeTo: nil))
            }

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
                let lineDistance = distanceFromRoute(sensorPosition, routePoints: routePoints)
                let geometricActivation = lineActivation(at: lineDistance)

                let reflectance: Float
                let lineSignal: Float
                if let sampledTile, !sampledTile.isValidPath {
                    // A light route block strongly returns the emitted IR and therefore produces
                    // no dark-line activation. The travel system uses this to demonstrate stall.
                    reflectance = sampledTile.reflectance
                    lineSignal = 0
                } else {
                    // Approximate a real analog sensor: the dark center absorbs most IR, while
                    // the light floor outside the line returns almost all of it. The smooth edge
                    // is what lets weighted sensor readings steer instead of merely switching.
                    reflectance = mix(0.96, 0.08, geometricActivation)
                    lineSignal = 1 - reflectance
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
        let tileRadius: Float = 0.25
        return tiles.first { entity, _, _ in
            let tilePosition = entity.position(relativeTo: nil)
            return simd_distance(
                SIMD2(sensorPosition.x, sensorPosition.z),
                SIMD2(tilePosition.x, tilePosition.z)
            ) <= tileRadius
        }?.2
    }

    private func distanceFromRoute(
        _ point: SIMD3<Float>,
        routePoints: [SIMD3<Float>]
    ) -> Float {
        guard routePoints.count >= 2 else { return .greatestFiniteMagnitude }
        let point2D = SIMD2(point.x, point.z)

        return zip(routePoints, routePoints.dropFirst()).reduce(Float.greatestFiniteMagnitude) {
            nearest, pair in
            let start = SIMD2(pair.0.x, pair.0.z)
            let end = SIMD2(pair.1.x, pair.1.z)
            let segment = end - start
            let lengthSquared = simd_length_squared(segment)
            guard lengthSquared > 0.000001 else {
                return min(nearest, simd_distance(point2D, start))
            }

            let progress = min(max(simd_dot(point2D - start, segment) / lengthSquared, 0), 1)
            let closest = start + segment * progress
            return min(nearest, simd_distance(point2D, closest))
        }
    }

    /// Matches the HTML visualizer's smoothed transition at the edge of the dark line.
    private func lineActivation(at distance: Float) -> Float {
        let darkCoreHalfWidth: Float = 0.018
        let outerEdge: Float = 0.060
        guard distance > darkCoreHalfWidth else { return 1 }
        guard distance < outerEdge else { return 0 }

        let t = (distance - darkCoreHalfWidth) / (outerEdge - darkCoreHalfWidth)
        let smooth = t * t * (3 - 2 * t)
        return 1 - smooth
    }

    private func mix(_ lightSurface: Float, _ darkLine: Float, _ activation: Float) -> Float {
        lightSurface + (darkLine - lightSurface) * min(max(activation, 0), 1)
    }

    private func normalizedPhase(_ value: Float) -> Float {
        value - floor(value)
    }
}
