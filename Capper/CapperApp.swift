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
    @StateObject private var authStateManager = AuthStateManager.shared
    @StateObject private var createdRecapStore = CreatedRecapBlogStore.shared
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
            .environmentObject(authStateManager)
            .environmentObject(createdRecapStore)
            .onAppear {
                photoAuth.refreshStatus()
            }
            // Autosave on scene phase changes
            .onChange(of: scenePhase) { _, newPhase in
                if newPhase == .inactive || newPhase == .background {
                    Task {
                        await BlogRepository.shared.saveIndex(
                            CreatedRecapBlogStore.shared.recents
                        )
                    }
                }
            }
            // Sync + import prompt on login
            .onChange(of: authStateManager.authState) { _, newState in
                if case .loggedIn = newState {
                    authStateManager.checkAndPromptImportIfNeeded()
                }
            }
            // Import drafts modal (presented at app root so it overlays any screen)
            .sheet(isPresented: $authStateManager.showImportDraftsModal) {
                ImportDraftsModalView()
                    .environmentObject(authStateManager)
                    .environmentObject(createdRecapStore)
            }
        }
    }

    private func openSettings() {
        guard let url = URL(string: UIApplication.openSettingsURLString) else { return }
        UIApplication.shared.open(url)
    }
}
