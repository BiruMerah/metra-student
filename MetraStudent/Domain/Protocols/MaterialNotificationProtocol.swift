import Foundation

@MainActor
protocol MaterialNotificationProtocol: AnyObject {
    func requestAuthorizationIfNeeded() async
    func notifyNewMaterials(_ materials: [MathMaterialModel], classroomID: String, classroomName: String)
}
