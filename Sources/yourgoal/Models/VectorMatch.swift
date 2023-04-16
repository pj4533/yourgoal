//
//  VectorMatch.swift
//  
//
//  Created by PJ Gray on 4/16/23.
//

import Foundation

struct VectorMatch: Codable {
    var id: String
    var score: Float
    var metadata: VectorMetadata
}
