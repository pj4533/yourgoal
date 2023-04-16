//
//  GPT4AllClient.swift
//  
//
//  Created by PJ Gray on 4/16/23.
//

import Foundation
import NIO

class GPT4AllClient {
    private static var _shared: GPT4AllClient?

    private var bot: Process?
    private let model: String
    private let executablePath: String
    private let modelPath: String

    static var shared: GPT4AllClient {
        guard let instance = _shared else {
            fatalError("Must be initialized before use")
        }
        return instance
    }
    
    static func initialize(model: String = "gpt4all-lora-quantized") async throws {
        guard _shared == nil else {
            print("Already initialized")
            return
        }
        _shared = try GPT4AllClient(model: model)
        try! await _shared?.open()
    }

    private init(model: String = "gpt4all-lora-quantized") throws {
        self.model = model

        if model != "gpt4all-lora-quantized" && model != "gpt4all-lora-unfiltered-quantized" {
            throw NSError(domain: "ModelNotSupported", code: 0, userInfo: [NSLocalizedDescriptionKey: "Model \(model) is not supported. Current models supported are: gpt4all-lora-quantized, gpt4all-lora-unfiltered-quantized"])
        }

        let homeDirectory = FileManager.default.homeDirectoryForCurrentUser
        executablePath = "\(homeDirectory.path)/.nomic/gpt4all"
        modelPath = "\(homeDirectory.path)/.nomic/\(model).bin"
    }

    func open() async throws {
        if bot != nil {
            close()
        }

        let spawnArgs = [executablePath, "--model", modelPath]
        let process = Process()
        let outputPipe = Pipe()
        let inputPipe = Pipe()
        process.executableURL = URL(fileURLWithPath: spawnArgs[0])
        process.arguments = Array(spawnArgs[1...])
        process.standardOutput = outputPipe
        process.standardInput = inputPipe
        try process.run()

        bot = process

        let ready = try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Bool, Error>) in
            outputPipe.fileHandleForReading.readabilityHandler = { fileHandle in
                let data = fileHandle.availableData
                let output = String(data: data, encoding: .utf8) ?? ""
                if output.contains(">") {
                    continuation.resume(returning: true)
                }
            }
        }
    }

    actor ResponseActor {
        private(set) var response: String = ""

        func append(_ text: String) {
            response += text
        }

        func removeLast() {
            if response.hasSuffix(">") {
                response.removeLast()
            }
        }
    }

    @MainActor
    func prompt(_ prompt: String) async throws -> String {
        guard let bot = bot else {
            throw NSError(domain: "BotNotInitialized", code: 1, userInfo: [NSLocalizedDescriptionKey: "Bot is not initialized."])
        }

        let inputData = Data(prompt.utf8)
        if let inputPipe = bot.standardInput as? Pipe {
            inputPipe.fileHandleForWriting.write(inputData)
        } else {
            throw NSError(domain: "StandardInputError", code: 2, userInfo: [NSLocalizedDescriptionKey: "Error occurred while writing to standard input."])
        }

        return try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<String, Error>) in
            let outputPipe = bot.standardOutput as! Pipe
            let responseActor = ResponseActor()

            let source = DispatchSource.makeReadSource(fileDescriptor: outputPipe.fileHandleForReading.fileDescriptor, queue: DispatchQueue.global())

            source.setEventHandler {
                let data = outputPipe.fileHandleForReading.availableData
                let text = String(data: data, encoding: .utf8) ?? ""
                Task {
                    await responseActor.append(text)

                    if text.contains(">") {
                        source.cancel()
                        terminateAndResolve()
                    }
                }
            }

            source.setCancelHandler {
                outputPipe.fileHandleForReading.closeFile()
            }

            source.resume()

            func terminateAndResolve() {
                Task {
                    await responseActor.removeLast()
                    let finalResponse = await responseActor.response
                    continuation.resume(returning: finalResponse)
                }
            }
        }
    }

    func close() {
        if let bot = bot {
            bot.terminate()
            self.bot = nil
        }
    }
}
