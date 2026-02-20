//
//  CapperApp.swift
//  Capper
//
//  Created by Justin Seo on 2/7/26.
//

import SwiftUI
import UIKit

@main
struct CapperApp: App {
    @StateObject private var photoAuth = PhotosAuthorizationManager()
    @StateObject private var authService = AuthService.shared
    @AppStorage("blogify.hasCompletedOnboarding") private var hasCompletedOnboarding = false
    @Environment(\.scenePhase) private var scenePhase

    var body: some Scene {
        WindowGroup {
            Group {
                if !hasCompletedOnboarding {
                    OnboardingFlowView {
                        hasCompletedOnboarding = true
                        photoAuth.refreshStatus()
                    }
                } else if photoAuth.isAuthorized {
                    ContentView()
                } else {
                    PhotosPermissionView(
                        status: photoAuth.status,
                        onRequest: { await photoAuth.requestAccess() },
                        onOpenSettings: { openSettings() }
                    )
                }
            }
            .environmentObject(authService)
            .onAppear {
                // Ensure auth status is fresh
                photoAuth.refreshStatus()
            }
            .onChange(of: scenePhase) { _, newPhase in
                if newPhase == .inactive || newPhase == .background {
                    Task {
                        await BlogRepository.shared.saveIndex(
                            CreatedRecapBlogStore.shared.recents
                        )
                    }
                }
            }
        }
    }

    private func openSettings() {
        guard let url = URL(string: UIApplication.openSettingsURLString) else { return }
        UIApplication.shared.open(url)
    }
}
