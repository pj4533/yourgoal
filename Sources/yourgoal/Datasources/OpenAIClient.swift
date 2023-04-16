//
//  OpenAIEmbeddingStore.swift
//  
//
//  Created by PJ Gray on 4/16/23.
//

import Foundation
import OpenAIKit
import AsyncHTTPClient

class OpenAIClient {
    private static var _shared: OpenAIClient?
    private let apiKey: String
    private let organization: String
    internal var openAIClient: OpenAIKit.Client?
    private let httpClient = HTTPClient(eventLoopGroupProvider: .createNew)
    
    private init(apiKey: String, organization: String) {
        self.apiKey = apiKey
        self.organization = organization
        
        let configuration = Configuration(apiKey: apiKey, organization: organization)
        self.openAIClient = OpenAIKit.Client(httpClient: self.httpClient, configuration: configuration)
    }
    
    static var shared: OpenAIClient {
        guard let instance = _shared else {
            fatalError("Must be initialized before use")
        }
        return instance
    }
    
    static func initialize(apiKey: String, organization: String) {
        guard _shared == nil else {
            print("Already initialized")
            return
        }
        _shared = OpenAIClient(apiKey: apiKey, organization: organization)
    }
        
    internal func getCompletion(withPrompt prompt: String, temperature: Double, maxTokens: Int) async -> String {
        let messages: [OpenAIKit.Chat.Message] = [
            .system(content: prompt)
        ]
        DebugLog.shared.log(messages)
        var assisantResponse = ""
        do {
            let completion = try await openAIClient?.chats.create(
                model: Model.GPT3.gpt3_5Turbo,
                messages: messages,
                temperature: temperature,
                maxTokens: maxTokens
            )
            switch completion?.choices.first?.message {
            case .assistant(let content):
                assisantResponse = content
            case .user(let content):
                print("ERROR: got user response: \(content)")
            case .system(let content):
                print("ERROR: got system response: \(content)")
            case .none:
                print("ERROR: got no response")
            }
        } catch let error {
            print(error)
        }
        return assisantResponse
    }
}

