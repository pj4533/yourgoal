//
//  File.swift
//  
//
//  Created by PJ Gray on 4/16/23.
//

import Foundation

protocol LLMSource {
    func getCompletion(withPrompt prompt: String) async -> String
}
