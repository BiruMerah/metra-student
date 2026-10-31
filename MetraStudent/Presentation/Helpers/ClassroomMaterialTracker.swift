import Foundation

struct ClassroomMaterialTracker {
    private var seenMaterialIDs: [String: Set<UUID>] = [:]

    mutating func newMaterials(in materials: [MathMaterialModel], classroomID: String) -> [MathMaterialModel] {
        var seen = seenMaterialIDs[classroomID, default: []]
        let newMaterials = materials.filter { seen.insert($0.id).inserted }
        seenMaterialIDs[classroomID] = seen
        return newMaterials
    }

    mutating func reset() {
        seenMaterialIDs.removeAll()
    }
}
