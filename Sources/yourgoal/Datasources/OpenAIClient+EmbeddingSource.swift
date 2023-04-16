//
//  File.swift
//  
//
//  Created by PJ Gray on 4/16/23.
//

import Foundation

extension OpenAIClient: EmbeddingSource {
    func getEmbedding(withText text: String) async -> [Float] {
        let singleLineText = text.replacingOccurrences(of: "\n", with: " ")
        do {
            let response = try await self.openAIClient?.embeddings.create(input: singleLineText)
            return response?.data.first?.embedding ?? []
        } catch let error {
            print(error)
        }
        return []
    }
}
