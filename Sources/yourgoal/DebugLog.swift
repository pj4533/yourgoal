//
//  DebugLog.swift
//  
//
//  Created by PJ Gray on 4/16/23.
//

import Foundation

class DebugLog {
    static let shared = DebugLog()
    var debug: Bool

    private init() {
        debug = false
    }

    func log(_ message: String) {
        guard debug else { return }
        print("\(message)".brightWhite)
    }
}
