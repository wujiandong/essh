defmodule Essh.Run do
    use  GenServer

    def run do 
	case Application.get_env(:essh, :shell, false) do
		true -> Essh.Shell.run
		false  -> 
			task_run
			Application.stop(:essh)
#			System.halt(0)
	end
    end
	
    defp init() do
	:ets.new(:essh,[:named_table, :public])
	:ets.insert(:essh, {:total_exec, 0}) 
	:ets.insert(:essh, {:succ, 0})
	:ets.insert(:essh, {:fail, 0})

    end

    def task_run() do
	init

	tasks = for i <- Application.get_env(:essh,:iplist)  do
		Task.async(fn -> GenServer.call(String.to_atom("worker"<>i),:exec, :infinity) end)
	end

	tasks_with_results = Task.yield_many(tasks, 327680)
	Enum.map(tasks_with_results, fn {task, res} ->
		res || Task.shutdown(task, :brutal_kill)
	end)	
	
	IO.puts IO.ANSI.underline<>"\n\nSummary:"<>IO.ANSI.reset
	succ = :ets.lookup(:essh, :succ)[:succ]
	fail = :ets.lookup(:essh, :fail)[:fail]
	IO.puts "succ: "<>Integer.to_string(succ)<>"\nfail: "<>Integer.to_string(fail)

	:ets.delete(:essh)
    end
end
