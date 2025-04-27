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

  func perform(_ simulation: Simulation) {}
}

class JobEnqueued: Event {
  var job: Job
  var to: JobQueue

  init(job: Job, to: JobQueue, at: Date = Date()) {
    self.job = job
    self.to = to
    super.init(at: at)
  }

  override func perform(_ simulation: Simulation) {
    print("Enqueueing job \(self.job) at \(at)")
    to.enqueue(self.job)
  }
}

class JobCompleted: Event {
  var job: Job
  var worker_id: Int

  init(job: Job, worker_id: Int, at: Date = Date()) {
    self.job = job
    self.worker_id = worker_id
    super.init(at: at)
  }

  override func perform(_ simulation: Simulation) {
    simulation.recordJobCompletion(job, worker_id: worker_id, at: at)
    print("Worker finished a job at \(at)")
    if let w = simulation.workerWithId(self.worker_id) {
      w.idle = true
    }
  }
}
