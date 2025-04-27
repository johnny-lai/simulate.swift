// The Swift Programming Language
// https://docs.swift.org/swift-book

import Foundation

class Event {
  var at: Date

  init(at: Date = Date()) {
    self.at = at
  }

  func perform(_ events: EventQueue) {}
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
        events.enqueue(JobCompleted(worker: self, at: at.addingTimeInterval(job.latency)))
      }
    }
  }

  func jobCompleted(at: Date) {
    self.jobCount += 1
    self.job = nil
  }
}


var eventQueue = EventQueue()
var jobQueue = JobQueue()
var w = Worker(queue: jobQueue)

let start = Date()
eventQueue.enqueue(JobEnqueued(job: Job(id: 1, latency: 2), to: jobQueue, at: start.addingTimeInterval(10)))
eventQueue.enqueue(JobEnqueued(job: Job(id: 2, latency: 12), to: jobQueue))


print("Starting simulation")
while let event = eventQueue.dequeue() {
  let at = event.at
  event.perform(eventQueue)
  w.perform(eventQueue, at: at)
}
print("Simulation ended: \(jobQueue.count) \(w.jobCount)")
