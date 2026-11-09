//
//  AppRoutes.swift
//  MetraStudent
//
//  Created by Fidel Fausta Cavell on 29/10/26.
//

import Foundation

enum AppRoutes: Hashable {
    case material(MathMaterialModel)
    case section(sections: [MathSectionModel], initialIndex: Int, speechStyle: SpeechStyle = .clearSpeak)
}
