//
//  File.swift
//  
//
//  Created by PJ Gray on 4/16/23.
//

import Foundation

protocol LLMSource {
    func getCompletion(withSystemMessage systemMessage: String, userMessage: String) async -> String
}
