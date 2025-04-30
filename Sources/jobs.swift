//
//  event.swift
//  simulate
//
//  Created by Bing-Chang Lai on 4/27/25.
//

import Foundation
import Logging


class Worker {
  var id: Int
  var queue: JobQueue
  var idle: Bool = true
  var alive: Bool = true

  init(id: Int, queue: JobQueue) {
    self.id = id
    self.queue = queue
  }
  
  func perform(_ events: EventQueue, at: Date) {
    if self.idle && self.alive {
      if let job = self.queue.dequeue() {
        eventLog.trace("JobStartedEvent", metadata: [
          "at": "\(at)",
          "job_id": "\(job.id)",
          "worker_id": "\(self.id)"
        ])
        self.idle = false
        events.enqueue(JobCompletedEvent(job: job, worker_id: self.id, at: at.addingTimeInterval(job.latency)))
      }
    }
  }
}

class JobQueue {
  var jobs: [Job] = []

  var count: Int {
    return jobs.count
  }

  func enqueue(_ job: Job) {
    jobs.append(job)
  }

  func dequeue() -> Job? {
    if jobs.isEmpty {
      return nil
    }
    return jobs.removeFirst()
  }

  func latency() -> TimeInterval {
    jobs.reduce(0) { $0 + $1.latency }
  }
}

class Job : CustomStringConvertible, Decodable {
  var id: Int
  var queue: String
  var enqueuedAt: Date
  var latency: TimeInterval

  init(id: Int, queue: String = "default", enqueuedAt: Date, latency: TimeInterval = 0) {
    self.id = id
    self.queue = queue
    self.enqueuedAt = enqueuedAt
    self.latency = latency
  }

  var description: String {
    return "Job \(id) on queue \(queue)"
  }
}
