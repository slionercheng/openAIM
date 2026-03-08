//
//  Agent.swift
//  openAIM
//
//  Created by Claude on 2026/3/7.
//

import Foundation

/// AI Agent 模型
struct Agent: Codable, Identifiable, Hashable {
    let id: String
    let name: String
    let description: String?
    let skills: [String]
    let accessToken: String?
    let status: AgentStatus
    let createdAt: Date
    let updatedAt: Date
    
    enum CodingKeys: String, CodingKey {
        case id
        case name
        case description
        case skills
        case accessToken = "access_token"
        case status
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }
}

/// Agent 状态
enum AgentStatus: String, Codable {
    case active = "active"
    case inactive = "inactive"
}

/// 创建 Agent 请求
struct CreateAgentRequest: Codable {
    let name: String
    let description: String?
    let skills: [String]
}

/// 更新 Agent 请求
struct UpdateAgentRequest: Codable {
    let name: String?
    let description: String?
    let skills: [String]?
    let status: AgentStatus?
}