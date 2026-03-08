//
//  OrganizationViewModel.swift
//  openAIM
//
//  Created by Claude on 2026/3/7.
//

import Foundation
import SwiftUI

/// 组织视图模型
@MainActor
@Observable
class OrganizationViewModel {
    var organizations: [Organization] = []
    var members: [OrgMembership] = []
    var selectedOrganization: Organization?
    var isLoading = false
    var errorMessage: String?
    
    private let service = OrganizationService.shared
    
    /// 加载组织列表
    func loadOrganizations() async {
        isLoading = true
        errorMessage = nil
        
        do {
            organizations = try await service.getOrganizations()
        } catch {
            errorMessage = error.localizedDescription
        }
        
        isLoading = false
    }
    
    /// 选择组织
    func selectOrganization(_ organization: Organization) async {
        selectedOrganization = organization
        await loadMembers(organizationId: organization.id)
    }
    
    /// 加载成员
    func loadMembers(organizationId: String) async {
        isLoading = true
        
        do {
            members = try await service.getMembers(organizationId: organizationId)
        } catch {
            errorMessage = error.localizedDescription
        }
        
        isLoading = false
    }
    
    /// 创建组织
    func createOrganization(name: String, description: String?, type: OrganizationType) async {
        isLoading = true
        
        do {
            let organization = try await service.createOrganization(
                name: name,
                description: description,
                type: type
            )
            organizations.append(organization)
            selectedOrganization = organization
            members = []
        } catch {
            errorMessage = error.localizedDescription
        }
        
        isLoading = false
    }
    
    /// 邀请成员
    func inviteMember(email: String, role: MemberRole) async {
        guard let orgId = selectedOrganization?.id else { return }
        
        do {
            try await service.inviteMember(organizationId: orgId, email: email, role: role)
            await loadMembers(organizationId: orgId)
        } catch {
            errorMessage = error.localizedDescription
        }
    }
    
    /// 更新成员角色
    func updateMemberRole(userId: String, role: MemberRole) async {
        guard let orgId = selectedOrganization?.id else { return }
        
        do {
            try await service.updateMemberRole(organizationId: orgId, userId: userId, role: role)
            await loadMembers(organizationId: orgId)
        } catch {
            errorMessage = error.localizedDescription
        }
    }
    
    /// 移除成员
    func removeMember(userId: String) async {
        guard let orgId = selectedOrganization?.id else { return }
        
        do {
            try await service.removeMember(organizationId: orgId, userId: userId)
            members.removeAll { $0.userId == userId }
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}