//
//  ContentView.swift
//  StopTyping (iOS)
//
//  Main tab view with dictation and settings.
//

import SwiftUI

struct ContentView: View {
    var body: some View {
        TabView {
            DictationView()
                .tabItem {
                    Label("Dictate", systemImage: "mic.fill")
                }

            iOSSettingsView()
                .tabItem {
                    Label("Settings", systemImage: "gear")
                }
        }
        .tint(Color(red: 0.41, green: 0.855, blue: 1.0)) // #69DAFF
    }
}
