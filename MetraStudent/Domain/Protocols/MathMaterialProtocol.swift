//
//  MathMaterialProtocol.swift
//  MetraStudent
//
//  Created by Fidel Fausta Cavell on 29/10/26.
//

import Foundation

@MainActor
protocol MathMaterialProtocol {
    // TODO: Define list of functions
    func fetchSavedMaterials() throws -> [MathMaterialModel]
    
    func addSavedMaterial(material: MathMaterialModel) throws
    
    func deleteSavedMaterial(id: UUID) throws
}
