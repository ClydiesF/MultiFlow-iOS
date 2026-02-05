//
//  MultiFlowApp.swift
//  MultiFlow
//
//  Created by clydies freeman on 2/2/26.
//

import SwiftUI
import FirebaseCore

@main
struct MultiFlowApp: App {
    @StateObject private var authViewModel = AuthViewModel()
    @StateObject private var propertyStore = PropertyStore()
    @StateObject private var gradeProfileStore = GradeProfileStore()
    @AppStorage("colorSchemePreference") private var colorSchemePreference = 0

    init() {
        FirebaseApp.configure()
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(authViewModel)
                .environmentObject(propertyStore)
                .environmentObject(gradeProfileStore)
                .preferredColorScheme(preferredScheme)
        }
    }

    private var preferredScheme: ColorScheme? {
        switch colorSchemePreference {
        case 1: return .light
        case 2: return .dark
        default: return nil
        }
    }
}
