//
//  EmbeddingStore.swift
//  
//
//  Created by PJ Gray on 4/16/23.
//

import Foundation

protocol EmbeddingSource {
    func getEmbedding(withText text: String) async -> [Float]
}
