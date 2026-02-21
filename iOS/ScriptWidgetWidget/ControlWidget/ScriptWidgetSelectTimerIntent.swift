//
//  ScriptWidgetSelectTimerIntent.swift
//  ScriptWidget
//
//  Created by eevv on 11/5/24.
//

import Foundation
import AppIntents
import WidgetKit

struct ConfigurableProvider: AppIntentControlValueProvider {
    func previewValue(configuration: SelectTimerIntent) -> TimerState {
        TimerState(timer: configuration.timer ?? .init(id: 1, name: "Work Timer"), isRunning: false)
    }
    
    func currentValue(configuration: SelectTimerIntent) async throws -> TimerState {
        let timer = configuration.timer ?? .init(id: .init(), name: "Work Timer")
        let isRunning = try await TimerManager.shared.fetchTimerRunning(timer: timer)
        return TimerState(timer: timer, isRunning: isRunning)
    }
}
struct TimerState {
  let timer: Timer
  let isRunning: Bool
}
class TimerManager {
  static let shared = TimerManager()
  
  func fetchTimerRunning(timer: Timer) async throws -> Bool {
    // Logic to check if the given timer is currently running
    // Returns true if the timer is running, false otherwise
    false // Placeholder implementation
  }
  
  func setTimerRunning(_ isRunning: Bool) {
    // Logic to start or stop the timer based on the isRunning value
  }
}

struct TimerQuery: EntityQuery {
  func entities(for identifiers: [Timer.ID]) async throws -> [Timer] {
    let allTimers = [
      Timer(id: 1, name: "Work Timer"),
      Timer(id: 2, name: "Break Timer"),
      Timer(id: 3, name: "Exercise Timer"),
      Timer(id: 4, name: "Study Timer"),
      Timer(id: 5, name: "Meditation Timer")
    ]
    return identifiers.compactMap { id in allTimers.first(where: { $0.id == id }) }
  }
  
  func suggestedEntities() async throws -> [Timer] {
    try await entities(for: [1, 2, 3, 4, 5])
  }
}

struct Timer: Identifiable, AppEntity {
  static var defaultQuery = TimerQuery()
  static var typeDisplayRepresentation: TypeDisplayRepresentation = "Timer"
  let id: Int
  let name: String
  var displayRepresentation: DisplayRepresentation {
    DisplayRepresentation(title: "\(name)")
  }
}



struct SelectTimerIntent: ControlConfigurationIntent {
  static var title: LocalizedStringResource = "Select Timer"
  static var isDiscoverable: Bool { false }
  @Parameter(title: "Timer")
  var timer: Timer?
  
  init() {}
  init(_ timer: Timer?) {
    self.timer = timer
  }
  
  func perform() async throws -> some IntentResult {
    .result()
  }
}
struct ToggleTimerIntent: SetValueIntent {
  static let title: LocalizedStringResource = "Productivity Timer"
  static var isDiscoverable: Bool { false }
  @Parameter(title: "Running")
  var value: Bool
  @Parameter(title: "Timer")
  var timer: Timer
  
  init() {}
  init(timer: Timer) {
    self.timer = timer
  }
  
  func perform() throws -> some IntentResult {
    TimerManager.shared.setTimerRunning(value)
    return .result()
  }
}
