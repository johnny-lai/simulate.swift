// The Swift Programming Language
// https://docs.swift.org/swift-book

import Foundation

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
