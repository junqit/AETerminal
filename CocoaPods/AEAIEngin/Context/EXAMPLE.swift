//
//  EXAMPLE.swift
//  AEAIEngin
//
//  使用示例 - 展示如何使用 AEAIContext
//

import Foundation

// MARK: - 示例 1：基本使用

func example1_BasicUsage() {
    // 创建配置
    let config = AEContextConfig(content: "iOS 开发助手")

    // 创建上下文
    let context = AEAIContext(config: config)

    // 发送问题
    let question = AEAIQuestion.text("如何实现自定义 UITableViewCell？")
    context.sendQuestion(question) { result in
        switch result {
        case .success(let response):
            print("AI 响应: \(response)")
        case .failure(let error):
            print("错误: \(error)")
        }
    }
}

// MARK: - 示例 2：使用 ContextManager 类方法

func example2_ContextManager() {
    // 创建配置
    let config1 = AEContextConfig(content: "项目A")

    // 通过 Manager 创建并管理（自动检查是否已存在）
    let managedContext1 = AEAIContextManager.createContext(config1)

    // 创建另一个上下文
    let config2 = AEContextConfig(
        content: "项目B",
        maxMessageCount: 50,
        metadata: ["version": "1.0"]
    )
    let managedContext2 = AEAIContextManager.createContext(config2)

    // 重复创建相同 ID 的上下文会返回现有的
    let sameContext = AEAIContextManager.createContext(config1)
    // sameContext === managedContext1 (指向同一对象)

    // 发送问题
    let question = AEAIQuestion.command("/analyze code")
    managedContext2.sendQuestion(question) { result in
        // 处理响应
    }

    // 获取所有上下文
    let allContexts = AEAIContextManager.getAllContexts()
    print("共有 \(allContexts.count) 个上下文")

    // 根据 ID 获取
    if let context = AEAIContextManager.getContext(id: managedContext1.id) {
        print("找到上下文: \(context.dir)")
    }

    // 删除上下文（使用上下文对象）
    AEAIContextManager.removeContext(managedContext1)

    // 清空所有
    AEAIContextManager.clearAllContexts()
}

// MARK: - 示例 3：不同类型的问题

func example3_QuestionTypes() {
    // 创建并管理上下文
    let config = AEContextConfig(content: "助手")
    let managedContext = AEAIContextManager.createContext(config)

    // 文本问题
    let textQuestion = AEAIQuestion.text("如何实现登录功能？")
    managedContext.sendQuestion(textQuestion) { _ in }

    // 命令问题
    let commandQuestion = AEAIQuestion.command("/help")
    managedContext.sendQuestion(commandQuestion) { _ in }

    // 搜索问题
    let searchQuestion = AEAIQuestion.search("React hooks")
    managedContext.sendQuestion(searchQuestion) { _ in }

    // 自定义类型问题（带参数）
    let customQuestion = AEAIQuestion(
        content: "生成代码",
        type: .custom("generate"),
        parameters: [
            "language": "Swift",
            "framework": "UIKit"
        ]
    )
    managedContext.sendQuestion(customQuestion) { _ in }
}

// MARK: - 示例 4：消息历史管理

func example4_MessageHistory() {
    // 创建并管理上下文
    let config = AEContextConfig(content: "助手")
    let managedContext = AEAIContextManager.createContext(config)

    // 添加几个问题
    managedContext.sendQuestion(AEAIQuestion.text("问题1")) { _ in }
    managedContext.sendQuestion(AEAIQuestion.text("问题2")) { _ in }
    managedContext.sendQuestion(AEAIQuestion.text("问题3")) { _ in }

    // 获取当前问题
    if let current = managedContext.getCurrentQuestion() {
        print("当前: \(current.content)")
    }

    // 获取上一条
    if let previous = managedContext.getPreviousQuestion() {
        print("上一条: \(previous.content)")
    }

    // 获取下一条
    if let next = managedContext.getNextQuestion() {
        print("下一条: \(next.content)")
    }

    // 获取所有问题
    let allQuestions = managedContext.getAllQuestions()
    print("共有 \(allQuestions.count) 条消息")
}
