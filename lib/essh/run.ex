defmodule Essh.Run do
    use GenServer

    def run do 
	iplist = Application.get_env(:essh,:iplist)
	tasks = for i <- iplist do
       		Task.async(fn -> GenServer.call(String.to_atom("worker"<>i),:exec, :infinity) end)
	end
	tasks_with_results = Task.yield_many(tasks, 327680)


	Enum.map(tasks_with_results, fn {task, res} ->
  		res || Task.shutdown(task, :brutal_kill);
	end)	

	IO.puts IO.ANSI.underline<>"\n\nSummary:"<>IO.ANSI.reset
	succ = :ets.lookup(:essh, :succ)[:succ]
	fail = :ets.lookup(:essh, :fail)[:fail]
	IO.puts "succ: "<>Integer.to_string(succ)<>"\nfail: "<>Integer.to_string(fail)
	:ets.delete(:essh)
	Application.stop(:essh)

    end

end
