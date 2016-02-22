defmodule Mix.Tasks.Essh do
    use Application
    use Mix.Task
    
    def start(_type, _args) do
        import Supervisor.Spec
        children = Application.get_env(:essh, :iplist) |> Enum.map(&(worker(Essh.Worker, [&1], [id: &1])))
	
	ets_worker = [worker(Essh.EtsWorker, [], [])]
#        :io.format("~p~n",[children])

        opts = [strategy: :one_for_one, name: Essh.Supervisor]
        Supervisor.start_link(children ++ ets_worker, opts)
    end

    def run(args) do
        Essh.CLI.main(args)
        Application.start(:essh)

	:ets.new(:essh,[:named_table, :public])
	:ets.insert(:essh, {:total_exec, 0}) 
	:ets.insert(:essh, {:succ, 0})
	:ets.insert(:essh, {:fail, 0})

        :ssh.start
	Essh.Run.run
    
    end

    def get_iplist() do
        Essh.CLI.main "-f /root/testip"
    
    end
end
