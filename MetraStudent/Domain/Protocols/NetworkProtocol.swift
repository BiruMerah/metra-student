//
//  NetworkProtocol.swift
//  MetraStudent
//
//  Created by Fidel Fausta Cavell on 29/10/26.
//

import Foundation

protocol NetworkProtocol: AnyObject {
    var onEvent: ((NetworkEvent) -> Void)? { get set }
    
    func startSearchingClassrooms()
    
    func stopSearchingClassrooms()
    
    func ensureSearchingIfNeeded()
    
    func joinClassroom(_ discoveredClassroom: DiscoveredClassroom, studentName: String)
    
    func leaveCurrentClassroom()
    
    func stopAll()
}
