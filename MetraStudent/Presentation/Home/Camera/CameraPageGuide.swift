import CoreGraphics
import Foundation

nonisolated enum CameraPageStatus: Equatable, Sendable {
    case searching, moveLeft, moveRight, moveUp, moveDown
    case moveCloser, moveFarther, straighten, holdStill, ready

    var message: String {
        switch self {
        case .searching: "Arahkan kamera hingga keempat sudut halaman terlihat."
        case .moveLeft: "Geser kamera sedikit ke kiri."
        case .moveRight: "Geser kamera sedikit ke kanan."
        case .moveUp: "Geser kamera sedikit ke atas."
        case .moveDown: "Geser kamera sedikit ke bawah."
        case .moveCloser: "Dekatkan kamera sedikit."
        case .moveFarther: "Jauhkan kamera agar seluruh halaman terlihat."
        case .straighten: "Luruskan kamera sejajar dengan halaman."
        case .holdStill: "Posisi sudah baik. Tahan kamera."
        case .ready: "Halaman siap. Ketuk dua kali di mana saja untuk mengambil foto."
        }
    }
}

nonisolated struct CameraPageGeometry {
    let topLeft: CGPoint
    let topRight: CGPoint
    let bottomRight: CGPoint
    let bottomLeft: CGPoint

    var corners: [CGPoint] { [topLeft, topRight, bottomRight, bottomLeft] }

    var hasFullPage: Bool {
        corners.allSatisfy { (0.025...0.975).contains($0.x) && (0.025...0.975).contains($0.y) }
    }

    var coverage: CGFloat {
        let width = (distance(topLeft, topRight) + distance(bottomLeft, bottomRight)) / 2
        let height = (distance(topLeft, bottomLeft) + distance(topRight, bottomRight)) / 2
        return width * height
    }

    var alignment: CameraPageStatus {
        guard hasFullPage, coverage <= 0.88 else { return .moveFarther }
        guard coverage >= 0.20 else { return .moveCloser }
        let tilt = abs(atan2(topRight.y - topLeft.y, topRight.x - topLeft.x))
        guard tilt <= 0.18 else { return .straighten }

        // Vision coordinates start at the lower-left corner of the image.
        let centerX = corners.reduce(0) { $0 + $1.x } / 4
        let centerY = corners.reduce(0) { $0 + $1.y } / 4
        if centerX < 0.38 { return .moveLeft }
        if centerX > 0.62 { return .moveRight }
        if centerY < 0.38 { return .moveDown }
        if centerY > 0.62 { return .moveUp }
        return .holdStill
    }

    func isStable(comparedTo other: Self) -> Bool {
        zip(corners, other.corners).allSatisfy { distance($0, $1) <= 0.025 }
    }

    private func distance(_ first: CGPoint, _ second: CGPoint) -> CGFloat {
        hypot(first.x - second.x, first.y - second.y)
    }
}

nonisolated struct CameraPageGuide {
    private(set) var status: CameraPageStatus = .searching
    private var stablePage: CameraPageGeometry?
    private var stableSince: TimeInterval = 0
    private var lastFrameTime: TimeInterval?

    mutating func update(page: CameraPageGeometry?, at time: TimeInterval) {
        let previousFrame = lastFrameTime
        lastFrameTime = time
        status = page?.alignment ?? .searching

        guard let page, status == .holdStill else {
            stablePage = nil
            return
        }

        guard let stablePage, let previousFrame, time - previousFrame <= 0.8,
              page.isStable(comparedTo: stablePage) else {
            self.stablePage = page
            stableSince = time
            return
        }

        if time - stableSince >= 0.65 {
            status = .ready
        }
    }

    func canCapture(at time: TimeInterval) -> Bool {
        guard let lastFrameTime else { return false }
        return status == .ready && time - lastFrameTime <= 0.8
    }
}
