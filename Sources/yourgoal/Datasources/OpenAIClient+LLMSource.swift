//
//  File.swift
//  
//
//  Created by PJ Gray on 4/16/23.
//

import Foundation

extension OpenAIClient: LLMSource {
    func getCompletion(withPrompt prompt: String) async -> String {
        return await self.getCompletion(withPrompt: prompt, temperature: 0.5, maxTokens: 500)
    }
}
