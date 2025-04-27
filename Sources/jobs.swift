//
//  event.swift
//  simulate
//
//  Created by Bing-Chang Lai on 4/27/25.
//

import Foundation

class Worker {
  var queue: JobQueue
  var job: Job?
  var jobCount: Int = 0

  init(queue: JobQueue) {
    self.queue = queue
  }
  
  func perform(_ events: EventQueue, at: Date) {
    if self.job == nil {
      if let job = self.queue.dequeue() {
        print("Worker picked up \(job) at \(at)")
        self.job = job
        events.enqueue(JobCompleted(worker: self, at: at.addingTimeInterval(job.latency)))
      }
    }
  }

  func jobCompleted(at: Date) {
    self.jobCount += 1
    self.job = nil
  }

  var idle: Bool {
    return self.job == nil
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
  var latency: TimeInterval

  init(id: Int, queue: String = "default", latency: TimeInterval = 0) {
    self.id = id
    self.queue = queue
    self.latency = latency
  }

  var description: String {
    return "Job \(id) on queue \(queue)"
  }
}
