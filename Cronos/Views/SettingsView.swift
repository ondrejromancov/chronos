import SwiftUI

enum Shell: String, CaseIterable {
    case zsh = "/bin/zsh"
    case bash = "/bin/bash"
    case fish = "/opt/homebrew/bin/fish"
    case sh = "/bin/sh"

    var displayName: String {
        switch self {
        case .zsh: return "Zsh"
        case .bash: return "Bash"
        case .fish: return "Fish"
        case .sh: return "sh"
        }
    }
}

struct SettingsView: View {
    @AppStorage("launchAtLogin") private var launchAtLogin = true
    @AppStorage("shell") private var shell = Shell.zsh.rawValue

    var body: some View {
        Form {
            Section("General") {
                Toggle("Launch at Login", isOn: $launchAtLogin)
                    .onChange(of: launchAtLogin) { _, newValue in
                        LaunchAtLogin.setEnabled(newValue)
                    }
            }

            Section("Execution") {
                Picker("Shell", selection: $shell) {
                    ForEach(Shell.allCases, id: \.self) { shellOption in
                        Text(shellOption.displayName).tag(shellOption.rawValue)
                    }
                }
            }

            Section("Storage") {
                LabeledContent("Jobs file") {
                    Text("~/.cronos/jobs.json")
                        .font(.system(.caption, design: .monospaced))
                        .foregroundStyle(.secondary)
                        .textSelection(.enabled)
                }

                LabeledContent("Logs directory") {
                    Text("~/.cronos/logs/")
                        .font(.system(.caption, design: .monospaced))
                        .foregroundStyle(.secondary)
                        .textSelection(.enabled)
                }

                Button("Open in Finder") {
                    let url = FileManager.default.homeDirectoryForCurrentUser
                        .appendingPathComponent(".cronos")
                    NSWorkspace.shared.open(url)
                }
            }

            Section("About") {
                LabeledContent("Version") {
                    Text("1.0.0")
                        .foregroundStyle(.secondary)
                }
            }
        }
        .formStyle(.grouped)
        .scrollDisabled(true)
        .frame(width: 380)
        .fixedSize(horizontal: false, vertical: true)
        .onAppear {
            // Sync with actual state on appear
            launchAtLogin = LaunchAtLogin.isEnabled
        }
    }
}
