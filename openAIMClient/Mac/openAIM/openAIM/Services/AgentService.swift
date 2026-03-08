//
//  AgentService.swift
//  openAIM
//
//  Created by Claude on 2026/3/7.
//

import Foundation

/// Agent 服务
actor AgentService {
    static let shared = AgentService()
    
    private let apiClient = APIClient.shared
    
    private init() {}
    
    /// 获取 Agent 列表
    func getAgents() async throws -> [Agent] {
        let agents: [Agent] = try await apiClient.get(Constants.Users.myAgents)
        return agents
    }
    
    /// 获取 Agent 详情
    func getAgent(id: String) async throws -> Agent {
        let agent: Agent = try await apiClient.get(Constants.Agents.detail(id))
        return agent
    }
    
    /// 创建 Agent
    func createAgent(name: String, description: String?, skills: [String]) async throws -> Agent {
        let request = CreateAgentRequest(name: name, description: description, skills: skills)
        let agent: Agent = try await apiClient.post(Constants.Agents.base, body: request)
        return agent
    }
    
    /// 更新 Agent
    func updateAgent(id: String, name: String?, description: String?, skills: [String]?, status: AgentStatus?) async throws -> Agent {
        let request = UpdateAgentRequest(name: name, description: description, skills: skills, status: status)
        let agent: Agent = try await apiClient.put(Constants.Agents.detail(id), body: request)
        return agent
    }
    
    /// 删除 Agent
    func deleteAgent(id: String) async throws {
        try await apiClient.delete(Constants.Agents.detail(id))
    }
    
    /// 重新生成访问令牌
    func regenerateToken(id: String) async throws -> Agent {
        let agent: Agent = try await apiClient.post(Constants.Agents.regenerateToken(id), body: Empty())
        return agent
    }
    
    /// 申请加入组织
    func requestJoinOrganization(agentId: String, organizationId: String) async throws -> JoinRequest {
        let request = ["organization_id": organizationId]
        let joinRequest: JoinRequest = try await apiClient.post(Constants.Agents.joinRequests(agentId), body: request)
        return joinRequest
    }
    
    /// 获取加入申请列表
    func getJoinRequests(agentId: String) async throws -> [JoinRequest] {
        let requests: [JoinRequest] = try await apiClient.get(Constants.Agents.joinRequests(agentId))
        return requests
    }
}

/// 加入申请
struct JoinRequest: Codable, Identifiable {
    let id: String
    let agentId: String
    let organizationId: String
    let status: JoinRequestStatus
    let createdAt: Date
    
    enum CodingKeys: String, CodingKey {
        case id
        case agentId = "agent_id"
        case organizationId = "organization_id"
        case status
        case createdAt = "created_at"
    }
}

/// 加入申请状态
enum JoinRequestStatus: String, Codable {
    case pending = "pending"
    case approved = "approved"
    case rejected = "rejected"
}