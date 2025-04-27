//
//  event.swift
//  simulate
//
//  Created by Bing-Chang Lai on 4/27/25.
//

import Foundation

class EventQueue {
  var events: [Event] = []

  func enqueue(_ event: Event) {
    if let i = events.firstIndex(where: { $0.at > event.at }) {
      events.insert(event, at: i)
    } else {
      events.append(event)
    }
  }

  func dequeue() -> Event? {
    if events.isEmpty {
      return nil
    }
    return events.removeFirst()
  }
}

class Event {
  var at: Date

  init(at: Date = Date()) {
    self.at = at
  }

  func perform(_ events: EventQueue) {}
}

class JobEnqueued: Event {
  var job: Job
  var to: JobQueue

  init(job: Job, to: JobQueue, at: Date = Date()) {
    self.job = job
    self.to = to
    super.init(at: at)
  }

  override func perform(_ events: EventQueue) {
    print("Enqueueing job \(self.job) at \(at)")
    to.enqueue(self.job)
  }
}

class JobCompleted: Event {
  var worker: Worker

  init(worker: Worker, at: Date = Date()) {
    self.worker = worker
    super.init(at: at)
  }

  override func perform(_ events: EventQueue) {
    print("Worker finished a job at \(at)")
    worker.jobCompleted(at: self.at)
  }
}
