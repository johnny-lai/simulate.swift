//
//  event.swift
//  simulate
//
//  Created by Bing-Chang Lai on 4/27/25.
//

import Foundation

class Worker {
  var id: Int
  var queue: JobQueue
  var idle: Bool = true

  init(id: Int, queue: JobQueue) {
    self.id = id
    self.queue = queue
  }
  
  func perform(_ events: EventQueue, at: Date) {
    if self.idle {
      if let job = self.queue.dequeue() {
        print("Worker picked up \(job) at \(at)")
        self.idle = false
        events.enqueue(JobCompleted(job: job, worker_id: self.id, at: at.addingTimeInterval(job.latency)))
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
