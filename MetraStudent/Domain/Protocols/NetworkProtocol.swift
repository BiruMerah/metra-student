//
//  NetworkProtocol.swift
//  MetraStudent
//
//  Created by Fidel Fausta Cavell on 29/10/26.
//

import Foundation

protocol NetworkProtocol {
    func startSearchingRooms()
    
    func stopSearchingRooms()
    
    func ensureSearchingIfNeeded()
    
    func stopAll()
    
    func joinRoom(_ room: DiscoveredRoom)
}
