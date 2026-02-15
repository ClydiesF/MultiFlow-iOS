//
//  ContentView.swift
//  MultiFlow
//
//  Created by clydies freeman on 2/2/26.
//

import SwiftUI

struct ContentView: View {
    var body: some View {
        RootView()
    }
}

#Preview {
    ContentView()
        .environmentObject(AuthViewModel())
        .environmentObject(PropertyStore())
        .environmentObject(GradeProfileStore())
        .environmentObject(SubscriptionManager())
}
