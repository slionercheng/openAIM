//
//  OrganizationView.swift
//  openAIM
//
//  Created by Claude on 2026/3/7.
//

import SwiftUI

struct OrganizationView: View {
    @Environment(AppViewModel.self) private var appViewModel
    
    @State private var searchText = ""
    @State private var showCreateOrg = false
    @State private var showSearchOrgs = false
    @State private var showJoinRequests = false
    
    var body: some View {
        HStack(spacing: 0) {
            // 侧边栏
            orgSidebar
            
            // 详情区域
            if let org = appViewModel.organizationViewModel.selectedOrganization {
                OrgDetailView(organization: org, showInviteSheet: false)
            } else {
                emptyView
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .sheet(isPresented: $showCreateOrg) {
            CreateOrganizationView()
        }
        .sheet(isPresented: $showSearchOrgs) {
            SearchOrganizationsView()
        }
        .sheet(isPresented: $showJoinRequests) {
            JoinRequestsView()
        }
    }
    
    // MARK: - Organization Sidebar
    
    private var orgSidebar: some View {
        VStack(spacing: 0) {
            // 头部
            HStack {
                Text("Organizations")
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundStyle(Color(red: 0.118, green: 0.161, blue: 0.231))
                
                Spacer()
                
                Button {
                    showCreateOrg = true
                } label: {
                    ZStack {
                        RoundedRectangle(cornerRadius: 8)
                            .fill(Color.blue)
                            .frame(width: 32, height: 32)
                        Image(systemName: "plus")
                            .font(.system(size: 14))
                            .foregroundStyle(.white)
                    }
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 16)
            .overlay(
                Rectangle()
                    .fill(Color.gray.opacity(0.2))
                    .frame(height: 1),
                alignment: .bottom
            )
            
            // 搜索框
            HStack(spacing: 8) {
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 14))
                    .foregroundStyle(.secondary)
                
                TextField("Search organizations...", text: $searchText)
                    .textFieldStyle(.plain)
            }
            .padding(10)
            .background(Color.gray.opacity(0.1))
            .cornerRadius(8)
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            
            // 加入请求按钮
            Button {
                showJoinRequests = true
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "person.badge.plus")
                        .font(.system(size: 14))
                    
                    Text("Join Requests")
                        .font(.system(size: 13, weight: .medium))
                    
                    Spacer()
                    
                    Text("3")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 2)
                        .background(Color.blue)
                        .cornerRadius(100)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 10)
                .background(Color.blue.opacity(0.05))
                .cornerRadius(8)
            }
            .buttonStyle(.plain)
            .padding(.horizontal, 16)
            .padding(.bottom, 12)
            
            // 组织列表
            ScrollView {
                LazyVStack(spacing: 4) {
                    ForEach(filteredOrganizations) { org in
                        OrgRowView(organization: org, isSelected: appViewModel.organizationViewModel.selectedOrganization?.id == org.id)
                            .cornerRadius(10)
                            .onTapGesture {
                                Task {
                                    await appViewModel.organizationViewModel.selectOrganization(org)
                                }
                            }
                    }
                }
                .padding(.horizontal, 8)
            }
        }
        .frame(width: 320)
        .background(Color.white)
        .overlay(
            Rectangle()
                .fill(Color.gray.opacity(0.2))
                .frame(width: 1),
            alignment: .trailing
        )
    }
    
    // MARK: - Empty View
    
    private var emptyView: some View {
        VStack(spacing: 16) {
            Image(systemName: "building.2")
                .font(.system(size: 64))
                .foregroundStyle(.secondary)
            
            Text("Select an organization to view details")
                .font(.system(size: 16))
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.gray.opacity(0.05))
    }
    
    private var filteredOrganizations: [Organization] {
        if searchText.isEmpty {
            return appViewModel.organizationViewModel.organizations
        }
        return appViewModel.organizationViewModel.organizations.filter {
            $0.name.localizedCaseInsensitiveContains(searchText)
        }
    }
}

// MARK: - Org Row View

struct OrgRowView: View {
    let organization: Organization
    var isSelected: Bool = false
    
    var body: some View {
        HStack(spacing: 12) {
            // 头像
            RoundedRectangle(cornerRadius: 10)
                .fill(avatarColor)
                .frame(width: 44, height: 44)
                .overlay {
                    Text(organization.name.prefix(2))
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(.white)
                }
            
            // 信息
            VStack(alignment: .leading, spacing: 2) {
                Text(organization.name)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(Color(red: 0.118, green: 0.161, blue: 0.231))
                    .lineLimit(1)
                
                Text("\(organization.type.rawValue.capitalized) • \(organization.memberCount ?? 0) members")
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
            }
            
            Spacer()
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(isSelected ? Color.blue.opacity(0.05) : Color.white)
    }
    
    private var avatarColor: Color {
        let colors: [Color] = [
            Color(red: 0.231, green: 0.510, blue: 0.965),  // Blue
            Color(red: 0.545, green: 0.361, blue: 0.965),  // Purple
            Color(red: 0.961, green: 0.620, blue: 0.043),  // Orange
            Color(red: 0.063, green: 0.725, blue: 0.506),  // Green
            Color(red: 0.941, green: 0.267, blue: 0.459)   // Pink
        ]
        let index = abs(organization.name.hashValue) % colors.count
        return colors[index]
    }
}

// MARK: - Org Detail View

struct OrgDetailView: View {
    @Environment(AppViewModel.self) private var appViewModel
    
    let organization: Organization
    @State var showInviteSheet: Bool = false
    
    @State private var memberSearchText = ""
    
    var body: some View {
        ScrollView {
            VStack(spacing: 32) {
                // 头部信息
                profileHeader
                
                Divider()
                    .padding(.horizontal, 40)
                
                // 统计行
                statsRow
                
                Divider()
                    .padding(.horizontal, 40)
                
                // 成员列表
                membersSection
            }
            .padding(.vertical, 40)
            .padding(.horizontal, 60)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.white)
        .sheet(isPresented: $showInviteSheet) {
            InviteMembersView(organization: organization)
        }
    }
    
    // MARK: - Profile Header
    
    private var profileHeader: some View {
        VStack(spacing: 24) {
            // 头像
            RoundedRectangle(cornerRadius: 28)
                .fill(avatarColor)
                .frame(width: 120, height: 120)
                .overlay {
                    Text(organization.name.prefix(2))
                        .font(.system(size: 48, weight: .bold))
                        .foregroundStyle(.white)
                }
            
            // 名称和描述
            VStack(spacing: 8) {
                Text(organization.name)
                    .font(.system(size: 28, weight: .bold))
                    .foregroundStyle(Color(red: 0.118, green: 0.161, blue: 0.231))
                
                if let description = organization.description {
                    Text(description)
                        .font(.system(size: 16))
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                }
            }
            
            // 操作按钮
            HStack(spacing: 12) {
                Button {
                    showInviteSheet = true
                } label: {
                    HStack(spacing: 8) {
                        Image(systemName: "person.badge.plus")
                            .font(.system(size: 14))
                        Text("Invite")
                            .font(.system(size: 14, weight: .semibold))
                    }
                    .frame(width: 140, height: 44)
                    .foregroundStyle(.white)
                    .background(Color.blue)
                    .cornerRadius(22)
                }
                .buttonStyle(.plain)
                
                Button {
                    // TODO: 设置
                } label: {
                    ZStack {
                        Circle()
                            .fill(Color.gray.opacity(0.1))
                            .frame(width: 44, height: 44)
                        Image(systemName: "gearshape")
                            .font(.system(size: 16))
                            .foregroundStyle(.secondary)
                    }
                }
                .buttonStyle(.plain)
            }
        }
    }
    
    // MARK: - Stats Row
    
    private var statsRow: some View {
        HStack(spacing: 60) {
            statItem(value: "\(organization.memberCount ?? 0)", label: "Members")
            statItem(value: organization.type.rawValue.capitalized, label: "Type")
            statItem(value: "3", label: "Agents")
        }
    }
    
    private func statItem(value: String, label: String) -> some View {
        VStack(spacing: 4) {
            Text(value)
                .font(.system(size: 24, weight: .bold))
                .foregroundStyle(Color(red: 0.118, green: 0.161, blue: 0.231))
            
            Text(label)
                .font(.system(size: 14))
                .foregroundStyle(.secondary)
        }
    }
    
    // MARK: - Members Section
    
    private var membersSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("Members")
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundStyle(Color(red: 0.118, green: 0.161, blue: 0.231))
                
                Spacer()
                
                // 搜索框
                HStack(spacing: 8) {
                    Image(systemName: "magnifyingglass")
                        .font(.system(size: 12))
                        .foregroundStyle(.secondary)
                    
                    TextField("Search...", text: $memberSearchText)
                        .textFieldStyle(.plain)
                }
                .padding(8)
                .frame(width: 200)
                .background(Color.gray.opacity(0.1))
                .cornerRadius(8)
            }
            
            // 成员列表
            VStack(spacing: 8) {
                ForEach(appViewModel.organizationViewModel.members) { member in
                    MemberRowView(member: member)
                }
            }
        }
    }
    
    private var avatarColor: Color {
        let colors: [Color] = [
            Color(red: 0.231, green: 0.510, blue: 0.965),
            Color(red: 0.545, green: 0.361, blue: 0.965),
            Color(red: 0.961, green: 0.620, blue: 0.043),
            Color(red: 0.063, green: 0.725, blue: 0.506),
            Color(red: 0.941, green: 0.267, blue: 0.459)
        ]
        let index = abs(organization.name.hashValue) % colors.count
        return colors[index]
    }
}

// MARK: - Member Row View

struct MemberRowView: View {
    let member: OrgMembership
    
    var body: some View {
        HStack(spacing: 12) {
            // 头像
            Circle()
                .fill(avatarColor)
                .frame(width: 40, height: 40)
                .overlay {
                    Text(member.userName?.prefix(1) ?? "?")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(.white)
                }
            
            VStack(alignment: .leading, spacing: 2) {
                Text(member.userName ?? "Unknown")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(Color(red: 0.118, green: 0.161, blue: 0.231))
                
                Text(member.userEmail ?? "")
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
            }
            
            Spacer()
            
            // 角色标签
            Text(member.role.rawValue.capitalized)
                .font(.system(size: 12, weight: .medium))
                .padding(.horizontal, 10)
                .padding(.vertical, 4)
                .background(roleBackgroundColor.opacity(0.1))
                .foregroundStyle(roleBackgroundColor)
                .cornerRadius(6)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .background(Color.white)
        .cornerRadius(12)
    }
    
    private var avatarColor: Color {
        let colors: [Color] = [
            Color(red: 0.063, green: 0.725, blue: 0.506),  // Green
            Color(red: 0.545, green: 0.361, blue: 0.965),  // Purple
            Color(red: 0.961, green: 0.620, blue: 0.043),  // Orange
            Color(red: 0.231, green: 0.510, blue: 0.965),  // Blue
            Color(red: 0.941, green: 0.267, blue: 0.459)   // Pink
        ]
        let index = abs(member.userId.hashValue) % colors.count
        return colors[index]
    }
    
    private var roleBackgroundColor: Color {
        switch member.role {
        case .owner: return .blue
        case .admin: return Color(red: 0.545, green: 0.361, blue: 0.965) // Purple
        case .member: return .secondary
        }
    }
}

// MARK: - Create Organization View

struct CreateOrganizationView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(AppViewModel.self) private var appViewModel
    
    @State private var name = ""
    @State private var description = ""
    @State private var selectedType: OrganizationType = .team
    
    var body: some View {
        HStack(spacing: 0) {
            // 侧边栏
            sidebar
            
            // 表单区域
            formArea
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    // MARK: - Sidebar
    
    private var sidebar: some View {
        VStack(spacing: 0) {
            // 头部
            HStack {
                Button {
                    dismiss()
                } label: {
                    ZStack {
                        RoundedRectangle(cornerRadius: 8)
                            .fill(Color.gray.opacity(0.1))
                            .frame(width: 32, height: 32)
                        Image(systemName: "arrow.left")
                            .font(.system(size: 12))
                            .foregroundStyle(.secondary)
                    }
                }
                .buttonStyle(.plain)
                
                Text("My Organizations")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(Color(red: 0.118, green: 0.161, blue: 0.231))
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 16)
            .overlay(
                Rectangle()
                    .fill(Color.gray.opacity(0.2))
                    .frame(height: 1),
                alignment: .bottom
            )
            
            // 组织列表
            ScrollView {
                LazyVStack(spacing: 4) {
                    ForEach(appViewModel.organizationViewModel.organizations) { org in
                        OrgRowView(organization: org)
                            .cornerRadius(10)
                            .onTapGesture {
                                Task {
                                    await appViewModel.organizationViewModel.selectOrganization(org)
                                }
                                dismiss()
                            }
                    }
                }
                .padding(.horizontal, 8)
            }
        }
        .frame(width: 320)
        .background(Color.white)
        .overlay(
            Rectangle()
                .fill(Color.gray.opacity(0.2))
                .frame(width: 1),
            alignment: .trailing
        )
    }
    
    // MARK: - Form Area
    
    private var formArea: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 32) {
                Text("Create New Organization")
                    .font(.system(size: 28, weight: .bold))
                    .foregroundStyle(Color(red: 0.118, green: 0.161, blue: 0.231))
                
                // 名称
                VStack(alignment: .leading, spacing: 8) {
                    Text("Organization Name")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(Color(red: 0.118, green: 0.161, blue: 0.231))
                    
                    TextField("e.g., My Company", text: $name)
                        .textFieldStyle(.roundedBorder)
                        .frame(width: 500)
                }
                
                // 描述
                VStack(alignment: .leading, spacing: 8) {
                    Text("Description")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(Color(red: 0.118, green: 0.161, blue: 0.231))
                    
                    TextEditor(text: $description)
                        .frame(width: 500, height: 100)
                        .padding(8)
                        .background(Color.white)
                        .cornerRadius(8)
                        .overlay(
                            RoundedRectangle(cornerRadius: 8)
                                .stroke(Color.gray.opacity(0.3), lineWidth: 1)
                        )
                }
                
                // 类型
                VStack(alignment: .leading, spacing: 12) {
                    Text("Organization Type")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(Color(red: 0.118, green: 0.161, blue: 0.231))
                    
                    HStack(spacing: 12) {
                        typeOption(type: .team, icon: "person.2.fill", title: "Team", subtitle: "Small team collaboration")
                        typeOption(type: .enterprise, icon: "building.2.fill", title: "Enterprise", subtitle: "Large organization")
                    }
                }
                
                // 按钮
                HStack(spacing: 16) {
                    Button("Cancel") {
                        dismiss()
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.large)
                    
                    Button {
                        Task {
                            await createOrganization()
                        }
                    } label: {
                        HStack(spacing: 8) {
                            Image(systemName: "plus")
                            Text("Create Organization")
                        }
                        .font(.system(size: 14, weight: .semibold))
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)
                    .disabled(name.isEmpty)
                }
                .padding(.top, 16)
            }
            .padding(80)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.white)
    }
    
    private func typeOption(type: OrganizationType, icon: String, title: String, subtitle: String) -> some View {
        Button {
            selectedType = type
        } label: {
            HStack(spacing: 12) {
                ZStack {
                    RoundedRectangle(cornerRadius: 8)
                        .fill(selectedType == type ? Color.blue.opacity(0.1) : Color.gray.opacity(0.1))
                        .frame(width: 40, height: 40)
                    Image(systemName: icon)
                        .font(.system(size: 16))
                        .foregroundStyle(selectedType == type ? .blue : .secondary)
                }
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(Color(red: 0.118, green: 0.161, blue: 0.231))
                    Text(subtitle)
                        .font(.system(size: 12))
                        .foregroundStyle(.secondary)
                }
            }
            .padding(16)
            .background(selectedType == type ? Color.blue.opacity(0.05) : Color.white)
            .cornerRadius(10)
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .stroke(selectedType == type ? Color.blue : Color.gray.opacity(0.3), lineWidth: selectedType == type ? 2 : 1)
            )
        }
        .buttonStyle(.plain)
    }
    
    private func createOrganization() async {
        await appViewModel.organizationViewModel.createOrganization(
            name: name,
            description: description.isEmpty ? nil : description,
            type: selectedType
        )
        dismiss()
    }
}

// MARK: - Search Organizations View

struct SearchOrganizationsView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(AppViewModel.self) private var appViewModel
    
    @State private var searchText = ""
    
    var body: some View {
        VStack(spacing: 0) {
            // 头部
            HStack {
                Button {
                    dismiss()
                } label: {
                    ZStack {
                        RoundedRectangle(cornerRadius: 8)
                            .fill(Color.gray.opacity(0.1))
                            .frame(width: 32, height: 32)
                        Image(systemName: "arrow.left")
                            .font(.system(size: 12))
                            .foregroundStyle(.secondary)
                    }
                }
                .buttonStyle(.plain)
                
                Text("Search Organizations")
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundStyle(Color(red: 0.118, green: 0.161, blue: 0.231))
                
                Spacer()
            }
            .padding(.horizontal, 32)
            .padding(.vertical, 16)
            .overlay(
                Rectangle()
                    .fill(Color.gray.opacity(0.2))
                    .frame(height: 1),
                alignment: .bottom
            )
            
            // 搜索框
            HStack(spacing: 12) {
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 14))
                    .foregroundStyle(.secondary)
                
                TextField("Search by name or organization ID...", text: $searchText)
                    .textFieldStyle(.plain)
            }
            .padding(12)
            .background(Color.gray.opacity(0.1))
            .cornerRadius(10)
            .padding(.horizontal, 32)
            .padding(.vertical, 16)
            
            // 搜索结果
            ScrollView {
                VStack(spacing: 16) {
                    ForEach(0..<5) { _ in
                        SearchOrgResultRow()
                    }
                }
                .padding(.horizontal, 32)
                .padding(.bottom, 32)
            }
        }
        .frame(width: 800, height: 600)
        .background(Color.white)
    }
}

struct SearchOrgResultRow: View {
    @State private var isPending = false
    
    var body: some View {
        HStack(spacing: 16) {
            // 头像
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(red: 0.063, green: 0.725, blue: 0.506))
                .frame(width: 56, height: 56)
                .overlay {
                    Text("TC")
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundStyle(.white)
                }
            
            // 信息
            VStack(alignment: .leading, spacing: 4) {
                Text("Tech Corp")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(Color(red: 0.118, green: 0.161, blue: 0.231))
                
                Text("Enterprise • 156 members")
                    .font(.system(size: 13))
                    .foregroundStyle(.secondary)
            }
            
            Spacer()
            
            // 加入按钮
            Button {
                isPending = true
            } label: {
                Text(isPending ? "Pending" : "Request Join")
                    .font(.system(size: 13, weight: .medium))
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    .background(isPending ? Color(red: 1.0, green: 0.953, blue: 0.776) : Color.blue)
                    .foregroundStyle(isPending ? Color(red: 0.851, green: 0.466, blue: 0.024) : .white)
                    .cornerRadius(8)
            }
            .buttonStyle(.plain)
            .disabled(isPending)
        }
        .padding(16)
        .background(Color.white)
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.gray.opacity(0.2), lineWidth: 1)
        )
    }
}

// MARK: - Join Requests View

struct JoinRequestsView: View {
    @Environment(\.dismiss) private var dismiss
    
    @State private var selectedTab = 0
    
    var body: some View {
        VStack(spacing: 0) {
            // 头部
            HStack {
                Button {
                    dismiss()
                } label: {
                    ZStack {
                        RoundedRectangle(cornerRadius: 8)
                            .fill(Color.gray.opacity(0.1))
                            .frame(width: 32, height: 32)
                        Image(systemName: "arrow.left")
                            .font(.system(size: 12))
                            .foregroundStyle(.secondary)
                    }
                }
                .buttonStyle(.plain)
                
                Text("Join Requests")
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundStyle(Color(red: 0.118, green: 0.161, blue: 0.231))
                
                Spacer()
            }
            .padding(.horizontal, 32)
            .padding(.vertical, 16)
            .overlay(
                Rectangle()
                    .fill(Color.gray.opacity(0.2))
                    .frame(height: 1),
                alignment: .bottom
            )
            
            // 标签
            HStack(spacing: 24) {
                Button {
                    selectedTab = 0
                } label: {
                    VStack(spacing: 0) {
                        Text("Incoming (3)")
                            .font(.system(size: 14, weight: selectedTab == 0 ? .semibold : .medium))
                            .foregroundStyle(selectedTab == 0 ? .blue : .secondary)
                            .padding(.vertical, 14)
                        
                        Rectangle()
                            .fill(selectedTab == 0 ? Color.blue : Color.clear)
                            .frame(height: 2)
                    }
                }
                .buttonStyle(.plain)
                
                Button {
                    selectedTab = 1
                } label: {
                    VStack(spacing: 0) {
                        Text("Outgoing (1)")
                            .font(.system(size: 14, weight: selectedTab == 1 ? .semibold : .medium))
                            .foregroundStyle(selectedTab == 1 ? .blue : .secondary)
                            .padding(.vertical, 14)
                        
                        Rectangle()
                            .fill(selectedTab == 1 ? Color.blue : Color.clear)
                            .frame(height: 2)
                    }
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 32)
            .overlay(
                Rectangle()
                    .fill(Color.gray.opacity(0.2))
                    .frame(height: 1),
                alignment: .bottom
            )
            
            // 请求列表
            ScrollView {
                VStack(spacing: 16) {
                    ForEach(0..<3) { _ in
                        JoinRequestRow()
                    }
                }
                .padding(32)
            }
        }
        .frame(width: 900, height: 600)
        .background(Color.white)
    }
}

struct JoinRequestRow: View {
    var body: some View {
        VStack(spacing: 12) {
            HStack(spacing: 12) {
                // 头像
                Circle()
                    .fill(Color(red: 0.063, green: 0.725, blue: 0.506))
                    .frame(width: 48, height: 48)
                    .overlay {
                        Text("J")
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundStyle(.white)
                    }
                
                // 用户信息
                VStack(alignment: .leading, spacing: 2) {
                    Text("John Smith")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(Color(red: 0.118, green: 0.161, blue: 0.231))
                    
                    Text("john@example.com")
                        .font(.system(size: 13))
                        .foregroundStyle(.secondary)
                }
                
                Spacer()
                
                // 组织信息
                VStack(alignment: .trailing, spacing: 2) {
                    Text("AI Research Team")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(Color(red: 0.118, green: 0.161, blue: 0.231))
                    
                    Text("Requested 2 days ago")
                        .font(.system(size: 12))
                        .foregroundStyle(.secondary)
                }
            }
            
            // 操作按钮
            HStack {
                Spacer()
                
                Button("Reject") {
                    // TODO: 拒绝
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
                
                Button("Approve") {
                    // TODO: 批准
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.small)
            }
        }
        .padding(16)
        .background(Color.white)
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.gray.opacity(0.2), lineWidth: 1)
        )
    }
}

// MARK: - Invite Members View

struct InviteMembersView: View {
    @Environment(\.dismiss) private var dismiss
    
    let organization: Organization
    
    @State private var searchText = ""
    @State private var selectedRole: MemberRole = .member
    
    var body: some View {
        HStack(spacing: 0) {
            // 侧边栏
            sidebar
            
            // 主内容
            mainContent
        }
        .frame(width: 900, height: 600)
    }
    
    // MARK: - Sidebar
    
    private var sidebar: some View {
        VStack(spacing: 0) {
            // 头部
            HStack {
                Button {
                    dismiss()
                } label: {
                    ZStack {
                        RoundedRectangle(cornerRadius: 8)
                            .fill(Color.gray.opacity(0.1))
                            .frame(width: 32, height: 32)
                        Image(systemName: "arrow.left")
                            .font(.system(size: 12))
                            .foregroundStyle(.secondary)
                    }
                }
                .buttonStyle(.plain)
                
                Text(organization.name)
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(Color(red: 0.118, green: 0.161, blue: 0.231))
                    .lineLimit(1)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 16)
            .overlay(
                Rectangle()
                    .fill(Color.gray.opacity(0.2))
                    .frame(height: 1),
                alignment: .bottom
            )
            
            // 成员预览
            VStack(alignment: .leading, spacing: 12) {
                Text("Current Members (24)")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(.secondary)
                
                ForEach(0..<5) { _ in
                    HStack(spacing: 10) {
                        Circle()
                            .fill(Color(red: 0.063, green: 0.725, blue: 0.506))
                            .frame(width: 36, height: 36)
                            .overlay {
                                Text("J")
                                    .font(.system(size: 14, weight: .semibold))
                                    .foregroundStyle(.white)
                            }
                        
                        Text("John Smith")
                            .font(.system(size: 13, weight: .medium))
                            .foregroundStyle(Color(red: 0.118, green: 0.161, blue: 0.231))
                        
                        Spacer()
                        
                        Text("Owner")
                            .font(.system(size: 10, weight: .medium))
                            .foregroundStyle(.blue)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(Color.blue.opacity(0.1))
                            .cornerRadius(4)
                    }
                }
            }
            .padding(16)
            
            Spacer()
        }
        .frame(width: 320)
        .background(Color.white)
        .overlay(
            Rectangle()
                .fill(Color.gray.opacity(0.2))
                .frame(width: 1),
            alignment: .trailing
        )
    }
    
    // MARK: - Main Content
    
    private var mainContent: some View {
        VStack(alignment: .leading, spacing: 32) {
            Text("Invite Members")
                .font(.system(size: 28, weight: .bold))
                .foregroundStyle(Color(red: 0.118, green: 0.161, blue: 0.231))
            
            // 搜索框
            VStack(alignment: .leading, spacing: 12) {
                Text("Search by Email")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(Color(red: 0.118, green: 0.161, blue: 0.231))
                
                HStack(spacing: 12) {
                    Image(systemName: "magnifyingglass")
                        .font(.system(size: 14))
                        .foregroundStyle(.secondary)
                    
                    TextField("Enter email address...", text: $searchText)
                        .textFieldStyle(.plain)
                }
                .padding(12)
                .background(Color.gray.opacity(0.1))
                .cornerRadius(10)
            }
            
            // 搜索结果
            VStack(alignment: .leading, spacing: 12) {
                Text("Search Results")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(.secondary)
                
                VStack(spacing: 12) {
                    ForEach(0..<2) { index in
                        InviteUserRow(isInvited: index == 1)
                    }
                }
            }
            
            // 角色选择
            VStack(alignment: .leading, spacing: 12) {
                Text("Assign Role")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(Color(red: 0.118, green: 0.161, blue: 0.231))
                
                HStack(spacing: 12) {
                    roleButton(role: .member, icon: "person.fill", label: "Member")
                    roleButton(role: .admin, icon: "shield.fill", label: "Admin")
                }
            }
            
            Spacer()
        }
        .padding(48)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.white)
    }
    
    private func roleButton(role: MemberRole, icon: String, label: String) -> some View {
        Button {
            selectedRole = role
        } label: {
            HStack(spacing: 10) {
                Image(systemName: icon)
                    .font(.system(size: 14))
                
                Text(label)
                    .font(.system(size: 14, weight: .medium))
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(selectedRole == role ? Color.blue.opacity(0.05) : Color.white)
            .foregroundStyle(selectedRole == role ? .blue : .secondary)
            .cornerRadius(8)
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(selectedRole == role ? Color.blue : Color.gray.opacity(0.3), lineWidth: selectedRole == role ? 2 : 1)
            )
        }
        .buttonStyle(.plain)
    }
}

struct InviteUserRow: View {
    var isInvited: Bool = false
    
    var body: some View {
        HStack(spacing: 12) {
            // 头像
            Circle()
                .fill(Color(red: 0.961, green: 0.620, blue: 0.043))
                .frame(width: 44, height: 44)
                .overlay {
                    Text("M")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(.white)
                }
            
            // 信息
            VStack(alignment: .leading, spacing: 2) {
                Text("Mike Chen")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(Color(red: 0.118, green: 0.161, blue: 0.231))
                
                Text("mike@example.com")
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
            }
            
            Spacer()
            
            // 邀请按钮
            if isInvited {
                Text("Invited")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(Color(red: 0.024, green: 0.588, blue: 0.412))
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(Color(red: 0.820, green: 0.980, blue: 0.898))
                    .cornerRadius(8)
            } else {
                Button("Invite") {
                    // TODO: 邀请
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.small)
            }
        }
        .padding(16)
        .background(isInvited ? Color.gray.opacity(0.03) : Color.white)
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.gray.opacity(0.2), lineWidth: 1)
        )
    }
}

#Preview {
    OrganizationView()
        .environment(AppViewModel())
}