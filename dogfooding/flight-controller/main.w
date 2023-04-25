bring cloud;

struct CountingSemaphoreProps {
  available_resources: num;
}

resource CountingSemaphore {
  public limit: num;
  _counter: cloud.Counter;

  init(props: CountingSemaphoreProps) {
    // pseudocode: input validation
    this.limit = props.available_resources;
    this._counter = new cloud.Counter();
  }

  public inflight try_acquire(): bool {
    if this.is_at_capacity() {
      return false;
    }

    let post_acquired_capacity = this._counter.inc();
    if post_acquired_capacity < this.limit {
      return true;
    }
    this.release();
    return false;
  }

  public inflight release() {
    if this._counter.peek() <= 0 {
      return;
    }

    this._counter.dec();
  }

  public inflight is_at_capacity(): bool {
    return this._counter.peek() >= this.limit;
  }
}

resource FlightController {
  public runway_limit: num;
  _queue: cloud.Queue;

  init(runway_limit: num, on_runway_available: cloud.Function, max_runway_occupation_per_flight: duration?) {
    this.runway_limit = runway_limit;
    let counting_semaphore = new CountingSemaphore(available_resources: this.runway_limit) as "runway in-use";
    let max_duration = max_runway_occupation_per_flight ?? 5s;

    this._queue = new cloud.Queue(timeout: max_duration) as "scheduled flights";
    this._queue.add_consumer(inflight (message: str) => {
      let is_resource_acquired = counting_semaphore.try_acquire();
      log("for ${Json.stringify(message)} is runway acquired: ${is_resource_acquired}");
      if !is_resource_acquired {
        // brutally error out to re-enqueue
        throw("${Json.stringify(message)} failed to acquire runway, rescheduling");
      }

      // real work
      log("runway is acquired, go flight: ${Json.stringify(message)}");
      try {
        on_runway_available.invoke(message);
      } finally {
        counting_semaphore.release();
      }
    }, timeout: max_duration);
  }

  public inflight schedule_flight(message: str) {
    this._queue.push(message);
  }
}

let flight_controller = new FlightController(
    1,
    new cloud.Function(inflight (message: str) => {
      log("runway clear for: ${Json.stringify(message)}");
    }) as "flight action",
) as "flight controller";

new cloud.Function(inflight (s: str): str => {
    let var flight_id = 0;
    while flight_id < 3 {
      flight_controller.schedule_flight("flight - ${flight_id}");
        flight_id = flight_id + 1;
    }
}) as "test: flights generator";