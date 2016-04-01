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
	if Application.get_env(:essh, :auth_method) == :passwd do
		user = IO.gets("user> ") |> String.rstrip |> String.to_char_list
		passwd = get_passwd()|> String.rstrip |> String.to_char_list
		Application.put_env(:essh, :passwd, {user, passwd})	
	end

	Agent.start_link(fn -> %{:pretask=>{[],0}, :dotask=>{[],0}, :potask=>{[],0} } end, name: :task_info)
        Agent.start_link(fn -> [] end, name: :curr_task)

        Essh.CLI.main(args)
        Application.start(:essh)

        :ssh.start
	Essh.Run.run
    
    end

    defp get_passwd() do
	pid = spawn_link(fn -> loop("passwd> ") end)
	ref = make_ref()
	value = IO.gets("passwd> ")

	send pid, {:done, self(), ref}
	receive do: ({:done, ^pid, ^ref} -> :ok)
	
	value
    end

    defp loop(prompt) do
	receive do
		{:done, parent, ref} -> 
			send parent, {:done, self, ref}
#			IO.write :standard_error, "\e[2K\r"
			IO.write :standard_error, "\e[2K\r"
	after
		1 ->
			IO.write :standard_error, "\e[2K\r#{prompt}"
			loop(prompt)
	end
    end	
end
