//
//  DocumentViewModel.swift
//  MetraStudent
//
//  Created by Fidel Fausta Cavell on 06/11/26.
//

import Foundation
import Observation

@Observable
@MainActor
final class DocumentViewModel {
    // MARK: - Dependencies
    private let mathMaterialRepository: MathMaterialProtocol
    weak var coordinator: (any AppCoordinating)?
    
    init(
        mathMaterialRepository: MathMaterialProtocol,
        coordinator: (any AppCoordinating)? = nil
    ) {
        self.mathMaterialRepository = mathMaterialRepository
        self.coordinator = coordinator
    }
    
    // TODO
}
