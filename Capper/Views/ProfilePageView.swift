//
//  ProfilePageView.swift
//  Capper
//
//  Premium editorial-style Profile page for BlogGo.
//  Minimal, calm, typography-driven.
//
import SwiftUI
import PhotosUI

/// Centralized design system constants for the Profile
struct ProfileTheme {
    struct Spacing {
        static let xs: CGFloat = 4
        static let sm: CGFloat = 8
        static let md: CGFloat = 16
        static let lg: CGFloat = 24
        static let xl: CGFloat = 32
        static let xxl: CGFloat = 48
        static let massive: CGFloat = 64
    }
    
    struct Typography {
        /// For the user's display name
        static let profileName = Font.system(.title, design: .serif).weight(.medium)
        /// For the bio
        static let bio = Font.system(.body, design: .default).weight(.regular)
        /// For blog titles in the list
        static let storyTitle = Font.system(.title2, design: .serif).weight(.semibold)
        /// For location & date metadata (small, uppercase, wide)
        static let metadata = Font.system(.caption).weight(.medium)
        /// For the 2-line excerpt
        static let excerpt = Font.system(.subheadline, design: .default)
    }
}

struct ProfilePageView: View {
    @EnvironmentObject private var createdRecapStore: CreatedRecapBlogStore
    @EnvironmentObject private var authService: AuthService
    @Binding var selectedCreatedRecap: CreatedRecapBlog?
    
    @StateObject private var viewModel = MyBlogsProfileViewModel()
    @State private var selectedCountryID: String? = nil
    @State private var showMyMap = false
    
    private var uniqueCountries: [String] {
        let countries = createdRecapStore.recents.compactMap { $0.countryName }
        let unique = Array(Set(countries))
        return unique.sorted()
    }
    
    private var filteredBlogs: [CreatedRecapBlog] {
        guard let countryID = selectedCountryID else {
            return createdRecapStore.recents
        }
        return createdRecapStore.recents.filter { $0.countryName == countryID }
    }

    var body: some View {
        ZStack(alignment: .bottomTrailing) {
            ScrollView(showsIndicators: false) {
                VStack(spacing: ProfileTheme.Spacing.xxl) {
                
                // 1. Centered Hero Section
                ProfileHeroSection()
                    .environmentObject(authService)
                    .padding(.top, ProfileTheme.Spacing.xl)
                
                // 2. Stories Section
                VStack(alignment: .leading, spacing: ProfileTheme.Spacing.xl) {
                    
                    // Section Title
                    Text("Published Blogs")
                        .font(ProfileTheme.Typography.metadata)
                        .textCase(.uppercase)
                        .foregroundColor(.secondary)
                        .kerning(1.2) // Adds tracking for editorial feel
                        .padding(.horizontal, ProfileTheme.Spacing.md)
                    
                    // Content
                    if createdRecapStore.isLoading || viewModel.isScanning {
                        ProfileLoadingSkeleton()
                    } else if createdRecapStore.recents.isEmpty {
                        ProfileEmptyState()
                    } else {
                        VStack(alignment: .leading, spacing: ProfileTheme.Spacing.md) {
                            countryFilterBar
                            
                            StoryFeedSection(
                                blogs: filteredBlogs,
                                selectedBlog: $selectedCreatedRecap
                            )
                        }
                    }
                }
            }
            .padding(.bottom, ProfileTheme.Spacing.massive)
        }
        
        Button {
            showMyMap = true
        } label: {
            Image(systemName: "map.fill")
                .font(.title2)
                .foregroundColor(.white)
                .frame(width: 52, height: 52)
                .background(Color.blue)
                .clipShape(Capsule())
                .shadow(color: Color.black.opacity(0.3), radius: 4, x: 0, y: 2)
        }
        .buttonStyle(.plain)
        .padding(.trailing, 20)
        .padding(.bottom, 24)
        }
        .background(Color(uiColor: .systemBackground))
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    Task {
                        await prepareShareContent()
                        showShare = true
                    }
                } label: {
                    Image(systemName: "square.and.arrow.up")
                        .foregroundColor(.primary)
                }
            }
        }
        .sheet(isPresented: $showShare) {
            if !shareItems.isEmpty {
                ShareSheet(items: shareItems)
            }
        }
        .onAppear {
            viewModel.loadUnsavedTrips()
        }
        .navigationDestination(isPresented: $showMyMap) {
            MyMapView(selectedCreatedRecap: $selectedCreatedRecap)
        }
    }

    @State private var showShare = false
    @State private var shareItems: [Any] = []

    private func prepareShareContent() async {
        // Simple share content for the profile
        var items: [Any] = []
        if let name = authService.currentUser?.displayName ?? authService.currentUser?.email {
            items.append("Check out \(name)'s travel blogs on BlogGo!")
        }
        
        // Include the profile photo if available
        if let data = UserDefaults.standard.data(forKey: "customProfileImageData"), let uiImage = UIImage(data: data) {
            items.append(uiImage)
        }
        
        shareItems = items
    }
    
    private var countryFilterBar: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                Button(action: {
                    selectedCountryID = nil
                }) {
                    Text("All")
                        .font(.subheadline)
                        .fontWeight(selectedCountryID == nil ? .semibold : .regular)
                        .foregroundColor(selectedCountryID == nil ? Color(uiColor: .systemBackground) : .primary)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                        .background(selectedCountryID == nil ? Color.primary : Color(uiColor: .secondarySystemBackground))
                        .clipShape(Capsule())
                }
                .buttonStyle(.plain)
                
                ForEach(uniqueCountries, id: \.self) { country in
                    Button(action: {
                        selectedCountryID = country
                    }) {
                        Text(country)
                            .font(.subheadline)
                            .fontWeight(selectedCountryID == country ? .semibold : .regular)
                            .foregroundColor(selectedCountryID == country ? Color(uiColor: .systemBackground) : .primary)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 8)
                            .background(selectedCountryID == country ? Color.primary : Color(uiColor: .secondarySystemBackground))
                            .clipShape(Capsule())
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, ProfileTheme.Spacing.md)
        }
    }
}

// MARK: - Hero Section
struct ProfileHeroSection: View {
    @EnvironmentObject private var authService: AuthService
    @State private var showPhotoViewer = false
    @State private var showManagement = false
    @State private var showEditBio = false
    
    // For local persistence of the selected avatar
    @AppStorage("customProfileImageData") private var customProfileImageData: Data?
    
    // For local persistence of the user's bio
    @AppStorage("userBio") private var userBio: String = "Write your bio"
    
    var body: some View {
        VStack(spacing: ProfileTheme.Spacing.md) {
            // Profile Photo
            Button {
                showPhotoViewer = true
            } label: {
                if let data = customProfileImageData, let uiImage = UIImage(data: data) {
                    Image(uiImage: uiImage)
                        .resizable()
                        .scaledToFill()
                        .frame(width: 88, height: 88)
                        .clipShape(Circle())
                } else {
                    ZStack {
                        Circle()
                            .fill(LinearGradient(
                                colors: [Color(red: 0.2, green: 0.5, blue: 1), Color(red: 0.1, green: 0.3, blue: 0.8)],
                                startPoint: .topLeading, endPoint: .bottomTrailing
                            ))
                            .frame(width: 88, height: 88)
                        
                        Text(authService.currentUser?.initials ?? "?")
                            .font(.system(size: 34, weight: .bold))
                            .foregroundColor(.white)
                    }
                }
            }
            .buttonStyle(.plain)
            
            // Name & Bio
            VStack(spacing: ProfileTheme.Spacing.sm) {
                Text(authService.currentUser?.displayName ?? authService.currentUser?.email ?? "Traveler")
                    .font(ProfileTheme.Typography.profileName)
                    .foregroundColor(.primary)
                
                Text(userBio)
                    .font(ProfileTheme.Typography.bio)
                    .foregroundColor(.primary.opacity(0.8))
                    .multilineTextAlignment(.center)
                    .lineSpacing(4)
                    .padding(.horizontal, ProfileTheme.Spacing.xl)
            }
            
            // Subtle Stats Line
            Text("12 Countries • 34 Blogs")
                .font(ProfileTheme.Typography.metadata)
                .foregroundColor(.secondary)
                .padding(.top, ProfileTheme.Spacing.xs)
            
            // Action Buttons
            HStack(spacing: ProfileTheme.Spacing.md) {
                // Edit Bio Button
                Button {
                    showEditBio = true
                } label: {
                    Text("Edit Bio")
                        .font(.system(.subheadline, design: .default).weight(.medium))
                        .foregroundColor(.primary)
                        .padding(.horizontal, ProfileTheme.Spacing.lg)
                        .padding(.vertical, ProfileTheme.Spacing.sm)
                        .background(
                            RoundedRectangle(cornerRadius: 16)
                                .strokeBorder(Color.primary.opacity(0.15), lineWidth: 1)
                        )
                }
                
                // Manage Button
                Button {
                    showManagement = true
                } label: {
                    Text("Manage")
                        .font(.system(.subheadline, design: .default).weight(.medium))
                        .foregroundColor(.primary)
                        .padding(.horizontal, ProfileTheme.Spacing.lg)
                        .padding(.vertical, ProfileTheme.Spacing.sm)
                        .background(
                            RoundedRectangle(cornerRadius: 16)
                                .strokeBorder(Color.primary.opacity(0.15), lineWidth: 1)
                        )
                }
            }
            .padding(.top, ProfileTheme.Spacing.sm)
        }
        .sheet(isPresented: $showPhotoViewer) {
            ProfilePhotoViewer(customProfileImageData: $customProfileImageData)
                .environmentObject(authService)
                .presentationDragIndicator(.visible)
        }
        .sheet(isPresented: $showManagement) {
            ProfileManagementView()
                .presentationDragIndicator(.visible)
        }
        .sheet(isPresented: $showEditBio) {
            EditBioView(bio: $userBio)
                .presentationDragIndicator(.visible)
        }
    }
}

// MARK: - Edit Bio View
struct EditBioView: View {
    @Environment(\.dismiss) private var dismiss
    @Binding var bio: String
    
    @State private var draftBio: String = ""
    
    var body: some View {
        NavigationStack {
            Form {
                Section(header: Text("About You"), footer: Text("Write a short bio to display on your profile. Keep it brief!")) {
                    TextEditor(text: $draftBio)
                        .frame(minHeight: 100)
                }
            }
            .navigationTitle("Edit Bio")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        bio = draftBio
                        dismiss()
                    }
                    .fontWeight(.bold)
                }
            }
            .onAppear {
                draftBio = bio
            }
        }
    }
}

// MARK: - Profile Photo Viewer
struct ProfilePhotoViewer: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var authService: AuthService
    @Binding var customProfileImageData: Data?
    
    @State private var selectedItem: PhotosPickerItem?
    
    var body: some View {
        NavigationStack {
            VStack(spacing: ProfileTheme.Spacing.xl) {
                Spacer()
                
                if let data = customProfileImageData, let uiImage = UIImage(data: data) {
                    Image(uiImage: uiImage)
                        .resizable()
                        .scaledToFill()
                        .frame(width: 250, height: 250)
                        .clipShape(Circle())
                        .shadow(color: .black.opacity(0.2), radius: 20, x: 0, y: 10)
                } else {
                    ZStack {
                        Circle()
                            .fill(LinearGradient(
                                colors: [Color(red: 0.2, green: 0.5, blue: 1), Color(red: 0.1, green: 0.3, blue: 0.8)],
                                startPoint: .topLeading, endPoint: .bottomTrailing
                            ))
                            .frame(width: 250, height: 250)
                            .shadow(color: .black.opacity(0.2), radius: 20, x: 0, y: 10)
                        
                        Text(authService.currentUser?.initials ?? "?")
                            .font(.system(size: 100, weight: .bold))
                            .foregroundColor(.white)
                    }
                }
                
                PhotosPicker(selection: $selectedItem, matching: .images, photoLibrary: .shared()) {
                    Text("Change Photo")
                        .font(.headline)
                        .foregroundColor(.white)
                        .padding(.horizontal, 32)
                        .padding(.vertical, 14)
                        .background(Color.blue)
                        .clipShape(Capsule())
                }
                .onChange(of: selectedItem) { _, newItem in
                    Task {
                        if let data = try? await newItem?.loadTransferable(type: Data.self) {
                            DispatchQueue.main.async {
                                self.customProfileImageData = data
                            }
                        }
                    }
                }
                
                if customProfileImageData != nil {
                    Button("Remove Photo", role: .destructive) {
                        customProfileImageData = nil
                    }
                    .padding(.top, 8)
                }
                
                Spacer()
            }
            .frame(maxWidth: .infinity)
            .background(Color(uiColor: .systemBackground).ignoresSafeArea())
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { dismiss() }
                }
            }
        }
    }
}

// MARK: - Reusable BlogCard Component
struct BlogCard: View {
    let blog: CreatedRecapBlog
    
    var body: some View {
        VStack(alignment: .leading, spacing: ProfileTheme.Spacing.md) {
            
            // 16:9 Cover Image
            GeometryReader { proxy in
                if let uiImage = UIImage(named: blog.coverImageName) ?? UIImage(contentsOfFile: blog.coverImageName) {
                    Image(uiImage: uiImage)
                        .resizable()
                        .scaledToFill()
                        .frame(width: proxy.size.width, height: proxy.size.width * (9/16))
                        .clipped()
                } else {
                    Rectangle()
                        .fill(Color(uiColor: .secondarySystemBackground))
                        .frame(width: proxy.size.width, height: proxy.size.width * (9/16))
                }
            }
            .aspectRatio(16/9, contentMode: .fit)
            
            // Story Meta & Content
            VStack(alignment: .leading, spacing: ProfileTheme.Spacing.sm) {
                
                // Metadata (Location + Date)
                let location = blog.countryName ?? "Unknown"
                let date = blog.tripDateRangeText ?? ""
                
                Text("\(location) — \(date)".uppercased())
                    .font(ProfileTheme.Typography.metadata)
                    .foregroundColor(.secondary)
                    .kerning(0.5)
                
                // Bold Title
                Text(blog.title)
                    .font(ProfileTheme.Typography.storyTitle)
                    .foregroundColor(.primary)
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)
                
                // Excerpt
                let excerptText = "A \(blog.tripDurationDays)-day journey exploring \(blog.totalPlaceVisitCount) memorable places."
                Text(excerptText)
                    .font(ProfileTheme.Typography.excerpt)
                    .foregroundColor(.primary.opacity(0.7))
                    .lineLimit(2)
                    .lineSpacing(4)
            }
            .padding(.horizontal, ProfileTheme.Spacing.md)
        }
    }
}

// MARK: - Feed Section
struct StoryFeedSection: View {
    let blogs: [CreatedRecapBlog]
    @Binding var selectedBlog: CreatedRecapBlog?
    
    var body: some View {
        VStack(spacing: ProfileTheme.Spacing.xxl) {
            ForEach(blogs) { blog in
                Button {
                    selectedBlog = blog
                } label: {
                    BlogCard(blog: blog)
                }
                .buttonStyle(.plain)
            }
        }
    }
}

// MARK: - Empty State View
struct ProfileEmptyState: View {
    var body: some View {
        VStack(spacing: ProfileTheme.Spacing.md) {
            Text("No blogs yet.")
                .font(ProfileTheme.Typography.storyTitle)
                .foregroundColor(.primary)
            
            Text("When you publish a blog, it will appear here for your readers.")
                .font(ProfileTheme.Typography.bio)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 280)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, ProfileTheme.Spacing.massive)
    }
}

// MARK: - Loading Skeleton
struct ProfileLoadingSkeleton: View {
    @State private var isPulsing = false
    
    var body: some View {
        VStack(spacing: ProfileTheme.Spacing.xxl) {
            ForEach(0..<2, id: \.self) { _ in
                VStack(alignment: .leading, spacing: ProfileTheme.Spacing.md) {
                    // Image Skeleton
                    Rectangle()
                        .fill(Color(uiColor: .secondarySystemBackground))
                        .aspectRatio(16/9, contentMode: .fit)
                    
                    VStack(alignment: .leading, spacing: ProfileTheme.Spacing.sm) {
                        // Location Date Skeleton
                        Text("Location — Date")
                            .font(ProfileTheme.Typography.metadata)
                        
                        // Title Skeleton
                        Text("This is a placeholder for a two line title")
                            .font(ProfileTheme.Typography.storyTitle)
                        
                        // Excerpt Skeleton
                        Text("This is a placeholder excerpt spanning across two lines to show loading state.")
                            .font(ProfileTheme.Typography.excerpt)
                    }
                    .padding(.horizontal, ProfileTheme.Spacing.md)
                }
            }
        }
        .redacted(reason: .placeholder)
        .opacity(isPulsing ? 0.4 : 1.0)
        .animation(.easeInOut(duration: 1.0).repeatForever(autoreverses: true), value: isPulsing)
        .onAppear {
            isPulsing = true
        }
    }
}
