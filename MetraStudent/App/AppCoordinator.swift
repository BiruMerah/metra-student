//
//  AppCoordinator.swift
//  MetraStudent
//
//  Created by Fidel Fausta Cavell on 29/10/26.
//

import Foundation
import Observation
import SwiftUI
import SwiftData

@Observable
@MainActor
final class AppCoordinator {
    // MARK: - Navigation State
    var channelPath = NavigationPath()
    
    // MARK: - Dependencies (Domain Protocols)
    let mathMaterialRepository: MathMaterialProtocol
    let notificationManager: NotificationProtocol
    private let storageIsPersistent: Bool
    
    // MARK: - ViewModels
    @ObservationIgnored
    lazy var channelViewModel: ChannelViewModel = {
        let vm = ChannelViewModel(
            mathMaterialRepository: mathMaterialRepository,
            notificationManager: notificationManager,
            coordinator: self
        )
        vm.onMaterialsAutosaved = { [weak self] in
            self?.documentViewModel.reload()
        }
        return vm
    }()
    
    @ObservationIgnored
    lazy var documentViewModel = DocumentViewModel(
        mathMaterialRepository: mathMaterialRepository,
        storageIsPersistent: storageIsPersistent,
        notificationManager: notificationManager,
        coordinator: self
    )
    
    // MARK: - Main Initialization
    init(
        mathMaterialRepository: MathMaterialProtocol,
        notificationManager: NotificationProtocol,
        storageIsPersistent: Bool = true
    ) {
        self.mathMaterialRepository = mathMaterialRepository
        self.notificationManager = notificationManager
        self.storageIsPersistent = storageIsPersistent
    }

    static func makePreview(savedMaterials: [MathMaterialModel] = []) -> AppCoordinator {
        AppCoordinator(
            mathMaterialRepository: InMemoryMathMaterialRepository(materials: savedMaterials),
            notificationManager: NotificationManager()
        )
    }
    
    // MARK: - Stack Navigation
    func navigate(to route: AppRoutes) {
        channelPath.append(route)
    }
    
    func navigateBack() {
        if !channelPath.isEmpty {
            channelPath.removeLast()
        }
    }
    
    func popToRoot() {
        channelPath.removeLast(channelPath.count)
    }
    
    // MARK: - View Builders
    @ViewBuilder
    func buildHome() -> some View {
        HomeView(
            channelViewModel: channelViewModel,
            documentViewModel: documentViewModel
        )
    }
    
    @ViewBuilder
    func buildDestination(for route: AppRoutes) -> some View {
        switch route {
        case .material(let material):
            MaterialView(
                viewModel: MaterialViewModel(
                    material: material,
                    mathMaterialRepository: mathMaterialRepository,
                    notificationManager: notificationManager,
                    coordinator: self
                )
            )

        case .section(let materialTitle, let sections, let initialIndex, let speechStyle):
            SectionView(
                viewModel: SectionViewModel(
                    materialTitle: materialTitle,
                    sections: sections,
                    initialSectionIndex: initialIndex,
                    initialSpeechStyle: speechStyle
                ),
                onFinish: popToRoot
            )
        }
    }
}
