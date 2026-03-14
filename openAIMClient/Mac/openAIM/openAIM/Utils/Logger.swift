//
//  Logger.swift
//  openAIM
//
//  Created by Claude on 2026/3/12.
//

import Foundation
import os.log

/// 统一日志工具 - 支持客户端标识和用户标识
final class Logger {
    static let shared = Logger()

    // 客户端实例唯一标识（每次启动生成新的，区分同一机器上的多个实例）
    private let clientId: String

    // 当前用户信息
    private var currentUserId: String = "unknown"
    private var currentUserEmail: String = "unknown"

    // 日志文件路径
    private let logFileURL: URL
    private let logQueue = DispatchQueue(label: "com.openaim.logger", qos: .utility)

    // 日志级别
    enum Level: String {
        case debug = "DEBUG"
        case info = "INFO"
        case warn = "WARN"
        case error = "ERROR"

        var emoji: String {
            switch self {
            case .debug: return "🔍"
            case .info: return "ℹ️"
            case .warn: return "⚠️"
            case .error: return "❌"
            }
        }
    }

    private init() {
        // 为每个实例生成独立的客户端 ID（结合进程 PID 和 UUID）
        // 这样同一台机器上的多个客户端实例会有不同的 ID
        let pid = ProcessInfo.processInfo.processIdentifier
        let uuid = UUID().uuidString.prefix(4)
        self.clientId = "client_\(pid)_\(uuid)"

        // 设置日志文件路径（包含 PID 便于区分）
        let logsDir = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("OpenAIM", isDirectory: true)
            .appendingPathComponent("Logs", isDirectory: true)

        try? FileManager.default.createDirectory(at: logsDir, withIntermediateDirectories: true)
        self.logFileURL = logsDir.appendingPathComponent("client_\(Date().formatted(date: .abbreviated, time: .shortened).replacingOccurrences(of: "/", with: "-").replacingOccurrences(of: ":", with: "-")).log")

        // 写入启动日志
        writeToFile("[\(timestamp())] [\(clientId)] [SYSTEM] App started (PID: \(pid))")
    }

    // MARK: - 用户信息更新

    /// 更新当前用户信息
    func updateUser(userId: String, email: String) {
        self.currentUserId = userId
        self.currentUserEmail = email
        writeToFile("[\(timestamp())] [\(clientId)] [USER] User logged in: \(email) (\(userId))")
    }

    /// 清除用户信息
    func clearUser() {
        writeToFile("[\(timestamp())] [\(clientId)] [USER] User logged out: \(currentUserEmail)")
        self.currentUserId = "unknown"
        self.currentUserEmail = "unknown"
    }

    // MARK: - 日志方法

    func debug(_ module: String, _ message: String, file: String = #file, function: String = #function, line: Int = #line) {
        log(level: .debug, module: module, message: message, file: file, function: function, line: line)
    }

    func info(_ module: String, _ message: String, file: String = #file, function: String = #function, line: Int = #line) {
        log(level: .info, module: module, message: message, file: file, function: function, line: line)
    }

    func warn(_ module: String, _ message: String, file: String = #file, function: String = #function, line: Int = #line) {
        log(level: .warn, module: module, message: message, file: file, function: function, line: line)
    }

    func error(_ module: String, _ message: String, file: String = #file, function: String = #function, line: Int = #line) {
        log(level: .error, module: module, message: message, file: file, function: function, line: line)
    }

    private func log(level: Level, module: String, message: String, file: String, function: String, line: Int) {
        let fileName = (file as NSString).lastPathComponent
        let userInfo = "[\(currentUserId)|\(currentUserEmail)]"
        let logMessage = "[\(timestamp())] [\(clientId)] \(userInfo) [\(level.rawValue)] [\(module)] \(message) (\(fileName):\(line))"

        // 控制台输出
        print("\(level.emoji) \(logMessage)")

        // 写入文件
        writeToFile(logMessage)
    }

    private func timestamp() -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd HH:mm:ss.SSS"
        return formatter.string(from: Date())
    }

    private func writeToFile(_ message: String) {
        logQueue.async { [weak self] in
            guard let self = self else { return }
            do {
                let data = message + "\n"
                if FileManager.default.fileExists(atPath: self.logFileURL.path) {
                    let fileHandle = try FileHandle(forWritingTo: self.logFileURL)
                    fileHandle.seekToEndOfFile()
                    fileHandle.write(data.data(using: .utf8)!)
                    fileHandle.closeFile()
                } else {
                    try data.write(to: self.logFileURL, atomically: true, encoding: .utf8)
                }
            } catch {
                print("Failed to write log: \(error)")
            }
        }
    }

    // MARK: - 日志导出

    /// 获取当前日志文件路径
    var currentLogFilePath: String {
        return logFileURL.path
    }

    /// 获取所有日志文件
    func getAllLogFiles() -> [URL] {
        let logsDir = logFileURL.deletingLastPathComponent()
        guard let files = try? FileManager.default.contentsOfDirectory(at: logsDir, includingPropertiesForKeys: nil) else {
            return []
        }
        return files.filter { $0.pathExtension == "log" }.sorted { $0.path > $1.path }
    }

    /// 导出日志到指定路径
    func exportLogs(to url: URL) -> Bool {
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyyMMdd_HHmmss"
        let timestamp = dateFormatter.string(from: Date())

        let archiveURL = url.appendingPathComponent("openaim_logs_\(timestamp)")

        do {
            // 创建临时目录
            let tempDir = FileManager.default.temporaryDirectory.appendingPathComponent("openaim_logs_export")
            try? FileManager.default.removeItem(at: tempDir)
            try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)

            // 复制所有日志文件
            let logFiles = getAllLogFiles()
            for file in logFiles {
                try FileManager.default.copyItem(at: file, to: tempDir.appendingPathComponent(file.lastPathComponent))
            }

            // 添加元数据文件
            let metadata = """
            OpenAIM Client Logs
            ===================
            Client ID: \(clientId)
            Export Time: \(Date())
            User ID: \(currentUserId)
            User Email: \(currentUserEmail)
            Log Files: \(logFiles.count)
            """
            try metadata.write(to: tempDir.appendingPathComponent("metadata.txt"), atomically: true, encoding: .utf8)

            // 复制整个目录到目标位置
            try FileManager.default.copyItem(at: tempDir, to: archiveURL)

            return true
        } catch {
            print("Failed to export logs: \(error)")
            return false
        }
    }

    /// 清除旧日志（保留最近7天）
    func cleanOldLogs() {
        let logsDir = logFileURL.deletingLastPathComponent()
        let calendar = Calendar.current
        let sevenDaysAgo = calendar.date(byAdding: .day, value: -7, to: Date())!

        guard let files = try? FileManager.default.contentsOfDirectory(at: logsDir, includingPropertiesForKeys: [.creationDateKey]) else {
            return
        }

        for file in files {
            if let creationDate = try? file.resourceValues(forKeys: [.creationDateKey]).creationDate,
               creationDate < sevenDaysAgo {
                try? FileManager.default.removeItem(at: file)
            }
        }
    }
}

// MARK: - 便捷日志宏

func logDebug(_ module: String, _ message: String, file: String = #file, function: String = #function, line: Int = #line) {
    Logger.shared.debug(module, message, file: file, function: function, line: line)
}

func logInfo(_ module: String, _ message: String, file: String = #file, function: String = #function, line: Int = #line) {
    Logger.shared.info(module, message, file: file, function: function, line: line)
}

func logWarn(_ module: String, _ message: String, file: String = #file, function: String = #function, line: Int = #line) {
    Logger.shared.warn(module, message, file: file, function: function, line: line)
}

func logError(_ module: String, _ message: String, file: String = #file, function: String = #function, line: Int = #line) {
    Logger.shared.error(module, message, file: file, function: function, line: line)
}