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
final class AppCoordinator: AppCoordinating {
    // MARK: - Navigation State
    var selectedTab: AppTab = .channel
    var channelPath = NavigationPath()
    var documentPath = NavigationPath()
    
    // MARK: - Dependencies (Domain Protocols)
    let mathMaterialRepository: MathMaterialProtocol
    let notificationManager: NotificationProtocol
    private let storageIsPersistent: Bool
    let assistantEngineFactory: ((any AssistantTranslatingProtocol) -> any AssistantProvidingProtocol)?
    
    // MARK: - ViewModels
    @ObservationIgnored
    lazy var channelViewModel: ChannelViewModel = ChannelViewModel(
        mathMaterialRepository: mathMaterialRepository,
        notificationManager: notificationManager,
        coordinator: self
    )
    
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
        storageIsPersistent: Bool = true,
        assistantEngineFactory: ((any AssistantTranslatingProtocol) -> any AssistantProvidingProtocol)? = nil
    ) {
        self.mathMaterialRepository = mathMaterialRepository
        self.notificationManager = notificationManager
        self.storageIsPersistent = storageIsPersistent
        self.assistantEngineFactory = assistantEngineFactory
    }

    static func makePreview(savedMaterials: [MathMaterialModel] = []) -> AppCoordinator {
        AppCoordinator(
            mathMaterialRepository: InMemoryMathMaterialRepository(materials: savedMaterials),
            notificationManager: NotificationManager()
        )
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
        case .channel:
            channelPath.append(route)
            
        case .document:
            documentPath.append(route)
        }
    }
    
    func navigateBack(in tab: AppTab? = nil) {
        let targetTab = tab ?? selectedTab
        switch targetTab {
        case .channel:
            if !channelPath.isEmpty {
                channelPath.removeLast()
            }
            
        case .document:
            if !documentPath.isEmpty {
                documentPath.removeLast()
            }
        }
    }
    
    func popToRoot(in tab: AppTab) {
        switch tab {
        case .channel:
            channelPath.removeLast(channelPath.count)
            
        case .document:
            documentPath.removeLast(documentPath.count)
        }
    }
    
    // MARK: - View Builders
    @ViewBuilder
    func buildChannel() -> some View {
        ChannelView(viewModel: channelViewModel)
    }
    
    @ViewBuilder
    func buildDocument() -> some View {
        DocumentView(viewModel: documentViewModel)
    }
    
    @ViewBuilder
    func buildDestination(for route: AppRoutes, in tab: AppTab = .channel) -> some View {
        switch route {
        case .materialDetail(let material):
            MaterialDetailView(
                viewModel: MaterialDetailViewModel(
                    material: material,
                    mathMaterialRepository: mathMaterialRepository,
                    notificationManager: notificationManager,
                    coordinator: self
                ),
                sourceTab: tab
            )

        case .topicDetail(let topics, let initialIndex, let speechStyle):
            TopicView(
                viewModel: TopicViewModel(
                    topics: topics,
                    initialTopicIndex: initialIndex,
                    initialSpeechStyle: speechStyle,
                    assistantEngineFactory: assistantEngineFactory
                )
            )
        }
    }
}
