//
//  ChannelViewModel.swift
//  MetraStudent
//
//  Created by Fidel Fausta Cavell on 06/11/26.
//

import Foundation
import Observation

@Observable
@MainActor
final class ChannelViewModel {
    // MARK: - Dependencies
    private let mathMaterialRepository: MathMaterialProtocol
    private let notificationManager: NotificationProtocol
    weak var coordinator: (any AppCoordinating)?
    
    init(
        mathMaterialRepository: MathMaterialProtocol,
        notificationManager: NotificationProtocol,
        coordinator: (any AppCoordinating)? = nil
    ) {
        self.mathMaterialRepository = mathMaterialRepository
        self.notificationManager = notificationManager
        self.coordinator = coordinator
    }
    
    // TODO - Functions
}
