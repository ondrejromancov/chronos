import Foundation

actor JobRunner {
    /// Runs a shell command and captures output to files
    /// Returns true if exit code was 0
    /// - Parameters:
    ///   - command: The shell command to run
    ///   - workingDirectory: Directory to run the command in
    ///   - shell: Path to the shell executable (e.g., /bin/zsh, /bin/bash)
    ///   - stdoutFile: File to write stdout to
    ///   - stderrFile: File to write stderr to
    ///   - onStdout: Optional callback for streaming stdout (called with new text as it arrives)
    ///   - onStderr: Optional callback for streaming stderr (called with new text as it arrives)
    func run(
        command: String,
        workingDirectory: String,
        shell: String,
        stdoutFile: URL,
        stderrFile: URL,
        onStdout: (@Sendable (String) -> Void)? = nil,
        onStderr: (@Sendable (String) -> Void)? = nil
    ) async throws -> Bool {
        // Ensure log files exist
        let fileManager = FileManager.default
        fileManager.createFile(atPath: stdoutFile.path, contents: nil)
        fileManager.createFile(atPath: stderrFile.path, contents: nil)

        // Sanitize smart quotes to straight quotes
        let sanitizedCommand = command
            .replacingOccurrences(of: "\u{201C}", with: "\"")  // " left double
            .replacingOccurrences(of: "\u{201D}", with: "\"")  // " right double
            .replacingOccurrences(of: "\u{2018}", with: "'")   // ' left single
            .replacingOccurrences(of: "\u{2019}", with: "'")   // ' right single

        let process = Process()
        process.executableURL = URL(fileURLWithPath: shell)
        process.arguments = ["-l", "-i", "-c", sanitizedCommand]

        // Expand ~ in working directory
        let expandedPath = (workingDirectory as NSString).expandingTildeInPath
        process.currentDirectoryURL = URL(fileURLWithPath: expandedPath)

        // Set up pipes for output capture
        let stdoutPipe = Pipe()
        let stderrPipe = Pipe()
        process.standardOutput = stdoutPipe
        process.standardError = stderrPipe

        // Open file handles for writing
        let stdoutHandle = try FileHandle(forWritingTo: stdoutFile)
        let stderrHandle = try FileHandle(forWritingTo: stderrFile)

        // Write output to files as it arrives and notify callbacks
        stdoutPipe.fileHandleForReading.readabilityHandler = { handle in
            let data = handle.availableData
            if !data.isEmpty {
                try? stdoutHandle.write(contentsOf: data)
                if let text = String(data: data, encoding: .utf8) {
                    onStdout?(text)
                }
            }
        }

        stderrPipe.fileHandleForReading.readabilityHandler = { handle in
            let data = handle.availableData
            if !data.isEmpty {
                try? stderrHandle.write(contentsOf: data)
                if let text = String(data: data, encoding: .utf8) {
                    onStderr?(text)
                }
            }
        }

        try process.run()

        // Wait for process in background
        return await withCheckedContinuation { continuation in
            DispatchQueue.global().async {
                process.waitUntilExit()

                // Clean up handlers
                stdoutPipe.fileHandleForReading.readabilityHandler = nil
                stderrPipe.fileHandleForReading.readabilityHandler = nil

                // Read any remaining data
                let remainingStdout = stdoutPipe.fileHandleForReading.readDataToEndOfFile()
                let remainingStderr = stderrPipe.fileHandleForReading.readDataToEndOfFile()

                if !remainingStdout.isEmpty {
                    try? stdoutHandle.write(contentsOf: remainingStdout)
                    if let text = String(data: remainingStdout, encoding: .utf8) {
                        onStdout?(text)
                    }
                }
                if !remainingStderr.isEmpty {
                    try? stderrHandle.write(contentsOf: remainingStderr)
                    if let text = String(data: remainingStderr, encoding: .utf8) {
                        onStderr?(text)
                    }
                }

                try? stdoutHandle.close()
                try? stderrHandle.close()

                continuation.resume(returning: process.terminationStatus == 0)
            }
        }
    }
}
