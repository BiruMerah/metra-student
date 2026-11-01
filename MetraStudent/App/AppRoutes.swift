//
//  AppRoutes.swift
//  MetraStudent
//
//  Created by Fidel Fausta Cavell on 29/10/26.
//

import Foundation

enum AppRoutes: Hashable {
    case materialDetail(MathMaterialModel)
    case topicDetail(topics: [MathTopicModel], initialIndex: Int)
}

@MainActor
protocol AppCoordinating: AnyObject {
    func navigate(to route: AppRoutes, in tab: AppTab?)
    func navigateBack(in tab: AppTab?)
    func popToRoot(in tab: AppTab)
}

extension AppCoordinating {
    func navigate(to route: AppRoutes) {
        navigate(to: route, in: nil)
    }
}
