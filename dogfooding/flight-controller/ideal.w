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

  public inflight get_available_capacity(): num {
    let current = this._counter.peek();
    if current >= this.limit {
      return 0;
    }
    return this.limit - current;
  }
}

struct FlightControllerProps {
  runway_limit: num;
  max_runway_occupation_per_flight: duration;
}

resource FlightController {
  public runway_limit: num;
  _scheduled_flights: cloud.Queue;

  init(on_runway_available: inflight (str): str, props: FlightControllerProps) {
    let runway = new CountingSemaphore(CountingSemaphoreProps { available_resources: this.runway_limit });
    this.runway_limit = runway.limit;
    this._scheduled_flights = new cloud.Queue();
    let availability_checker = new cloud.Schedule(cloud.ScheduleProps { rate: props.max_runway_occupation_per_flight });
    let availability_signal = new cloud.Topic();

    let send_next_flight = inflight () => {
      if runway.is_at_capacity() {
        return;
      }

      if let flight = this._scheduled_flights.pop() {
        let is_runway_acquired = runway.try_acquire();
        log("is runway acquired: ${is_runway_acquired}");
        if !is_runway_acquired {
          // brutally error out to re-enqueue
          throw("Failed to acquire runway");
        }

        // real work
        log("runway is acquired, go flight: ${Json.stringify(flight)}");
        try {
          let leftover_to_scheduled_flights = on_runway_available(flight);
          if (leftover_to_scheduled_flights != "") {
            this._scheduled_flights.push(leftover_to_scheduled_flights);
          }
        } finally {
          runway.release();
          if !runway.is_at_capacity() {
            availability_signal.publish("runway may be available");
          }
        }
      }
    };

    let saturate_runway = inflight () => {
      let var available_capacity = runway.get_available_capacity();
      while available_capacity > 0 {
        defer send_next_flight();
        available_capacity = available_capacity - 1;
      }
    };

    // event-based, so that runway can be used immediately if there are more flights scheduled
    availability_signal.on_message(inflight (message: str) => {
      send_next_flight();
    }, cloud.TopicOnMessageProps { timeout: props.max_runway_occupation_per_flight }); // FIXME: TopicOnMessageProps should extends FunctionProps: https://github.com/winglang/wing/issues/2218

    // time-based, so that new flights can use runway if previously scheduled flights are all done when signaling available
    availability_checker.on_tick(saturate_runway, cloud.ScheduleOnTickProps { timeout: props.max_runway_occupation_per_flight });
  }

  public inflight schedule_flight(message: str) {
    this._scheduled_flights.push(message);
  }
}

struct MyFlightPlan {
  start_id: num;
}

let flight_controller = new FlightController(inflight (message: str): str => {
  log("received: ${Json.stringify(message)}");
  let plan = MyFlightPlan.from_json(Json.parse(message));
  let var i = plan.start_id;
  let step = 2500000;
  let ratio = 10;
  let target = i + ratio * step;
  while i <= target {
    if i == (i \ step * step) {
        log("${i}/${target}");
    }
    i = i + 1;
  }
  let next_plan = MyFlightPlan { start_id: target + 1 };
  return Json.stringify(next_plan);
}, FlightControllerProps {
  runway_limit: 2,
  max_runway_occupation_per_flight: 5m,
}) as "flight controller";

new cloud.Function(inflight (s: str): str => {
    let var task_id = 0;
    while task_id < 3 {
      flight_controller.schedule_flight("${s} - ${task_id}");
        task_id = task_id + 1;
    }
}) as "flights generator";