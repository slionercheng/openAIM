//
//  OrganizationService.swift
//  openAIM
//
//  Created by Claude on 2026/3/7.
//

import Foundation

/// 组织服务
actor OrganizationService {
    static let shared = OrganizationService()
    
    private let apiClient = APIClient.shared
    
    private init() {}
    
    /// 获取用户的组织列表
    func getOrganizations() async throws -> [Organization] {
        let organizations: [Organization] = try await apiClient.get(Constants.Users.myOrgs)
        return organizations
    }
    
    /// 获取组织详情
    func getOrganization(id: String) async throws -> Organization {
        let organization: Organization = try await apiClient.get(Constants.Organizations.detail(id))
        return organization
    }
    
    /// 创建组织
    func createOrganization(name: String, description: String?, type: OrganizationType) async throws -> Organization {
        let request = CreateOrganizationRequest(name: name, description: description, type: type)
        let organization: Organization = try await apiClient.post(Constants.Organizations.base, body: request)
        return organization
    }
    
    /// 更新组织
    func updateOrganization(id: String, name: String?, description: String?) async throws -> Organization {
        let request = ["name": name, "description": description]
        let organization: Organization = try await apiClient.put(Constants.Organizations.detail(id), body: request)
        return organization
    }
    
    /// 删除组织
    func deleteOrganization(id: String) async throws {
        try await apiClient.delete(Constants.Organizations.detail(id))
    }
    
    /// 获取组织成员
    func getMembers(organizationId: String) async throws -> [OrgMembership] {
        let members: [OrgMembership] = try await apiClient.get(Constants.Organizations.members(organizationId))
        return members
    }
    
    /// 邀请成员
    func inviteMember(organizationId: String, email: String, role: MemberRole) async throws {
        let request = InviteMemberRequest(email: email, role: role)
        try await apiClient.post(Constants.Organizations.invitations(organizationId), body: request)
    }
    
    /// 更新成员角色
    func updateMemberRole(organizationId: String, userId: String, role: MemberRole) async throws {
        let request = ["role": role.rawValue]
        let _: Empty = try await apiClient.put("\(Constants.Organizations.members(organizationId))/\(userId)", body: request)
    }
    
    /// 移除成员
    func removeMember(organizationId: String, userId: String) async throws {
        try await apiClient.delete("\(Constants.Organizations.members(organizationId))/\(userId)")
    }
    
    /// 获取组织内的 Agent 列表
    func getAgents(organizationId: String) async throws -> [Agent] {
        let agents: [Agent] = try await apiClient.get(Constants.Organizations.agents(organizationId))
        return agents
    }
    
    /// 审批加入申请
    func approveJoinRequest(requestId: String) async throws {
        let _: Empty = try await apiClient.post(Constants.JoinRequests.approve(requestId), body: Empty())
    }
    
    /// 拒绝加入申请
    func rejectJoinRequest(requestId: String) async throws {
        let _: Empty = try await apiClient.post(Constants.JoinRequests.reject(requestId), body: Empty())
    }
}