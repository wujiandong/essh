defmodule Essh.Worker do
    use GenServer
    import Essh.CLI

    @task_type [:pretask, :dotask, :potask]
    def init([ip]) do
	total = Application.get_env(:essh, :iplist_length)

        {:ok, [{:ip,ip}, {:total, total}]}
    end

    def start_link(ip) do
        GenServer.start_link(__MODULE__,[ip], [name: String.to_atom("worker"<>ip)]) 
    end

    def handle_call(:exec, _from, state) do
        ips = String.to_char_list(state[:ip])
	total = state[:total]
	case connect_ssh(ips) do
		{:ok, connref} ->
			case Application.get_env(:essh, :tasks, false) do
				false -> 
					run_task(ips, total, connref)
					:ssh.close(connref)
				true -> 
					res = Application.get_env(:essh, :tasks_info) 
					opts = [ips: ips, total: total, connref: connref]
					run_tasks(res, opts)
					:ssh.close(connref)
			end
		{:error, res} -> 	
			GenServer.call(:etsworker, :insert)
			print_output(ips, res, total, false)
			GenServer.cast(:etsworker, :ins_fail)
	end
        {:reply, [], []}
    end

    def terminate(_reason, _state) do
	:ok
    end

    defp run_task(ips, total, connref) do

	try do
	    case Application.get_env(:essh, :task_type) do
		"cmd" -> 
			run_cmd(connref, ips, total)
		"upload" -> 
			run_upload(connref, ips, total)	
		"bat" -> 
			run_bat(connref, ips, total)
		"templ" -> 
			run_templ(connref, ips, total)
	    end
	rescue
	    e -> 
		ins_curr(ips, total, Map.get(e, :message), false)
	end	
    end

    defp run_cmd(connref, ips, total) do
	res = SSHEx.cmd! connref, Application.get_env(:essh, :cmd),[exec_timeout: 30000]
	ins_curr(ips, total, res, true)
    end

    defp run_upload(connref, ips, total) do
	{src, dest} = Application.get_env(:essh, :up_file)
	case :ssh_sftp.start_channel(connref,[]) do
		{:ok, channel} -> 
#			:ssh_sftp.delete(channel,dest)
			case :ssh_sftp.open(channel, dest ,[:write,:binary]) do
				{:ok, handle} -> 
					#todo add try/catch
					File.stream!(src,[:read, :binary], 8192) |> 
						Stream.each(fn x -> :ssh_sftp.write(channel,handle, x) end)
						|> Stream.run
					:ssh_sftp.close(channel, handle)
					:ssh_sftp.stop_channel(channel)
					ins_curr(ips, total, "upload #{src} -> #{dest} succ", true)
			
				{:error, reason} -> 
					ins_curr(ips, total, "dest: #{dest}: "<>to_string(reason), false)
			end
		{:error, reason} ->  
				ins_curr(ips, total, "dest: #{dest}: "<>to_string(reason), false)

	end	
    end
    
    defp run_bat(connref, ips, total) do
	bat_cmd = Application.get_env(:essh, :bat_cmd)

	tasks = for [{:desc,desc},{:cmd, cmd},{:expect,expect}, {:else, els}] <- bat_cmd do
			Task.async(fn -> 
				res = SSHEx.cmd! connref, String.to_char_list(cmd), [exec_timeout: 30000] 
				res = String.strip(res)

				if to_string(res) == to_string(expect) do
					{:ok, desc,  []}		
				else
					SSHEx.cmd! connref, String.to_char_list(els), [exec_timeout: 30000]	
					{:error, desc, res}
				end
				
			end)
		end

	tasks_with_results = Task.yield_many(tasks, 327680)	
	results = Enum.map(tasks_with_results, fn {task, res} ->
  		res || Task.shutdown(task, :brutal_kill)
	end)

	rr = Enum.map(results, fn {:ok, value} -> 
		case value do
			{:error, desc, res} -> 
				case String.valid?(res) do
					true -> IO.ANSI.red<>desc <> ": error\n" <> "Actual_Value: " 
						<> res <> "\n"<>IO.ANSI.reset <> String.duplicate("-",30)
					false -> 
						res_valid = String.chunk(res, :valid) 
								|>  Enum.filter(fn x -> String.valid?(x) == true end)
								|> to_string
						IO.ANSI.red<>desc <> ": error\n" <> "Actual_Value: " <> res_valid
						<>"\n"<>IO.ANSI.reset<>String.duplicate("-",30)
				end
			{:ok, desc, _} -> desc <> ": ok"
		end
	end)

	ins_curr(ips, total, Enum.join(rr, "\n"), true)
    end

    defp run_templ(connref, ips, total) do
	{templ_file,dest} = Application.get_env(:essh, :templ_file)

	case :ssh_sftp.start_channel(connref,[]) do
		{:ok, channel} -> 
			content = EEx.eval_file templ_file, [], trim: true
			case :ssh_sftp.write_file(channel,dest, content) do
				:ok -> 
					:ssh_sftp.stop_channel(channel)
					ins_curr(ips, total, "upload #{templ_file} -> #{dest} succ", true)

				{:error, reason} ->
					ins_curr(ips, total, "dest: #{dest}: "<>to_string(reason), false)
			end
		{:error, reason} -> 
			ins_curr(ips, total, "dest: #{dest}: "<>to_string(reason), false)
	end	
    end

    defp connect_ssh(ips) do

	case :ssh.connect(ips,12321,[{:user, 'root'},{:silently_accept_hosts, true}],30000) do
		{:ok, connref} -> {:ok, connref}
		{:error, reason} -> 
			res = "connect #{ips} error: #{reason}"
			{:error, res}
	end
    end

    defp run_tasks(task_info, opts) do
	divider = String.duplicate("-", 20)
	[{:ips, ips}, {:total, total}, {:connref, connref}] = opts	

	res = Enum.map(@task_type, fn x -> 
			case Map.get(task_info, x) do
				{[], 0} -> "#{x}: no task info\n"
				{dt, _} -> 
					info = Enum.map(dt, fn [{:task_type, task_type}, {:args, args}] -> 
						case task_type do
							:cmd -> process_cmd(args)

							:upload -> upload_file(args)

							:templ -> process_templ(args)
						end

						run_task(ips, total, connref)
					
					end) |> Enum.into([divider <> "#{x} infos" <> divider <> "\n"]) 
					|>Enum.join("\n")
			end
		end) |> Enum.join("\n")

	GenServer.call(:etsworker, :insert)
	GenServer.cast(:etsworker, :ins_succ)
	print_output(ips, res, total, true)	
    end

    defp ins_curr(ips, total, info, true) do
	case Application.get_env(:essh, :tasks, false) do
		false -> 
			GenServer.call(:etsworker, :insert)
			print_output(ips, info, total, true)	
			GenServer.cast(:etsworker, :ins_succ)
		true -> 
			info
	end
    end

    defp ins_curr(ips, total, info, false) do
	GenServer.call(:etsworker, :insert)
	print_output(ips, info, total, false)
	GenServer.cast(:etsworker, :ins_fail)
    end

    defp print_output(ips, res, total, is_correct) do
	curr_total = GenServer.call(:etsworker, :look)
	curr_percent = Float.to_string(Float.ceil(curr_total*100/total, 2), [decimals: 0, compact: true])<>"%"

	space_newline = "\n"<>String.duplicate(" ", 25)

	common_output = IO.ANSI.cyan<>"[" <> String.ljust(curr_percent, 4) <>"] "
			<>IO.ANSI.reset
			<> String.ljust(to_string(ips)<>":",18)
	normal_output = IO.ANSI.green
			<>String.rjust(String.replace(to_string(String.strip(res)),"\n", space_newline),22)
			<>IO.ANSI.reset
	error_output = IO.ANSI.red<>String.rjust(res, 18)<>IO.ANSI.reset

	output = case is_correct do
			true -> common_output <> normal_output
			false -> common_output <> error_output
		end
		
	IO.puts output
    end
end
