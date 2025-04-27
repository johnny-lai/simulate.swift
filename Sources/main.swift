// The Swift Programming Language
// https://docs.swift.org/swift-book

import Foundation

class Event {
  var at: Date

  init(at: Date = Date()) {
    self.at = at
  }

  func perform() {}
}

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

class EnqueueJob: Event {
  var job: Job
  var to: JobQueue

  init(job: Job, to: JobQueue, at: Date = Date()) {
    self.job = job
    self.to = to
    super.init(at: at)
  }

  override func perform() {
    print("Enqueueing job \(job) at \(at)")
    to.enqueue(self.job)
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

class Job : CustomStringConvertible {
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


var jobQueue = JobQueue()
var eventQueue = EventQueue()

let start = Date()
eventQueue.enqueue(EnqueueJob(job: Job(id: 1), to: jobQueue, at: start.addingTimeInterval(10)))
eventQueue.enqueue(EnqueueJob(job: Job(id: 2), to: jobQueue))


print("Starting simulation")
while let event = eventQueue.dequeue() {
  event.perform()
}
print("Simulation ended: \(jobQueue.count)")
