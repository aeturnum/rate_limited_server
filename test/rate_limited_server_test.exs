defmodule RateLimitedServerTest do
  use ExUnit.Case

  alias RateLimitedServer.Jobs
  alias RateLimitedServer.JobState

  test "basic job single queue" do
    queue = "basic_test"
    func = fn -> IO.puts("test job") end
    id1 = Jobs.add_job(queue, func)
    id2 = Jobs.add_job(queue, func)
    # very briefly sleep to allow callback to happen, though it should happen immediately
    Process.sleep(10)
    assert Jobs.job_status(queue, id1).status == :done
    assert Jobs.job_status(queue, id2).status == :waiting
    Process.sleep(110)
    assert Jobs.job_status(queue, id2).status == :done
  end

  test "double queue" do
    queue1 = "double_test"
    queue2 = "double_test2"
    func = fn -> IO.puts("test job") end
    id1 = Jobs.add_job(queue1, func)
    id2 = Jobs.add_job(queue1, func)
    id3 = Jobs.add_job(queue2, func)
    id4 = Jobs.add_job(queue2, func)
    # very briefly sleep to allow callback to happen, though it should happen immediately
    Process.sleep(10)
    assert Jobs.job_status(queue2, id3).status == :done
    assert Jobs.job_status(queue1, id1).status == :done
    assert Jobs.job_status(queue1, id2).status == :waiting
    assert Jobs.job_status(queue2, id4).status == :waiting
    Process.sleep(110)
    assert Jobs.job_status(queue1, id2).status == :done
    assert Jobs.job_status(queue2, id4).status == :done
  end
end
