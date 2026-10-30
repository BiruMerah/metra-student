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
    
    let networkManager: NetworkProtocol
    let mathMaterialRepository: MathMaterialProtocol
    
    @ObservationIgnored
    lazy var classroomViewModel = ClassroomViewModel(
        coordinator: self,
        networkManager: networkManager,
        mathMaterialRepository: mathMaterialRepository
    )
    
    init(networkManager: NetworkProtocol, mathMaterialRepository: MathMaterialProtocol) {
        self.networkManager = networkManager
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
        ClassroomView(viewModel: classroomViewModel)
    }
    
    @ViewBuilder
    func buildView(route: AppRoutes) -> some View {
        switch route {
        case .classroom:
            ClassroomView(viewModel: classroomViewModel)
            
        case .library:
            // TODO: Need to change like classroomViewModel above!
            let viewModel = LibraryViewModel(coordinator: self, mathMaterialRepository: mathMaterialRepository)
            LibraryView(viewModel: viewModel)
            
        case .materialDetail:
            MaterialDetailView()
        }
    }
}
