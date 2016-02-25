defmodule Essh.Worker do
    use GenServer

    def init([ip]) do
	total = Application.get_env(:essh, :iplist_length)
        {:ok, [{:ip,ip}, {:total, total}]}
    end

    def start_link(ip) do
        GenServer.start_link(__MODULE__,[ip], [name: String.to_atom("worker"<>ip)]) 
    end

    def handle_call(:exec, _from, state) do
        ips = String.to_char_list(state[:ip])
	run_task(ips, state[:total])
        {:reply, [], []}
    end

    def terminate(_reason, _state) do
	:ok
    end

    defp run_task(ips, total) do
#        {:ok, connref} = :ssh.connect(ips,12321,[{:user, 'root'},{:silently_accept_hosts, true}],30000)
#	connref = connect_ssh(ips, total)
#	res = SSHEx.cmd! connref, Application.get_env(:essh, :cmd),[exec_timeout: 30000]

	case connect_ssh(ips) do
		{:ok, connref} -> 
			try do
			    case Application.get_env(:essh, :task_type) do
				"cmd" -> 
			    		res = SSHEx.cmd! connref, Application.get_env(:essh, :cmd),[exec_timeout: 30000]
			    		GenServer.call(:etsworker, :insert)
			    		print_output(ips, res, total, true)
			    		GenServer.cast(:etsworker, :ins_succ)
				"upload" -> 
					run_upload(connref, ips, total)	
			    end
			rescue
			    e -> print_output(ips, Map.get(e, :message), total, false)
			after
			    :ssh.close(connref)
			end	
		{:error, res} -> 	
			GenServer.call(:etsworker, :insert)
			print_output(ips, res, total, false)
			GenServer.cast(:etsworker, :ins_fail)
	end



    end

    defp run_upload(connref, ips, total) do
	{src, dest} = Application.get_env(:essh, :up_file)
	case :ssh_sftp.start_channel(connref,[]) do
		{:ok, channel} -> 
			case :ssh_sftp.open(channel, dest ,[:write,:binary]) do
				{:ok, handle} -> 
					#todo add try/catch
					File.stream!(src,[:read, :binary], 8192) |> 
						Stream.each(fn x -> :ssh_sftp.write(channel,handle, x) end)
						|> Stream.run
					:ssh_sftp.close(channel, handle)
					:ssh_sftp.stop_channel(channel)
					GenServer.call(:etsworker, :insert)
					print_output(ips, "upload #{src} -> #{dest} succ", total, true)	
			    		GenServer.cast(:etsworker, :ins_succ)
			
				{:error, reason} -> print_output(ips, reason, total, false)
			end	
		{:error, reason} ->  print_output(ips, reason, total, false)
	end	
    end

    defp connect_ssh(ips) do
	case :ssh.connect(ips,22,[{:user, 'root'},{:silently_accept_hosts, true}],30000) do
		{:ok, connref} -> {:ok, connref}
		{:error, reason} -> 
			res = "connect #{ips} error: #{reason}"
			{:error, res}
	end
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
