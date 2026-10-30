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
    // MARK: - Navigation State
    var selectedTab: AppTab = .classroom
    var classroomPath = NavigationPath()
    var libraryPath = NavigationPath()
    
    // MARK: - Dependencies
    let networkManager: NetworkProtocol
    let mathMaterialRepository: MathMaterialProtocol
    
    // MARK: - ViewModels
    @ObservationIgnored
    lazy var classroomViewModel: ClassroomViewModel = ClassroomViewModel(
        networkManager: networkManager,
        mathMaterialRepository: mathMaterialRepository,
        coordinator: self
    )
    
    @ObservationIgnored
    lazy var libraryViewModel = LibraryViewModel(
        mathMaterialRepository: mathMaterialRepository
    )
    
    // MARK: - Initialization
    init(networkManager: NetworkProtocol, mathMaterialRepository: MathMaterialProtocol) {
        self.networkManager = networkManager
        self.mathMaterialRepository = mathMaterialRepository
    }
    
    // MARK: - Tab Management
    func selectTab(_ tab: AppTab) {
        if selectedTab == tab {
            popToRoot(in: tab)
            
        } else {
            selectedTab = tab
        }
    }
    
    // MARK: - Stack Navigation
    func navigate(to route: AppRoutes, in tab: AppTab? = nil) {
        let targetTab = tab ?? selectedTab
        switch targetTab {
        case .classroom:
            classroomPath.append(route)
            
        case .library:
            libraryPath.append(route)
        }
    }
    
    func navigateBack(in tab: AppTab? = nil) {
        let targetTab = tab ?? selectedTab
        switch targetTab {
        case .classroom:
            if !classroomPath.isEmpty {
                classroomPath.removeLast()
            }
            
        case .library:
            if !libraryPath.isEmpty {
                libraryPath.removeLast()
            }
        }
    }
    
    func popToRoot(in tab: AppTab) {
        switch tab {
        case .classroom:
            classroomPath.removeLast(classroomPath.count)
            
        case .library:
            libraryPath.removeLast(libraryPath.count)
        }
    }
    
    // MARK: - View Builders
    @ViewBuilder
    func buildClassroom() -> some View {
        ClassroomView(viewModel: classroomViewModel)
    }
    
    @ViewBuilder
    func buildLibrary() -> some View {
        LibraryView(viewModel: libraryViewModel)
    }
    
    @ViewBuilder
    func buildDestination(for route: AppRoutes) -> some View {
        switch route {
        case .materialDetail:
            MaterialDetailView()
        }
    }
}
