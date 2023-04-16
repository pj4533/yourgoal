//
//  VectorDatabase.swift
//  
//
//  Created by PJ Gray on 4/16/23.
//

import Foundation

protocol VectorDatabase {
    func upsert(vector: Vector) async
    func query(embedding: Embedding, includeResults: Bool) async -> String
}
