#if os(iOS)
import Foundation
import CoreGraphics

/// Normalized, upright image coordinates, origin at the bottom left (Vision/Core Image).
struct DocumentQuadrilateral: Sendable, Equatable {
    let topLeft: CGPoint
    let topRight: CGPoint
    let bottomRight: CGPoint
    let bottomLeft: CGPoint
    var points: [CGPoint] { [topLeft, bottomLeft, bottomRight, topRight] }
    var bounds: CGRect {
        let xs = points.map(\.x), ys = points.map(\.y)
        return CGRect(x: xs.min() ?? 0, y: ys.min() ?? 0,
                      width: (xs.max() ?? 0) - (xs.min() ?? 0), height: (ys.max() ?? 0) - (ys.min() ?? 0))
    }
    var area: CGFloat { Self.area(points) }
    var isValid: Bool {
        points.allSatisfy { $0.x.isFinite && $0.y.isFinite && (0...1).contains($0.x) && (0...1).contains($0.y) }
            && area > 0.025 && zip(points, Array(points.dropFirst()) + [points[0]]).allSatisfy {
                hypot($0.x - $1.x, $0.y - $1.y) > 0.07
            }
            && (0..<4).allSatisfy { Self.cross(points[$0], points[($0 + 1) % 4], points[($0 + 2) % 4]) > 0 }
    }
    func contains(_ point: CGPoint, tolerance: CGFloat = 0.002) -> Bool {
        (0..<4).allSatisfy { Self.cross(points[$0], points[($0 + 1) % 4], point) >= -tolerance }
    }
    func intersectionArea(with other: Self) -> CGFloat {
        var polygon = points
        for index in 0..<4 {
            let a = other.points[index], b = other.points[(index + 1) % 4]
            let input = polygon
            polygon = []
            guard var previous = input.last else { return 0 }
            for current in input {
                let currentSide = Self.cross(a, b, current), previousSide = Self.cross(a, b, previous)
                if (currentSide >= 0) != (previousSide >= 0) {
                    let t = previousSide / (previousSide - currentSide)
                    polygon.append(CGPoint(x: previous.x + t * (current.x - previous.x), y: previous.y + t * (current.y - previous.y)))
                }
                if currentSide >= 0 { polygon.append(current) }
                previous = current
            }
        }
        return Self.area(polygon)
    }
    private static func cross(_ a: CGPoint, _ b: CGPoint, _ p: CGPoint) -> CGFloat {
        (b.x - a.x) * (p.y - a.y) - (b.y - a.y) * (p.x - a.x)
    }
    private static func area(_ points: [CGPoint]) -> CGFloat {
        guard points.count >= 3 else { return 0 }
        return abs(points.indices.reduce(CGFloat.zero) { total, i in
            let a = points[i], b = points[(i + 1) % points.count]
            return total + a.x * b.y - b.x * a.y
        }) / 2
    }
}

enum DocumentBoundarySelection {
    /// Keep the outer sheet, not its internal tables, diagrams, or duplicate edges.
    static func outermost(_ candidates: [DocumentQuadrilateral]) -> [DocumentQuadrilateral] {
        var selected: [DocumentQuadrilateral] = []
        for candidate in candidates.filter(\.isValid).sorted(by: { $0.area > $1.area }) {
            if selected.contains(where: { candidate.intersectionArea(with: $0) / candidate.area > 0.85 }) { continue }
            selected.append(candidate)
        }
        return selected
    }
    static func overlaps(_ pages: [DocumentQuadrilateral]) -> Bool {
        for i in pages.indices {
            for j in pages.indices where j > i {
                if pages[i].intersectionArea(with: pages[j]) / min(pages[i].area, pages[j].area) > 0.12 { return true }
            }
        }
        return false
    }
    /// Stable row grouping avoids a non-transitive comparator for tilted sheets.
    static func readingOrder(_ pages: [DocumentQuadrilateral]) -> [DocumentQuadrilateral] {
        var remaining = pages.sorted { $0.bounds.midY > $1.bounds.midY }
        var ordered: [DocumentQuadrilateral] = []
        while let first = remaining.first {
            let row = remaining.filter { abs($0.bounds.midY - first.bounds.midY) < min($0.bounds.height, first.bounds.height) * 0.45 }
            ordered += row.sorted { $0.bounds.midX < $1.bounds.midX }
            remaining.removeAll { row.contains($0) }
        }
        return ordered
    }
}

#endif
