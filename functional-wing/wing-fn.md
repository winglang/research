```js
bring cloud;

/** represents a cloud task list */
TaskList = () => {
  let bucket =? cloud.Bucket();
  let counter =? cloud.Counter();

  /** add prefix to all tasks */
  let in prefix =? "";

  /** max number of tasks */
  let in max =? 10;

  /** returns the number of tasks in the task list */
  let out task_count = (): num => bucket.list().len;

  let Task = () => {
    let var in out id =? "${counter.inc()}";
    let var in out title: str;
    let var in out effort?: num;
  };

  /** 
   * adds a task to the task list.
   * @returns the ID of the new task.
   */
  let out add_task = (): str => {
    let t = Task(title);
    let j = t.to_json();
    print("adding task ${id} with data: ${j}"); //j should be printed out nicely 
    bucket.put_json(id, j);
    out = id;
  };

  /** 
   * gets a task from the task list.
   * @param id - the id of the task to return
   * @returns the title of the task (optimistic)
   */
  let out get_task = (id: str) => Json {
    let t = Task.from_json(bucket.get_json(id));
    out = t.id;
  };


  /** 
   * sets effort estimation on a test
   * @param id - the id of the task to return
   * @param effort_estimation - the time (duration) estimated for this task
   * @returns The ID of the existing task.
   */
  let out add_estimation = (id: str): str => {
    in effort_estimation: duration;
    let t = get_task(id);
    t.effort = effort_estimation;
    bucket.put_json(id, t.to_json());
    out = id;
  }

  /** 
   * removes a task from the list
   * @param id - the id of the task to be removed
   * @returns the removed task id
   */
  let out remove_tasks = (id: str): str => {
    print("removing task ${id}");
    bucket.delete(id);
    out = id;
  };

   /** 
    * gets the tasks ids 
    */
  let out list_task_ids = () => Set<str> {
    let result = MutSet<str> {};
    for id in bucket.list() {
      result.add(id);
    }

    /** @returns set of task id */
    out = result.copy_mut();
  };

   /** 
    * find tasks with title that contains a term
    * @returns set of task id that matches the term
    */
  let out find_tasks_with = () => Array<str> {
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
    let out = output.copy();
  };
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
