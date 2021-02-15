defmodule RateLimitedServer.Jobs do
  use GenServer

  alias RateLimitedServer.JobState
  alias RateLimitedServer.Jobs

  # Callbacks
  @name Jobs

  def add_job(name, func) do
    GenServer.call(@name, {:add, name, func})
  end

  def status() do
    GenServer.call(@name, :status)
    # |> IO.inspect(label: "status():")
  end

  def job_status(name, id) do
    GenServer.call(@name, {:job_status, name, id})
    # |> IO.inspect(label: "job_status(#{name}, #{id}):")
  end

  def start_link(delay) do
    GenServer.start_link(__MODULE__, delay, name: @name)
  end

  def init(delay) do
    {:ok, %{delay: delay, queues: %{}}}
  end

  def handle_call({:add, name, func}, _from, state) do
    with queue <- queue(state, name),
         {job_id, up_queue} <- JobState.record_job(queue, func),
         up_queue <- maybe_schedule_job(up_queue, name) do
      # IO.puts("Added job #{inspect(func)} to queue #{name}")

      {
        :reply,
        job_id,
        state |> update_queue(name, up_queue)
      }
    end
  end

  def handle_call(:status, _from, state) do
    {
      :reply,
      Enum.reduce(
        state.queues,
        %{},
        fn {name, queue}, acc ->
          Map.put(acc, name, JobState.status(queue))
        end
      ),
      state
    }
  end

  def handle_call({:job_status, name, id}, _from, state) do
    with queue <- queue(state, name) do
      {
        :reply,
        JobState.get_result(queue, id),
        state
      }
    end
  end

  defp maybe_schedule_job(queue, queue_name) do
    # IO.puts("maybe_schedule_job(#{queue}, #{queue_name})")

    case JobState.should_start_job?(queue) do
      {true, {id, delay, func}} ->
        JobState.record_job_start(
          queue,
          Process.send_after(self(), {:job, queue_name, id, func}, delay)
        )

      # nothing for now
      {false, _} ->
        queue
    end
  end

  def handle_info({:job, queue_name, id, func}, state) do
    # IO.puts("doing job #{queue_name}.#{id}!")

    with queue <- queue(state, queue_name),
         # call actual function
         result <- func.(),
         # record this result
         new_queue <- JobState.record_result(queue, id, result),
         # maybe schedule a new job if we have one waiting
         new_queue <- maybe_schedule_job(new_queue, queue_name) do
      {
        :noreply,
        state |> update_queue(queue_name, new_queue)
      }
    end
  end

  defp queue(%{delay: d, queues: qs}, name) do
    case Map.has_key?(qs, name) do
      true -> qs[name]
      false -> JobState.new(d)
    end
  end

  defp update_queue(state, name, new_queue),
    do: %{state | queues: Map.put(state.queues, name, new_queue)}
end
