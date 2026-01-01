import Foundation

actor JobRunner {
    /// Runs a bash command and captures output to files
    /// Returns true if exit code was 0
    func run(
        command: String,
        workingDirectory: String,
        stdoutFile: URL,
        stderrFile: URL
    ) async throws -> Bool {
        // Ensure log files exist
        let fileManager = FileManager.default
        fileManager.createFile(atPath: stdoutFile.path, contents: nil)
        fileManager.createFile(atPath: stderrFile.path, contents: nil)

        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/bin/bash")
        process.arguments = ["-c", command]

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

        // Write output to files as it arrives
        stdoutPipe.fileHandleForReading.readabilityHandler = { handle in
            let data = handle.availableData
            if !data.isEmpty {
                try? stdoutHandle.write(contentsOf: data)
            }
        }

        stderrPipe.fileHandleForReading.readabilityHandler = { handle in
            let data = handle.availableData
            if !data.isEmpty {
                try? stderrHandle.write(contentsOf: data)
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
                }
                if !remainingStderr.isEmpty {
                    try? stderrHandle.write(contentsOf: remainingStderr)
                }

                try? stdoutHandle.close()
                try? stderrHandle.close()

                continuation.resume(returning: process.terminationStatus == 0)
            }
        }
    }
}
