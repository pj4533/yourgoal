//
//  PineconeVectorDatabase.swift
//  
//
//  Created by PJ Gray on 4/16/23.
//

import Foundation

class PineconeVectorDatabase: VectorDatabase {
    private let pineconeAPIKey: String
    private let pineconeBaseURL: String
    private let namespace: String

    init(apiKey: String, baseURL: String, namespace: String) {
        self.pineconeAPIKey = apiKey
        self.pineconeBaseURL = baseURL
        self.namespace = namespace
    }

    func upsert(vector: Vector) async {
        struct PineconeUpsert: Codable {
            var vectors: [Vector]
            var namespace: String
        }
        
        struct ResponseData: Codable {
            let result: String
        }
        
        let upsert = PineconeUpsert(vectors: [vector], namespace: self.namespace)
        do {
            if let url = URL(string: "https://\(pineconeBaseURL)/vectors/upsert") {
                var request = URLRequest(url: url)
                request.httpMethod = "POST"
                request.setValue("application/json", forHTTPHeaderField: "Content-Type")
                request.setValue("application/json", forHTTPHeaderField: "accept")
                request.setValue(self.pineconeAPIKey, forHTTPHeaderField: "Api-Key")

                let encoder = JSONEncoder()
                let jsonData = try encoder.encode(upsert)
                request.httpBody = jsonData
                
                let (_, _) = try await URLSession.shared.data(for: request)
            }
        } catch let error {
            print("ERROR: \(error)")
        }
    }
    
    func query(embedding: Embedding, includeResults: Bool) async -> String {
        struct PineconeQuery: Codable {
            var vector: Embedding
            var includeMetadata: Bool
            var topK: Int
            var namespace: String
        }
                
        struct ResponseData: Codable {
            let matches: [VectorMatch]
        }
        
        let query = PineconeQuery(vector: embedding, includeMetadata: true, topK: 5, namespace: self.namespace)
        do {
            if let url = URL(string: "https://\(self.pineconeBaseURL)/query") {
                var request = URLRequest(url: url)
                request.httpMethod = "POST"
                request.setValue("application/json", forHTTPHeaderField: "Content-Type")
                request.setValue("application/json", forHTTPHeaderField: "accept")
                request.setValue(self.pineconeAPIKey, forHTTPHeaderField: "Api-Key")

                let encoder = JSONEncoder()
                let jsonData = try encoder.encode(query)
                request.httpBody = jsonData
                
                let (data, _) = try await URLSession.shared.data(for: request)
                
                let decoder = JSONDecoder()
                let responseData = try decoder.decode(ResponseData.self, from: data)
                let sortedMatches = responseData.matches.sorted { match1, match2 in
                    return match1.score > match2.score
                }
                DebugLog.shared.log("\n*****MATCHES*****\n")
                for match in responseData.matches {
                    DebugLog.shared.log("\(match.score): \(match.metadata.taskName)")
                }
                if includeResults {
                    return sortedMatches.map({ "\n-----\n* TASK: \($0.metadata.taskName)\n* TASK RESULT: \($0.metadata.result)\n-----\n" }).joined()
                } else {
                    return "COMPLETED TASKS:\n\(sortedMatches.map({ "* \($0.metadata.taskName)\n" }).joined())"
                }
            }
        } catch let error {
            print("ERROR: \(error)")
        }
        return ""
    }
    
}
