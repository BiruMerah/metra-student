//
//  NetworkManager.swift
//  MetraStudent
//
//  Created by Fidel Fausta Cavell on 29/10/26.
//

import Foundation
import Network

final class NetworkManager: NetworkProtocol {
    static let bonjourServiceType = "_classroom-poc._tcp"
    
    typealias ClassroomProtocol = Coder<NetworkMessageContract, NetworkMessageContract, NetworkJSONCoder>
    typealias ClassroomConnection = NetworkConnection<ClassroomProtocol>
    
    private var localPeerID: String = UUID().uuidString
    private var isSearching: Bool = false
    private var browsingTask: Task<Void, Never>?
    private var studentConnectionTask: Task<Void, Never>?
    private var activeStudentConnection: ClassroomConnection?
    private var discoveredEndpoints: [String: Bonjour.Endpoint] = [:]
    
    var onEvent: ((NetworkEvent) -> Void)?
    
    func startSearchingClassrooms() {
        browsingTask?.cancel()
        isSearching = true
        discoveredEndpoints.removeAll()
        onEvent?(.classroomUpdated([]))
        onEvent?(.searchingChanged(true))
        
        browsingTask = Task { [weak self] in
            guard let self else { return }
            do {
                let browser = NetworkBrowser(
                    for: .bonjour(Self.bonjourServiceType, includeTxtRecord: true)
                )
                
                browser.onStateUpdate { [weak self] _, state in
                    guard let self else { return }
                    if case .failed(let error) = state {
                        self.isSearching = false
                        self.onEvent?(.searchingChanged(false))
                        self.onEvent?(.searchFailed(error.localizedDescription))
                    }
                }
                
                try await browser.run { [weak self] endpoints in
                    self?.handleDiscoveredEndpoints(endpoints)
                }
                
            } catch is CancellationError {
                // Normal Stop
            } catch {
                self.isSearching = false
                self.onEvent?(.searchingChanged(false))
                self.onEvent?(.searchFailed(error.localizedDescription))
            }
        }
    }
    
    func stopSearchingClassrooms() {
        browsingTask?.cancel()
        browsingTask = nil
        isSearching = false
        onEvent?(.searchingChanged(false))
    }
    
    func ensureSearchingIfNeeded() {
        if !isSearching {
            startSearchingClassrooms()
        }
    }
    
    func joinClassroom(_ discoveredClassroom: DiscoveredClassroom, studentName: String) {
        studentConnectionTask?.cancel()
        activeStudentConnection = nil
        onEvent?(.classroomConnecting(discoveredClassroom))
        
        let studentID = localPeerID
        let endpoint = discoveredEndpoints[discoveredClassroom.id]
        studentConnectionTask = Task { [weak self] in
            guard let self else { return }
            guard let endpoint else { return }
            let connection = NetworkConnection(to: endpoint) {
                Coder(NetworkMessageContract.self, using: .json) {
                    TCP()
                }
            }
            self.activeStudentConnection = connection
            
            connection.onStateUpdate { [weak self] _, state in
                guard let self, self.activeStudentConnection === connection else { return }
                switch state {
                case .ready:
                    self.onEvent?(.classroomConnected(discoveredClassroom))
                    
                case .failed, .cancelled:
                    self.activeStudentConnection = nil
                    self.onEvent?(.classroomDisconnected(classroomId: discoveredClassroom.id))
                    
                default:
                    break
                }
            }
            
            do {
                try await connection.send(.studentInformation(id: studentID, name: studentName))
                for try await message in connection.messages {
                    switch message.content {
                    case .classroomSync(let payload):
                        self.onEvent?(
                            .classroomSynced(
                                classroomId: discoveredClassroom.id,
                                classroomName: payload.classroomName,
                                teacherName: payload.teacherName,
                                materials: payload.materials.map { $0.toDomain() }
                            )
                        )
                    case .studentInformation:
                        break
                    }
                }
                
            } catch is CancellationError {
                // Normal cancellation when leaving or switching classrooms
            } catch {
                print("Classroom connection error: \(error)")
            }
            
            if self.activeStudentConnection === connection {
                self.activeStudentConnection = nil
                self.onEvent?(.classroomDisconnected(classroomId: discoveredClassroom.id))
            }
        }
    }
    
    func leaveCurrentClassroom() {
        studentConnectionTask?.cancel()
        studentConnectionTask = nil
        activeStudentConnection = nil
        onEvent?(.leftClassroom)
    }
    
    func stopAll() {
        browsingTask?.cancel()
        browsingTask = nil
        studentConnectionTask?.cancel()
        studentConnectionTask = nil
        activeStudentConnection = nil
        discoveredEndpoints.removeAll()
        isSearching = false
        onEvent?(.resetAll)
    }
    
    private func handleDiscoveredEndpoints(_ endpoints: [Bonjour.Endpoint]) {
        var nextEndpoints: [String: Bonjour.Endpoint] = [:]
        let updatedClassrooms = endpoints.map { endpoint in
            let classroomName = endpoint.txtRecord["classroomName"]
                ?? endpoint.txtRecord["roomName"]
                ?? endpoint.name
            let teacherName = endpoint.txtRecord["teacherName"] ?? endpoint.name
            let classroomID = "\(endpoint.name)|\(classroomName)|\(teacherName)"
            nextEndpoints[classroomID] = endpoint
            return DiscoveredClassroom(
                id: classroomID,
                classroomName: classroomName,
                teacherName: teacherName
            )
        }
        discoveredEndpoints = nextEndpoints
        onEvent?(.classroomUpdated(updatedClassrooms))
    }
}
