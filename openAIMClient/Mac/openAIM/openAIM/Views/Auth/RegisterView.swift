//
//  RegisterView.swift
//  openAIM
//
//  Created by Claude on 2026/3/7.
//

import SwiftUI

struct RegisterView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(AppViewModel.self) private var appViewModel

    @State private var name = ""
    @State private var email = ""
    @State private var password = ""
    @State private var confirmPassword = ""

    // 验证状态
    @State private var nameError: String?
    @State private var emailError: String?
    @State private var passwordError: String?
    @State private var confirmPasswordError: String?

    // 是否显示验证提示
    @State private var showValidation = false

    var body: some View {
        HStack(spacing: 0) {
            // 左侧品牌区
            brandPanel

            // 右侧注册表单
            registerPanel
        }
        .frame(width: 900, height: 600)
        .onChange(of: appViewModel.authViewModel.state) { _, newState in
            if case .authenticated = newState {
                dismiss()
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
        .frame(width: 400)
        .frame(maxHeight: .infinity)
        .background(Color.blue)
    }

    // MARK: - Register Panel

    private var registerPanel: some View {
        VStack(spacing: 16) {
            // 标题
            VStack(spacing: 8) {
                Text("Create Account")
                    .font(.system(size: 28, weight: .semibold))
                    .foregroundStyle(.primary)

                Text("Join OpenAIM today")
                    .font(.system(size: 14))
                    .foregroundStyle(.secondary)
            }

            // 表单
            VStack(spacing: 12) {
                // 姓名输入
                VStack(alignment: .leading, spacing: 4) {
                    TextField("Full Name", text: $name)
                        .textFieldStyle(.roundedBorder)
                        .textContentType(.name)
                        .frame(height: 44)
                        .onChange(of: name) { _, _ in validateName() }

                    if let error = nameError, showValidation {
                        Text(error)
                            .font(.system(size: 11))
                            .foregroundStyle(.red)
                    }
                }

                // 邮箱输入
                VStack(alignment: .leading, spacing: 4) {
                    TextField("Email", text: $email)
                        .textFieldStyle(.roundedBorder)
                        .textContentType(.emailAddress)
                        .frame(height: 44)
                        .onChange(of: email) { _, _ in validateEmail() }

                    if let error = emailError, showValidation {
                        Text(error)
                            .font(.system(size: 11))
                            .foregroundStyle(.red)
                    }
                }

                // 密码输入
                VStack(alignment: .leading, spacing: 4) {
                    SecureField("Password (min 8 characters)", text: $password)
                        .textFieldStyle(.roundedBorder)
                        .textContentType(.newPassword)
                        .frame(height: 44)
                        .onChange(of: password) { _, _ in
                            validatePassword()
                            if !confirmPassword.isEmpty {
                                validateConfirmPassword()
                            }
                        }

                    // 密码强度指示
                    if !password.isEmpty {
                        passwordStrengthIndicator
                    }

                    if let error = passwordError, showValidation {
                        Text(error)
                            .font(.system(size: 11))
                            .foregroundStyle(.red)
                    }
                }

                // 确认密码
                VStack(alignment: .leading, spacing: 4) {
                    SecureField("Confirm Password", text: $confirmPassword)
                        .textFieldStyle(.roundedBorder)
                        .textContentType(.newPassword)
                        .frame(height: 44)
                        .onChange(of: confirmPassword) { _, _ in validateConfirmPassword() }

                    if let error = confirmPasswordError, showValidation {
                        Text(error)
                            .font(.system(size: 11))
                            .foregroundStyle(.red)
                    }
                }
            }
            .frame(maxWidth: 320)

            // 服务器错误提示
            if !appViewModel.authViewModel.errorMessage.isEmpty {
                Text(appViewModel.authViewModel.errorMessage)
                    .font(.system(size: 13))
                    .foregroundStyle(.red)
            }

            // 注册按钮
            Button {
                showValidation = true
                validateAll()
                if isFormValid {
                    Task {
                        await appViewModel.authViewModel.register(email: email, password: password, name: name)
                    }
                }
            } label: {
                if appViewModel.authViewModel.isLoading {
                    ProgressView()
                        .frame(maxWidth: .infinity)
                        .frame(height: 48)
                } else {
                    Text("Create Account")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .frame(height: 48)
                }
            }
            .buttonStyle(.borderedProminent)
            .frame(maxWidth: 320)
            .disabled(appViewModel.authViewModel.isLoading)

            // 登录链接
            HStack(spacing: 4) {
                Text("Already have an account?")
                    .font(.system(size: 14))
                    .foregroundStyle(.secondary)

                Button("Sign in") {
                    dismiss()
                }
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(.blue)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.gray.opacity(0.05))
    }

    // MARK: - Password Strength Indicator

    private var passwordStrengthIndicator: some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack(spacing: 4) {
                ForEach(0..<4) { index in
                    Rectangle()
                        .fill(passwordStrengthColor(for: index))
                        .frame(height: 3)
                        .frame(maxWidth: .infinity)
                }
            }

            Text(passwordStrengthText)
                .font(.system(size: 10))
                .foregroundStyle(passwordStrengthColor(for: passwordStrengthLevel - 1))
        }
    }

    // MARK: - Validation Logic

    private var isFormValid: Bool {
        nameError == nil && emailError == nil && passwordError == nil && confirmPasswordError == nil
    }

    private func validateAll() {
        validateName()
        validateEmail()
        validatePassword()
        validateConfirmPassword()
    }

    private func validateName() {
        let trimmedName = name.trimmingCharacters(in: .whitespaces)
        if trimmedName.isEmpty {
            nameError = "请输入姓名"
        } else if trimmedName.count < 2 {
            nameError = "姓名至少需要 2 个字符"
        } else if trimmedName.count > 50 {
            nameError = "姓名不能超过 50 个字符"
        } else {
            nameError = nil
        }
    }

    private func validateEmail() {
        let trimmedEmail = email.trimmingCharacters(in: .whitespaces)
        if trimmedEmail.isEmpty {
            emailError = "请输入邮箱"
        } else if !isValidEmail(trimmedEmail) {
            emailError = "请输入有效的邮箱地址"
        } else {
            emailError = nil
        }
    }

    private func validatePassword() {
        if password.isEmpty {
            passwordError = "请输入密码"
        } else if password.count < 8 {
            passwordError = "密码至少需要 8 个字符"
        } else {
            passwordError = nil
        }
    }

    private func validateConfirmPassword() {
        if confirmPassword.isEmpty {
            confirmPasswordError = "请确认密码"
        } else if confirmPassword != password {
            confirmPasswordError = "两次输入的密码不一致"
        } else {
            confirmPasswordError = nil
        }
    }

    private func isValidEmail(_ email: String) -> Bool {
        let emailRegex = "[A-Z0-9a-z._%+-]+@[A-Za-z0-9.-]+\\.[A-Za-z]{2,64}"
        return NSPredicate(format: "SELF MATCHES %@", emailRegex).evaluate(with: email)
    }

    // MARK: - Password Strength

    private var passwordStrengthLevel: Int {
        var score = 0
        if password.count >= 8 { score += 1 }
        if password.count >= 12 { score += 1 }
        if password.contains(where: { $0.isUppercase }) { score += 1 }
        if password.contains(where: { $0.isNumber }) { score += 1 }
        if password.contains(where: { !$0.isLetter && !$0.isNumber }) { score += 1 }
        return min(score, 4)
    }

    private var passwordStrengthText: String {
        switch passwordStrengthLevel {
        case 0: return "非常弱"
        case 1: return "弱"
        case 2: return "一般"
        case 3: return "强"
        case 4: return "非常强"
        default: return ""
        }
    }

    private func passwordStrengthColor(for index: Int) -> Color {
        let level = passwordStrengthLevel
        if index >= level {
            return Color.gray.opacity(0.3)
        }
        switch level {
        case 0, 1: return .red
        case 2: return .orange
        case 3: return .green
        case 4: return .blue
        default: return .gray.opacity(0.3)
        }
    }
}

#Preview {
    RegisterView()
        .environment(AppViewModel())
}