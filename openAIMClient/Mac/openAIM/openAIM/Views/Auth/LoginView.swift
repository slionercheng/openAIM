//
//  LoginView.swift
//  openAIM
//
//  Created by Claude on 2026/3/7.
//

import SwiftUI

struct LoginView: View {
    @Environment(AppViewModel.self) private var appViewModel

    @State private var email = ""
    @State private var password = ""
    @State private var rememberMe = true
    @State private var showRegister = false

    var body: some View {
        HStack(spacing: 0) {
            // 左侧品牌区 - 占一半宽度
            brandPanel
                .frame(maxWidth: .infinity)

            // 右侧登录表单 - 占一半宽度
            loginPanel
                .frame(maxWidth: .infinity)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .sheet(isPresented: $showRegister) {
            RegisterView()
        }
        .sheet(isPresented: Binding(
            get: { appViewModel.showAccountSelection },
            set: { appViewModel.showAccountSelection = $0 }
        )) {
            AccountSelectionView(showAccountSelection: Binding(
                get: { appViewModel.showAccountSelection },
                set: { appViewModel.showAccountSelection = $0 }
            ))
            .environment(appViewModel)
        }
        .onChange(of: appViewModel.authViewModel.state) { _, newState in
            if case .authenticated = newState {
                appViewModel.currentView = .main
                // 加载初始数据
                Task {
                    await appViewModel.loadInitialData()
                }
            }
        }
        .onChange(of: appViewModel.prefilledEmail) { _, newValue in
            if !newValue.isEmpty {
                email = newValue
                appViewModel.prefilledEmail = ""
            }
        }
        .onAppear {
            // 如果有保存的账号，自动填充第一个账号的邮箱
            if email.isEmpty {
                if let lastAccount = AccountManager.shared.getCurrentAccount() {
                    email = lastAccount.email
                }
            }
        }
    }

    // MARK: - Brand Panel

    private var brandPanel: some View {
        VStack(spacing: 20) {
            Image(systemName: "message.circle.fill")
                .font(.system(size: 64))
                .foregroundStyle(.white)

            Text("OpenAIM")
                .font(.system(size: 32, weight: .bold))
                .foregroundStyle(.white)

            Text("AI-Powered Communication Platform")
                .font(.system(size: 16))
                .foregroundStyle(.white.opacity(0.8))
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.blue)
    }

    // MARK: - Login Panel

    private var loginPanel: some View {
        VStack(spacing: 24) {
            // 标题
            VStack(spacing: 8) {
                Text("Welcome Back")
                    .font(.system(size: 28, weight: .semibold))
                    .foregroundStyle(.primary)

                Text("Sign in to continue")
                    .font(.system(size: 14))
                    .foregroundStyle(.secondary)
            }

            // 表单
            VStack(spacing: 16) {
                TextField("Email", text: $email)
                    .textFieldStyle(.roundedBorder)
                    .textContentType(.emailAddress)
                    .frame(height: 44)

                SecureField("Password", text: $password)
                    .textFieldStyle(.roundedBorder)
                    .textContentType(.password)
                    .frame(height: 44)

                // 记住我
                HStack {
                    Toggle("Remember me", isOn: $rememberMe)
                        .font(.system(size: 13))
                    Spacer()
                }
            }
            .frame(maxWidth: 320)

            // 错误提示
            if !appViewModel.authViewModel.errorMessage.isEmpty {
                Text(appViewModel.authViewModel.errorMessage)
                    .font(.system(size: 13))
                    .foregroundStyle(.red)
            }

            // 登录按钮
            Button {
                Task {
                    await login()
                }
            } label: {
                if appViewModel.authViewModel.isLoading {
                    ProgressView()
                        .frame(maxWidth: .infinity)
                        .frame(height: 48)
                } else {
                    Text("Sign In")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .frame(height: 48)
                }
            }
            .buttonStyle(.borderedProminent)
            .frame(maxWidth: 320)
            .disabled(appViewModel.authViewModel.isLoading)

            // 已保存账号
            if !AccountManager.shared.getSavedAccounts().isEmpty {
                Button {
                    appViewModel.showAccountSelection = true
                } label: {
                    Text("Use saved account")
                        .font(.system(size: 14))
                        .foregroundStyle(.blue)
                }
            }

            // 忘记密码
            Button("Forgot password?") {
                // TODO: 忘记密码
            }
            .font(.system(size: 14))
            .foregroundStyle(.blue)

            // 分割线
            HStack {
                Rectangle()
                    .fill(Color.gray.opacity(0.3))
                    .frame(height: 1)
                Text("or")
                    .font(.system(size: 14))
                    .foregroundStyle(.secondary)
                Rectangle()
                    .fill(Color.gray.opacity(0.3))
                    .frame(height: 1)
            }
            .frame(maxWidth: 320)

            // Google 登录
            Button {
                // TODO: Google 登录
            } label: {
                HStack(spacing: 12) {
                    Text("G")
                        .font(.system(size: 18, weight: .bold))
                    Text("Continue with Google")
                        .font(.system(size: 14, weight: .medium))
                }
                .frame(maxWidth: .infinity)
                .frame(height: 48)
            }
            .buttonStyle(.bordered)
            .frame(maxWidth: 320)

            // 注册链接
            HStack(spacing: 4) {
                Text("Don't have an account?")
                    .font(.system(size: 14))
                    .foregroundStyle(.secondary)

                Button("Sign up") {
                    showRegister = true
                }
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(.blue)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.gray.opacity(0.05))
    }

    private func login() async {
        await appViewModel.authViewModel.login(
            email: email,
            password: password,
            rememberMe: rememberMe
        )
    }
}

#Preview {
    LoginView()
        .environment(AppViewModel())
}