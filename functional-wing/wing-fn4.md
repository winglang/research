Just fold `init()` into the class, keep props as-is:

```js
bring cloud;

struct TaskListProps {
  // ...
}

/** represents a cloud task list */
class TaskList(subject: str?, props: TaskListProps?) extends Base {
  let bucket: cloud.Bucket;
  let counter: cloud.Counter;

  /** returns the number of tasks in the task list */
  public inflight task_count(): num {
    return bucket.list().len;
  }

  struct Task {
    id: str;
    title: str;
    effort: num?;
  }

  /** 
   * adds a task to the task list.
   * @returns the ID of the new task.
   */
  public inflight add_task(title: str): str {
    let t = Task { 
      id: "${counter.inc()}",
      title: title,
    };

    let j = t.to_json();
    print("adding task ${id} with data: ${j}"); //j should be printed out nicely 
    bucket.put_json(id, j);
    return id;
  }

  /** 
   * gets a task from the task list.
   * @param id - the id of the task to return
   * @returns the title of the task (optimistic)
   */
  public inflight get_task(id: str): Json {
    let t = Task.from_json(bucket.get_json(id));
    return t.id;
  }

  let in multiplier ?= 1;

  /** 
   * sets effort estimation on a test
   * @param id - the id of the task to return
   * @param effort_estimation - the time (duration) estimated for this task
   * @returns The ID of the existing task.
   */
  public inflight add_estimation(id: str): str {
    in effort_estimation: duration;

    let t = get_task(id);
    let new_t = Task(
      id: t.id, 
      title: t.title, 
      effort: effort_estimation
    );

    bucket.put_json(id, new_t.to_json());
    return id;
  }

  /** 
   * removes a task from the list
   * @param id - the id of the task to be removed
   * @returns the removed task id
   */
  public inflight remove_tasks(id: str): str {
    print("removing task ${id}");
    bucket.delete(id);
    return id;
  }

  let ttl = 1m;
  let inflight task_ids = MutSet<str> {};
  let inflight var last_update: datetime?;

  /* gets the tasks ids */
  public inflight list_task_ids(): Set<str> {
    let lu = last_update ?? datetime.epoch;
    if datetime.utc_now().minus(lu) > 1m {
      for id in bucket.list() {
        task_ids.add(id);
      }
      last_update = datetime.utc_now();
    }
    
    return task_ids;
  }

  /** 
   * find tasks with title that contains a term
   * @returns set of task id that matches the term
   */
  public inflight find_tasks_with(): Array<str> {
    /** the term to search */
    let in term: str;

    print("find_tasks_with: ${term}");
    let task_ids = this.list_task_ids();
    print("found ${task_ids.size} tasks");
    let output = MutArray<str>[];
    for id in task_ids {
      let j = this.get_task(id); 
      let title = str.from_json(j.get("title"));
      if title.contains(term) { 
        print("found task ${id} with title \"${title}\" with term \"${term}\"");
        output.push(id);
      }
    }
    
    print("found ${output.len} tasks which match term '${term}'");
    return output.copy();
  }
}

let SpecialTaskList: ITaskList... = () => {
  let prefix = "I am so special!"
  let super = TaskList(prefix: prefix);
  let out = ...super;
  let out find_tasks_with = (s: str) => super.find_tasks_with(prefix + s);
};

let s = SpecialTaskList();

let tl = TaskList();
print(tl.task_count);
```
