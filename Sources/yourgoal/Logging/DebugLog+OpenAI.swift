//
//  DebugLog+OpenAI.swift
//  
//
//  Created by PJ Gray on 4/16/23.
//

import Foundation
import OpenAIKit

extension DebugLog {
    func log(_ messages: [OpenAIKit.Chat.Message]) {
        guard debug else { return }
        for message in messages {
            switch message {
            case .assistant(let content):
                print("(ASSISTANT) \(content)".brightWhite)
            case .user(let content):
                print("(USER) \(content)".brightWhite)
            case .system(let content):
                print("(SYSTEM) \(content)".brightWhite)
            }
        }
    }

}
