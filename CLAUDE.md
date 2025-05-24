# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Build and Run Commands

```bash
# Build the project
swift build

# Run with sample data
swift run simulate --input Samples/jobs.csv

# Run with custom parameters
swift run simulate --input Samples/jobs.csv --target 180 --workers 5 --max-pods 10

# Run with different algorithm
swift run simulate --input Samples/jobs.csv --algorithm average5

# Enable verbose logging
swift run simulate --input Samples/jobs.csv --verbose
```

## Architecture

This is a **discrete event simulation** system for modeling job pickup performance in an autoscaling environment. The simulation models workers organized into pods that process jobs from a queue.

### Core Components

- **Event-Driven Architecture**: `EventQueue` processes events chronologically (`JobEnqueuedEvent`, `JobCompletedEvent`, `AutoScaleEvent`, `AddPodEvent`, `RemovePodEvent`)
- **Job Processing**: `Worker` instances process `Job`s from a `JobQueue`, with jobs having configurable latency and pickup times
- **Autoscaling Logic**: Scaling decisions based on queue length estimates using pluggable `Algorithm` implementations
- **Historical Analysis**: `EventLog` tracks job completion metrics for algorithm input and final reporting

### Key Files

- `main.swift`: CLI argument parsing and simulation setup
- `simulation.swift`: Core `Simulation` class orchestrating the event loop and autoscaling
- `events.swift`: Event system and worker/queue implementations  
- `algorithm.swift`: Scaling algorithms (`PercentileAlgorithm`, `AverageAlgorithm`)
- `jobs.swift`: Job and worker models
- `eventlog.swift`: Performance tracking and metrics

### Algorithms

The simulation supports multiple autoscaling algorithms:
- `percentile90_5`: 90th percentile with 5-minute lookback (default)
- `percentile90_30`: 90th percentile with 30-minute lookback  
- `average5`: Average latency with 5-minute lookback

### Output Files

The simulation generates CSV files during execution:
- `kpis.csv`: Key performance indicators over time
- `queueLengths.csv`: Queue and worker state over time
- Console output includes final summary statistics

### Input Format

Expects CSV input with columns: `id`, `timestamp`, `latency`, `pickup`