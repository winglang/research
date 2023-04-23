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
  _counting_semaphore: CountingSemaphore;
  _queue: cloud.Queue;

  init(runway_limit: num, on_runway_available: cloud.Function) {  // FIXME: walk around cannot use struct - the compiler is not able to capture permissions correctly: https://github.com/winglang/wing/issues/2217
    this.runway_limit = runway_limit;
    let counting_semaphore = new CountingSemaphore(CountingSemaphoreProps { available_resources: this.runway_limit });
    this._counting_semaphore = counting_semaphore;

    this._queue = new cloud.Queue();
    // TODO: walk around the yet to implement pop()
    this._queue.add_consumer(inflight (message: str) => {
      let is_resource_acquired = counting_semaphore.try_acquire(); // FIXME: walk around cannot use this.counting_semaphore - Unknown error: Unexpected keyword 'this': https://github.com/winglang/wing/issues/2215
      log("is runway acquired: ${is_resource_acquired}");
      if !is_resource_acquired {
        // brutally error out to re-enqueue
        throw("Failed to acquire runway");
      }

      // real work
      log("runway is acquired, go flight: ${Json.stringify(message)}");
      try {
        on_runway_available.invoke(message); // FIXME: walk around cannot call inflight function inside another: https://github.com/winglang/wing/issues/2216
      } finally {
        counting_semaphore.release();
      }
    });
  }

  public inflight schedule_flight(message: str) {
    this._queue.push(message);
  }
}

let flight_controller = new FlightController(
    1,
    new cloud.Function(inflight (message: str) => {
      log("received: ${Json.stringify(message)}");
      let var i = 0;
      let step = 2500000;
      let ratio = 10;
      let target = ratio * step;
      while i <= target {
        if i == (i \ step * step) {
            log("${i}/${target}");
        }
        i = i + 1;
      }
    })
) as "flight controller";

new cloud.Function(inflight (s: str): str => {
    let var task_id = 0;
    while task_id < 3 {
      flight_controller.schedule_flight("${s} - ${task_id}");
        task_id = task_id + 1;
    }
}) as "flights generator";