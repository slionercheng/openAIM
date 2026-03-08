//
//  AgentViewModel.swift
//  openAIM
//
//  Created by Claude on 2026/3/7.
//

import Foundation
import SwiftUI

/// Agent 视图模型
@MainActor
@Observable
class AgentViewModel {
    var agents: [Agent] = []
    var selectedAgent: Agent?
    var isLoading = false
    var errorMessage: String?
    
    private let service = AgentService.shared
    
    /// 加载 Agent 列表
    func loadAgents() async {
        isLoading = true
        errorMessage = nil
        
        do {
            agents = try await service.getAgents()
        } catch {
            errorMessage = error.localizedDescription
        }
        
        isLoading = false
    }
    
    /// 选择 Agent
    func selectAgent(_ agent: Agent) {
        selectedAgent = agent
    }
    
    /// 创建 Agent
    func createAgent(name: String, description: String?, skills: [String]) async {
        isLoading = true
        
        do {
            let agent = try await service.createAgent(name: name, description: description, skills: skills)
            agents.append(agent)
            selectedAgent = agent
        } catch {
            errorMessage = error.localizedDescription
        }
        
        isLoading = false
    }
    
    /// 更新 Agent
    func updateAgent(id: String, name: String?, description: String?, skills: [String]?, status: AgentStatus?) async {
        do {
            let updatedAgent = try await service.updateAgent(
                id: id,
                name: name,
                description: description,
                skills: skills,
                status: status
            )
            
            if let index = agents.firstIndex(where: { $0.id == id }) {
                agents[index] = updatedAgent
            }
            
            if selectedAgent?.id == id {
                selectedAgent = updatedAgent
            }
        } catch {
            errorMessage = error.localizedDescription
        }
    }
    
    /// 删除 Agent
    func deleteAgent(_ agent: Agent) async {
        do {
            try await service.deleteAgent(id: agent.id)
            agents.removeAll { $0.id == agent.id }
            if selectedAgent?.id == agent.id {
                selectedAgent = nil
            }
        } catch {
            errorMessage = error.localizedDescription
        }
    }
    
    /// 重新生成 Token
    func regenerateToken(agentId: String) async {
        do {
            let updatedAgent = try await service.regenerateToken(id: agentId)
            
            if let index = agents.firstIndex(where: { $0.id == agentId }) {
                agents[index] = updatedAgent
            }
            
            if selectedAgent?.id == agentId {
                selectedAgent = updatedAgent
            }
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}