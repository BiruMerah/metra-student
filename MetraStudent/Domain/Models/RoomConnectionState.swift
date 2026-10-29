//
//  RoomConnectionState.swift
//  MetraStudent
//
//  Created by Fidel Fausta Cavell on 29/10/26.
//

import Foundation

// Define connection state that used by Network
enum RoomConnectionState: Equatable, Sendable {
    case notConnected
    case connecting
    case connected
}
