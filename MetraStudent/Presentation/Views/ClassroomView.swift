//
//  ClassroomView.swift
//  MetraStudent
//
//  Created by Fidel Fausta Cavell on 29/10/26.
//

import SwiftUI
import SwiftData

struct ClassroomView: View {
    let coordinator: AppCoordinator
    
    var body: some View {
        Text("Hello, This is ClassroomView!")
        
        Button("Go to Library") {
            coordinator.navigate(
                to: .library
            )
        }
        .buttonStyle(.glassProminent)
    }
}

#Preview {
    ClassroomView(
        coordinator: AppCoordinator(
            mathMaterialRepository: MathMaterialRepository(
                modelContext: ModelContext(try! ModelContainer(for: DatabaseSchema.schema))
            )
        )
    )
}
