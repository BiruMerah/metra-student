//
//  AppCoordinator.swift
//  MetraStudent
//
//  Created by Fidel Fausta Cavell on 29/10/26.
//

import Foundation
import Observation
import SwiftUI

@Observable
@MainActor
final class AppCoordinator {
    var path = NavigationPath()
    
    let mathMaterialRepository: MathMaterialProtocol
    
    init(mathMaterialRepository: MathMaterialProtocol) {
        self.mathMaterialRepository = mathMaterialRepository
    }
    
    func navigate(to route: AppRoutes) {
        path.append(route)
    }
    
    func navigateBack() {
        if !path.isEmpty {
            path.removeLast()
        }
    }
    
    func popToRoot() {
        path.removeLast(path.count)
    }
    
    @ViewBuilder
    func buildClassroom() -> some View {
        ClassroomView(coordinator: self)
    }
    
    @ViewBuilder
    func buildView(route: AppRoutes) -> some View {
        switch route {
        case .classroom:
            ClassroomView(coordinator: self)
            
        case .library:
            let viewModel = LibraryViewModel(coordinator: self, mathMaterialRepository: mathMaterialRepository)
            LibraryView(viewModel: viewModel)
            
        case .materialDetail:
            MaterialDetailView()
        }
    }
}
