//
//  AppViewModel.swift
//  openAIM
//
//  Created by Claude on 2026/3/7.
//

import SwiftUI

/// 应用视图模型
@MainActor
@Observable
class AppViewModel {
    var authViewModel = AuthViewModel()
    var conversationViewModel = ConversationViewModel()
    var agentViewModel = AgentViewModel()
    var organizationViewModel = OrganizationViewModel()
    var friendshipViewModel = FriendshipViewModel()
    
    var currentView: AppView = .login
    
    init() {
        Task {
            await checkAuthState()
        }
    }
    
    func checkAuthState() async {
        await authViewModel.checkAuthState()
        
        if authViewModel.isAuthenticated {
            currentView = .main
            // 加载初始数据
            await loadInitialData()
        } else {
            currentView = .login
        }
    }
    
    func loadInitialData() async {
        async let conversations = conversationViewModel.loadConversations()
        async let agents = agentViewModel.loadAgents()
        async let organizations = organizationViewModel.loadOrganizations()
        async let friends = friendshipViewModel.refreshAll()

        _ = await conversations
        _ = await agents
        _ = await organizations
        _ = await friends
    }
    
    func logout() async {
        await authViewModel.logout()
        currentView = .login
    }
}

/// 应用视图类型
enum AppView {
    case login
    case register
    case main
    case contacts
    case agents
    case organizations
    case settings
}