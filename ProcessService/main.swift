//
//  main.swift
//  ProcessService
//
//  Created by Yaxin Cheng on 2020-06-01.
//  Copyright © 2020 Yaxin Cheng. All rights reserved.
//

import Cocoa

struct RunningApp: Encodable {
  let title: String
  let subtitle: String
  let id: String
}

func listRunningApps(name: String) -> [RunningApp] {
  var running = NSWorkspace.shared.runningApplications.filter { $0.activationPolicy == .regular }
  if !name.isEmpty {
    running = running.filter { $0.localizedName?.lowercased().contains(name) ?? true }
  }
  return running.map {
    RunningApp(title: "Quit \($0.localizedName ?? "UNKNOWN")",
               subtitle: $0.bundleURL?.path ?? "UNKNOWN",
               id: String($0.processIdentifier))
  }
}

func quit(pid: pid_t, force: Bool) {
  guard let runningApp = NSRunningApplication(processIdentifier: pid) else { return }
  if force {
    runningApp.forceTerminate()
  } else {
    runningApp.terminate()
  }
}

struct Response<S: Encodable>: Encodable {
  let provider: String
  let services: [S]
}

func write<S: Encodable>(response: Response<S>, to output: String) throws {
  let encoder = JSONEncoder()
  let json = try encoder.encode(response)
  let outputFile = try FileHandle(forWritingTo: URL(fileURLWithPath: output))
  outputFile.write(json)
}

private let OUTPUT_ENV_KEY = "OUTPUT"
private let IDENTIFIER_ENV_KEY = "IDENTIFIER"

func help() -> Never {
  print("""
  Process Manager

  Parameters:
  -q, --query <query>       query for running applications
  -x, --execute <id>        quit application with given pid
  -X, --alter-execute <id>  force kill application with given pid
  """)
  exit(0)
}

let arguments = CommandLine.arguments.map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
print(arguments)
if arguments.count > 3 || arguments.count <= 1 {
  help()
}

if arguments[1] == "-q" || arguments[1] == "--query" {
  let output = ProcessInfo.processInfo.environment[OUTPUT_ENV_KEY]!
  let identifier = ProcessInfo.processInfo.environment[IDENTIFIER_ENV_KEY]!
  let runningApps: [RunningApp]
  if arguments.count == 2 {
    runningApps = listRunningApps(name: "")
  } else {
    runningApps = listRunningApps(name: arguments[2].trimmingCharacters(in: .whitespacesAndNewlines))
  }
  let response = Response(provider: identifier, services: runningApps)
  try! write(response: response, to: output)
} else if arguments[1] == "-x" || arguments[1] == "--execute" {
  guard let pid = Int32(arguments[2]) else { exit(1) }
  quit(pid: pid, force: false)
} else if arguments[1] == "-X" || arguments[1] == "--alter-execute" {
  guard let pid = Int32(arguments[2]) else { exit(1) }
  quit(pid: pid, force: true)
} else {
  help()
}
