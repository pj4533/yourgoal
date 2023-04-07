//
//  String+Colors.swift
//  
//
//  Created by PJ Gray on 4/7/23.
//

import Foundation

extension String {
    var magenta: String { return "\u{001B}[95m\u{001B}[1m\(self)\u{001B}[0m\u{001B}[0m" }
    var green: String { return "\u{001B}[92m\u{001B}[1m\(self)\u{001B}[0m\u{001B}[0m" }
    var yellow: String { return "\u{001B}[93m\u{001B}[1m\(self)\u{001B}[0m\u{001B}[0m" }
    var lightBlue: String { return "\u{001B}[96m\u{001B}[1m\(self)\u{001B}[0m\u{001B}[0m" }
    var red: String { return "\u{001B}[91m\u{001B}[1m\(self)\u{001B}[0m\u{001B}[0m" }
    var brightWhite: String { return "\u{001B}[97m\u{001B}[1m\(self)\u{001B}[0m\u{001B}[0m" }
}
