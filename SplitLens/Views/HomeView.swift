//
//  HomeView.swift
//  SplitLens
//
//  Landing screen with liquid glass design
//

import SwiftUI

// Note: Route enum defined in Navigation/Route.swift

/// Home screen with main navigation options
struct HomeView: View {
    // MARK: - Environment
    
    @Environment(\.dependencies) private var dependencies
    
    // MARK: - State
    
    @State private var navigationPath = NavigationPath()
    @State private var showHistory = false
    @StateObject private var historyViewModel: HistoryViewModel
    
    // MARK: - Initialization
    
    init() {
        _historyViewModel = StateObject(wrappedValue: HistoryViewModel())
    }
    
    // MARK: - Body
    
    var body: some View {
        NavigationStack(path: $navigationPath) {
            ZStack {
                // Animated gradient background
                AnimatedGradientBackground()
                
                ScrollView {
                    VStack(spacing: 32) {
                        Spacer()
                            .frame(height: 40)
                        
                        // App icon and title
                        VStack(spacing: 16) {
                            ZStack {
                                Circle()
                                    .fill(
                                        LinearGradient(
                                            colors: [
                                                Color.blue.opacity(0.8),
                                                Color.purple.opacity(0.6)
                                            ],
                                            startPoint: .topLeading,
                                            endPoint: .bottomTrailing
                                        )
                                    )
                                    .frame(width: 120, height: 120)
                                    .shadow(color: Color.blue.opacity(0.4), radius: 20, x: 0, y: 10)
                                
                                Image(systemName: "receipt.fill")
                                    .font(.system(size: 60, weight: .light))
                                    .foregroundStyle(.white)
                            }
                            .background(.ultraThinMaterial, in: Circle())
                            
                            VStack(spacing: 8) {
                                Text("SplitLens")
                                    .font(.system(size: 44, weight: .bold, design: .rounded))
                                    .foregroundStyle(.white)
                                
                                Text("Smart Bill Splitting")
                                    .font(.system(size: 18, weight: .medium))
                                    .foregroundStyle(.white.opacity(0.9))
                            }
                        }
                        
                        Spacer()
                            .frame(height: 40)
                        
                        // Main action buttons
                        VStack(spacing: 16) {
                            // New Scan button
                            HomeActionButton(
                                icon: "camera.fill",
                                title: "New Scan",
                                subtitle: "Scan a receipt to split",
                                gradient: [Color.blue, Color.blue.opacity(0.8)]
                            ) {
                                navigationPath.append(Route.imageUpload)
                            }
                            
                            // History button
                            HomeActionButton(
                                icon: "clock.fill",
                                title: "History",
                                subtitle: "View past splits",
                                gradient: [Color.purple, Color.purple.opacity(0.8)]
                            ) {
                                navigationPath.append(Route.history)
                            }
                        }
                        .padding(.horizontal, 24)
                        
                        // Recent sessions preview
                        if historyViewModel.hasSessions {
                            RecentSessionsPreview(
                                sessions: Array(historyViewModel.filteredSessions.prefix(3)),
                                onTap: { session in
                                    navigationPath.append(Route.sessionDetail(session))
                                }
                            )
                            .padding(.horizontal, 24)
                        }
                        
                        Spacer()
                    }
                }
            }
            .navigationDestination(for: Route.self) { route in
                routeDestination(for: route)
            }
        }
        .task {
            await historyViewModel.loadRecentSessions(count: 5)
        }
    }
    
    // MARK: - Navigation Destination
    
    @ViewBuilder
    private func routeDestination(for route: Route) -> some View {
        switch route {
        case .imageUpload:
            ImageUploadView(navigationPath: $navigationPath)
        case .itemsEditor(let items):
            ItemsEditorView(items: items, navigationPath: $navigationPath)
        case .participantsEntry(let items):
            ParticipantsEntryView(items: items, navigationPath: $navigationPath)
        case .itemAssignment(let items, let participants, let paidBy, let total):
            ItemAssignmentView(
                items: items,
                participants: participants,
                paidBy: paidBy,
                totalAmount: total,
                navigationPath: $navigationPath
            )
        case .finalReport(let session):
            FinalReportView(session: session, navigationPath: $navigationPath)
        case .history:
            HistoryView(navigationPath: $navigationPath)
        case .sessionDetail(let session):
            SessionDetailView(session: session)
        }
    }
}

// MARK: - Home Action Button

struct HomeActionButton: View {
    let icon: String
    let title: String
    let subtitle: String
    let gradient: [Color]
    let action: () -> Void
    
    var body: some View {
        Button(action: {
            let generator = UIImpactFeedbackGenerator(style: .medium)
            generator.impactOccurred()
            action()
        }) {
            HStack(spacing: 20) {
                // Icon
                ZStack {
                    Circle()
                        .fill(Color.white.opacity(0.2))
                        .frame(width: 56, height: 56)
                    
                    Image(systemName: icon)
                        .font(.system(size: 24, weight: .semibold))
                        .foregroundStyle(.white)
                }
                
                // Text
                VStack(alignment: .leading, spacing: 4) {
                    Text(title)
                        .font(.system(size: 20, weight: .bold))
                        .foregroundStyle(.white)
                    
                    Text(subtitle)
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(.white.opacity(0.8))
                }
                
                Spacer()
                
                Image(systemName: "chevron.right")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundStyle(.white.opacity(0.6))
            }
            .padding(20)
            .background(
                LinearGradient(
                    colors: gradient,
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            .clipShape(RoundedRectangle(cornerRadius: 20))
            .shadow(color: gradient[0].opacity(0.3), radius: 15, x: 0, y: 8)
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Recent Sessions Preview

struct RecentSessionsPreview: View {
    let sessions: [ReceiptSession]
    let onTap: (ReceiptSession) -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Recent")
                .font(.system(size: 18, weight: .bold))
                .foregroundStyle(.white)
                .padding(.leading, 4)
            
            VStack(spacing: 10) {
                ForEach(sessions) { session in
                    Button(action: {
                        onTap(session)
                    }) {
                        HStack(spacing: 12) {
                            Image(systemName: "receipt")
                                .font(.system(size: 16, weight: .medium))
                                .foregroundStyle(.white.opacity(0.8))
                            
                            VStack(alignment: .leading, spacing: 2) {
                                Text(session.shortFormattedDate)
                                    .font(.system(size: 14, weight: .semibold))
                                    .foregroundStyle(.white)
                                
                                Text("\(session.participantCount) people • \(session.itemCount) items")
                                    .font(.system(size: 12))
                                    .foregroundStyle(.white.opacity(0.7))
                            }
                            
                            Spacer()
                            
                            Text(session.formattedTotal)
                                .font(.system(size: 16, weight: .bold, design: .rounded))
                                .foregroundStyle(.white)
                        }
                        .padding(14)
                        .background(Color.white.opacity(0.15))
                        .background(.ultraThinMaterial)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }
}

// MARK: - Animated Gradient Background

struct AnimatedGradientBackground: View {
    @State private var animateGradient = false
    
    var body: some View {
        LinearGradient(
            colors: [
                Color.blue.opacity(animateGradient ? 0.7 : 0.6),
                Color.purple.opacity(animateGradient ? 0.6 : 0.7),
                Color.pink.opacity(animateGradient ? 0.5 : 0.4)
            ],
            startPoint: animateGradient ? .topLeading : .bottomLeading,
            endPoint: animateGradient ? .bottomTrailing : .topTrailing
        )
        .ignoresSafeArea()
        .onAppear {
            withAnimation(
                .easeInOut(duration: 3.0)
                    .repeatForever(autoreverses: true)
            ) {
                animateGradient = true
            }
        }
    }
}

// MARK: - Preview

#Preview {
    HomeView()
        .withDependencies()
}
