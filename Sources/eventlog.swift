//
//  eventlog.swift
//  simulate
//
//  Created by Bing-Chang Lai on 4/27/25.
//

import Foundation
import SigmaSwiftStatistics

struct JobLogEntry {
  var jobId: Int
  var workerId: Int
  var enqueuedAt: Date
  var startedAt: Date
  var completedAt: Date

  var pickup: TimeInterval {
    startedAt.timeIntervalSince(enqueuedAt)
  }

  var latency: TimeInterval {
    completedAt.timeIntervalSince(startedAt)
  }
}

class EventLog {
  var entries: [JobLogEntry] = []

  func append(_ entry: JobLogEntry) {
    self.entries.append(entry)
  }

  func pickups(since: Date) -> [Double] {
    entries.filter({ $0.completedAt >= since })
      .map({ $0.pickup })
  }

  func latencies(since: Date) -> [Double] {
    entries.filter({ $0.completedAt >= since })
      .map({ $0.latency })
  }
}
