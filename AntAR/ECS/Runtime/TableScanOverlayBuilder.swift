//
//  TableScanOverlayBuilder.swift
//  AntAR
//
//  Builds a one-time visual snapshot of the real table's scanned shape from LiDAR mesh data,
//  textured with RingPatternTexture — the confirmation overlay shown once a table is detected.
//  Built once, from whatever .table-classified mesh data exists at that instant (see
//  ARViewContainer's call site for why this isn't kept in sync as ARKit refines its mesh further).
//
//  Low-level ARMeshGeometry buffer parsing below follows Apple's own documented pattern (see
//  "Visualizing and Interacting with a Reconstructed Scene") — RealityKit has no higher-level API
//  for reading per-face mesh classification.
//

import ARKit
import RealityKit

enum TableScanOverlayBuilder {
    // How many meters of real table one texture tile covers — tunable; smaller values make the
    // ring pattern denser.
    private static let tileWorldSize: Float = 0.12
    // Lifted this far above the flattened plane height so the overlay doesn't z-fight with the
    // real table surface in the camera feed.
    private static let liftAboveSurface: Float = 0.002

    /// - Parameters:
    ///   - anchors: the current frame's ARAnchors (ARMeshAnchor instances are filtered out of this).
    ///   - planeTransform: scannedTable's world transform — flattens mesh-noise Y positions onto
    ///     the real plane height (LiDAR depth noise is a couple of centimeters; rendering raw mesh
    ///     Y speckles/z-fights against the real table) and supplies the UV axes for the texture.
    ///   - nearPoint: scannedTable's own world position — filters out .table-classified faces
    ///     belonging to some OTHER table elsewhere in the room.
    static func build(
        from anchors: [ARAnchor],
        planeTransform: simd_float4x4,
        nearPoint: SIMD3<Float>,
        maxRadius: Float = 1.5
    ) -> ModelEntity? {
        let planeNormal = normalize(SIMD3<Float>(planeTransform.columns.1.x, planeTransform.columns.1.y, planeTransform.columns.1.z))
        let planeOrigin = SIMD3<Float>(planeTransform.columns.3.x, planeTransform.columns.3.y, planeTransform.columns.3.z)
        let planeRight = normalize(SIMD3<Float>(planeTransform.columns.0.x, planeTransform.columns.0.y, planeTransform.columns.0.z))
        let planeForward = normalize(SIMD3<Float>(planeTransform.columns.2.x, planeTransform.columns.2.y, planeTransform.columns.2.z))

        var positions: [SIMD3<Float>] = []
        var uvs: [SIMD2<Float>] = []
        var indices: [UInt32] = []

        // Diagnostics only — a nil result otherwise gives no way to tell "no LiDAR classification
        // at all" from "found a table but nothing classified as .table yet" from "found .table
        // faces, but none near enough to this table" apart.
        var meshAnchorCount = 0
        var classifiedAnchorCount = 0
        var tableFaceCount = 0
        var survivingFaceCount = 0

        for anchor in anchors {
            guard let meshAnchor = anchor as? ARMeshAnchor else { continue }
            meshAnchorCount += 1
            guard let classificationSource = meshAnchor.geometry.classification else { continue }
            classifiedAnchorCount += 1

            let geometry = meshAnchor.geometry
            let vertexSource = geometry.vertices
            let faces = geometry.faces
            let meshTransform = meshAnchor.transform

            for faceIndex in 0..<faces.count {
                guard classification(ofFace: faceIndex, in: classificationSource) == .table else { continue }
                tableFaceCount += 1

                let worldPositions = vertexIndices(ofFace: faceIndex, in: faces).map { index -> SIMD3<Float> in
                    let local = vertex(at: index, in: vertexSource)
                    let world = meshTransform * SIMD4<Float>(local, 1)
                    return SIMD3<Float>(world.x, world.y, world.z)
                }
                guard worldPositions.count == 3 else { continue }

                let centroid = (worldPositions[0] + worldPositions[1] + worldPositions[2]) / 3
                guard simd_length(centroid - nearPoint) <= maxRadius else { continue }
                survivingFaceCount += 1

                let baseIndex = UInt32(positions.count)
                for worldPosition in worldPositions {
                    let offsetFromPlane = worldPosition - planeOrigin
                    let distanceAlongNormal = simd_dot(offsetFromPlane, planeNormal)
                    let flattened = worldPosition - distanceAlongNormal * planeNormal + planeNormal * liftAboveSurface
                    positions.append(flattened)

                    let localOffset = flattened - planeOrigin
                    let u = simd_dot(localOffset, planeRight) / tileWorldSize
                    let v = simd_dot(localOffset, planeForward) / tileWorldSize
                    uvs.append(SIMD2<Float>(u, v))
                }
                indices.append(contentsOf: [baseIndex, baseIndex + 1, baseIndex + 2])
            }
        }

        print("[TableScanOverlayBuilder] meshAnchors=\(meshAnchorCount) classified=\(classifiedAnchorCount) tableFaces=\(tableFaceCount) survivingFaces=\(survivingFaceCount)")

        guard !positions.isEmpty else { return nil }

        var descriptor = MeshDescriptor(name: "TableScanOverlay")
        descriptor.positions = MeshBuffers.Positions(positions)
        descriptor.textureCoordinates = MeshBuffers.TextureCoordinates(uvs)
        descriptor.primitives = .triangles(indices)

        guard let mesh = try? MeshResource.generate(from: [descriptor]) else { return nil }

        var material = UnlitMaterial()
        // Raw mesh triangles carry whatever winding order ARKit happened to generate — not
        // guaranteed consistent once flattened onto the plane — so single-sided culling would
        // silently drop some faces and leave a patchy/holey look. Rendering both sides is cheap for
        // a small, one-time overlay mesh.
        material.faceCulling = .none
        if let texture = try? TextureResource(image: RingPatternTexture.image, options: .init(semantic: .color)) {
            material.color = .init(tint: .white, texture: .init(texture))
        } else {
            material.color = .init(tint: .white)
        }

        return ModelEntity(mesh: mesh, materials: [material])
    }

    private static func classification(ofFace faceIndex: Int, in source: ARGeometrySource) -> ARMeshClassification {
        let pointer = source.buffer.contents().advanced(by: source.offset + source.stride * faceIndex)
        let rawValue = pointer.assumingMemoryBound(to: UInt8.self).pointee
        return ARMeshClassification(rawValue: Int(rawValue)) ?? .none
    }

    private static func vertexIndices(ofFace faceIndex: Int, in element: ARGeometryElement) -> [UInt32] {
        let indicesPerFace = element.indexCountPerPrimitive
        let bytesPerIndex = element.bytesPerIndex
        let faceStartOffset = faceIndex * indicesPerFace * bytesPerIndex
        let buffer = element.buffer.contents()

        return (0..<indicesPerFace).map { offset in
            let pointer = buffer.advanced(by: faceStartOffset + offset * bytesPerIndex)
            if bytesPerIndex == 2 {
                return UInt32(pointer.assumingMemoryBound(to: UInt16.self).pointee)
            } else {
                return pointer.assumingMemoryBound(to: UInt32.self).pointee
            }
        }
    }

    private static func vertex(at index: UInt32, in source: ARGeometrySource) -> SIMD3<Float> {
        let pointer = source.buffer.contents().advanced(by: source.offset + source.stride * Int(index))
        return pointer.assumingMemoryBound(to: SIMD3<Float>.self).pointee
    }
}
