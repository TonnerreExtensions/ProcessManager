//
//  main.swift
//  ProcessService
//
//  Created by Yaxin Cheng on 2020-06-01.
//  Copyright © 2020 Yaxin Cheng. All rights reserved.
//

import Cocoa
import ArgumentParser

struct RunningApp: Encodable {
  let title: String
  let subtitle: String
  let id: pid_t
}

func listRunningApps(name: String) -> [RunningApp] {
  var running = NSWorkspace.shared.runningApplications.filter { $0.activationPolicy == .regular }
  if !name.isEmpty {
    running = running.filter { $0.localizedName?.contains(name) ?? true }
  }
  return running.map {
    RunningApp(title: "Quit \($0.localizedName ?? "UNKNOWN")",
               subtitle: $0.bundleURL?.path ?? "UNKNOWN",
               id: $0.processIdentifier)
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

struct ProcessService: ParsableCommand {
  @Option(name: .shortAndLong, help: "The name filter for running applications")
  var query: String?
  @Option(name: [.customShort("x"), .customLong("execute")], help: "The pid of targeted process")
  var exitPid: Int32?
  @Option(name: [.customShort("X"), .customLong("alter_execute")], help: "The pid of targeted process")
  var killPid: Int32?
  
  func run() throws {
    if let request = query {
      let output = ProcessInfo.processInfo.environment[OUTPUT_ENV_KEY]!
      let identifier = ProcessInfo.processInfo.environment[IDENTIFIER_ENV_KEY]!
      let services = listRunningApps(name: request)
      let response = Response(provider: identifier, services: services)
      try write(response: response, to: output)
    } else if let pid = exitPid {
      quit(pid: pid, force: false)
    } else if let pid = killPid {
      quit(pid: pid, force: true)
    }
  }
}

ProcessService.main()
