//
//  File.swift
//  
//
//  Created by PJ Gray on 4/16/23.
//

import Foundation

extension GPT4AllClient: LLMSource {
    func getCompletion(withPrompt prompt: String) async throws -> String {
        return try await self.prompt(prompt)
    }
}
