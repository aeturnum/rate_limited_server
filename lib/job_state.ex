defmodule RateLimitedServer.JobState do
  defstruct result_id: 0, delay: 0, last: nil, timer: nil, order: [], results: %{}

  alias RateLimitedServer.JobState

  @state_waiting :waiting
  @state_done :done
  @state_unknown :unknown

  def new(delay) do
    %JobState{delay: delay}
  end

  def status(js = %JobState{}) do
    %{
      delay: js.delay,
      timer: timer_str(js.timer),
      order: js.order,
      results:
        Enum.reduce(
          js.results,
          %{},
          fn {id, result}, acc ->
            Map.put(acc, id, %{status: result.status, result: result.result})
          end
        )
    }
  end

  def record_job(js = %JobState{}, func) do
    with new_results <- Map.put(js.results, js.result_id, new_record(func)),
         new_order <- js.order ++ [js.result_id],
         next_id <- js.result_id + 1 do
      {
        js.result_id,
        %{js | result_id: next_id, order: new_order, results: new_results}
      }
    end
  end

  # return {should_start, {result_id, delay, func}} - latter argument ignored if false
  def should_start_job?(%JobState{order: []}), do: {false, {}}

  # don't start a job if one is already running
  def should_start_job?(%JobState{timer: t}) when is_nil(t) == false, do: {false, {}}

  def should_start_job?(js = %JobState{order: [next | _], timer: nil}) do
    {true,
     {
       next,
       job_delay(js),
       js.results[next].func
     }}
  end

  def record_job_start(js = %JobState{order: [_ | rest]}, timer) do
    %{js | order: rest, timer: timer}
  end

  def record_result(js = %JobState{}, id, val) do
    with record <- Map.get(js.results, id),
         updated_record <- %{record | result: val, status: @state_done},
         now <- ts() do
      # use job completion as the mark where we start counting until we can extecute the next job
      # remove timer to mark that we're done with this one
      %{js | results: Map.put(js.results, id, updated_record), last: now, timer: nil}
    end
  end

  def get_result(js = %JobState{}, id),
    do: Map.get(js.results, id, @state_unknown) |> Map.drop([:func])

  # time before staring next job
  def job_delay(%JobState{last: nil}), do: 0

  def job_delay(%JobState{delay: d, last: last_ts}) do
    with time_since_last_job <- ts() - last_ts do
      if time_since_last_job > d do
        # we can start now
        0
      else
        # start in d seconds, minus time elapsed
        d - time_since_last_job
      end
    end
  end

  # private functions

  defp timer_str(nil), do: "0.0s"
  defp timer_str(timer), do: "#{Process.read_timer(timer) / 1000}s"

  defp new_record(func), do: %{func: func, status: @state_waiting, result: nil}

  defp ts(), do: System.monotonic_time(:second)

  # protocols
  defimpl String.Chars, for: JobState do
    def to_string(js = %JobState{}) do
      with res <- results_str(js.results) do
        "%JS#{inspect(js.order)} timer: #{inspect(js.timer)}| #{res}}"
      end
    end

    def results_str(results) do
      Enum.reduce(
        results,
        [],
        fn {id, result}, acc ->
          acc ++ ["#{id}: %{stat: #{result.status}}"]
        end
      )
      |> inspect
    end
  end
end
