defmodule Essh.CLI do
    use Essh.TaskMacroRun

    def main(args) do
        case check_args(args ++ ["--no-stdin", "--no-shell"]) do
            :help -> print_help(); exit(:normal)
            nil -> case OptionParser.parse(args,aliases: [f: :file, h: :help, c: :cmd, 
				u: :upload, b: :bat, t: :templ, g: :group, s: :shell], 
				switches: [stdin: :boolean, shell: :boolean]) do
                        {pargs, [], []} -> 
				case process(pargs) do
					:nfo -> IO.puts "-f/--file or --group or --stdin not given"; exit(:normal)
					:exist -> 
						case pargs[:tasks] do
							nil ->	process_args(pargs)
							true -> IO.puts "-f/--file or --group or --stdin not given"; exit(:normal)
							_ -> 
								Application.put_env(:essh, :tasks, true)
							     	res = Essh.TaskMacroRun.run(pargs[:tasks])
							     	Application.put_env(:essh, :tasks_info, res)
						end
				end
                        {_, _, error } -> IO.puts "Argument error #{error} "; print_help()  
                   end
        end        
    end

    defp check_args([first_arg|_]) when first_arg in 
        ["--help", "-h"], do: :help

    defp check_args(_), do: nil

    defp process(args) do
	case args[:file] do
		nil -> 
		    case args[:stdin] do
			nil -> :nfo
			false -> :nfo
			true -> read_stdin; :exist
		    end
		true -> :nfo
		_  -> 
		    case args[:group] do
			nil -> :nfo
			true -> :nfo
			_ -> read_file(args[:file], String.to_atom(args[:group])); :exist
		    end	


        end
    end

    defp read_stdin do
	res = IO.stream(:stdio, :line) |> 
		Stream.filter(fn x -> 
				x = String.strip(x)
				String.starts_with?(x, "#") == false
			end)
		|> Stream.filter(fn x ->
				x = String.strip(x)
				String.ends_with?(x, "#") == false
	      		end)
		|> Stream.filter(fn x-> 
				x != "\n"
			end)
	iplist = Enum.to_list(res) |> Enum.map(&(String.strip(&1)))
	Application.put_env(:essh, :iplist, iplist)
	Application.put_env(:essh, :iplist_length, length(iplist))
    end

    defp process_args(args) do

	cond do
		is_boolean(args[:cmd]) == true ->  IO.puts "-c/--cmd after command not given"; exit(:normal)
		is_boolean(args[:upload]) == true -> IO.puts "-u/--upload after parameter not given"; exit(:normal)
		is_boolean(args[:bat]) == true -> IO.puts "-b/--bat after parameter not given"; exit(:normal)
		is_boolean(args[:templ]) == true -> IO.puts "-t/--templ after parameter not given"; exit(:normal) 
		is_boolean(args[:shell]) == true -> process_shell
		is_nil(args[:cmd]) == false -> process_cmd(String.to_char_list(args[:cmd]))
		is_nil(args[:upload]) == false -> upload_file(args[:upload])
		is_nil(args[:bat]) == false -> process_bat(args[:bat])
		is_nil(args[:templ]) == false -> process_templ(args[:templ])

		true  -> IO.puts "-c/--cmd or -u/--upload not given"; exit(:normal)
	end
    end

    defp read_file(filename, group) do
	case File.exists?(filename) do
		true -> 
			case File.read(filename) do
			    {:ok, res} -> 
				parse_iplist(res, group)
					
			    {:error, reason} -> IO.puts "#{filename}: #{reason}"; exit(:normal)
			end
		false -> IO.puts "#{filename} not exists"; exit(:normal)
	end
    end

    defp parse_iplist(res,group) do
	iplist = String.split(res,"\n",trim: true)
		|> Enum.map(&(String.strip(&1)))
		|> Enum.filter(fn x -> 
			String.starts_with?(x,"#") == false
		end)
		|> Enum.filter(fn x ->
			String.ends_with?(x,"#") == false
		end)
		|> Enum.uniq
		

	iplist_re = Regex.scan(~r/\[(\S+)\](.+?)(?=\[\S+\]?|$)/s, Enum.join(iplist, " ")) 

	case iplist_re do
		[] -> Application.put_env(:essh, :iplist, iplist)
		      Application.put_env(:essh, :iplist_length, length(iplist))
	
		_ -> 
		iplist_kw = Enum.map(iplist_re, fn [_|tail] -> 
					[group|[hosts]]=tail
					{String.to_atom(group), String.split(hosts, " ", trim: true)} 
				end)	
		group_name_list = Keyword.keys(iplist_kw)
		parent_group = group_name_list 
					|> Enum.filter(fn x -> String.contains?(to_string(x),":child") == true end) 
					|>  Enum.map(fn x -> String.to_atom(String.replace(to_string(x),":child", "")) end)
		filter_group = group_name_list |> Enum.filter(fn x -> String.contains?(to_string(x),":child") == false end)

		case group do
			:all -> 
				ip_all = Regex.scan(~r/(\d+\.){3}\d+/s, Enum.join(iplist, " ")) |> Enum.map(fn [head|_] -> head end)
				Application.put_env(:essh, :iplist, ip_all)	
		      		Application.put_env(:essh, :iplist_length, length(ip_all))
			g -> 
			  cond  do   
				Enum.member?(filter_group,g) == true  -> 
					ipl = Keyword.get(iplist_kw, g) 
					Application.put_env(:essh, :iplist, ipl)
		      			Application.put_env(:essh, :iplist_length, length(ipl))

				Enum.member?(parent_group,g) == true -> 
					ipl = List.flatten( 
						Keyword.get(iplist_kw, String.to_atom(to_string(g)<>":child")) 
						|> Enum.map(fn x -> Keyword.get(iplist_kw, String.to_atom(x)) end)
					      )
					Application.put_env(:essh, :iplist, ipl)
		      			Application.put_env(:essh, :iplist_length, length(ipl))
				true -> IO.puts "#{g} is invalid"; exit(:normal)
			  end
		end
		     
	end

    end

    def process_cmd(cmd) do
	Application.put_env(:essh, :task_type, "cmd")
	Application.put_env(:essh, :cmd, cmd)
    end
	
    def upload_file(args) do
	Application.put_env(:essh, :task_type, "upload")
	case String.split(args) do
		[src, dest] -> 
			case File.exists?(src) do
		   		true -> Application.put_env(:essh, :up_file, {src, dest})
		   		false -> IO.puts "#{src} not exists"; exit(:normal)   
			end
		_ -> IO.puts "dest file not given"; exit(:normal)
	end
    end

    def process_bat(filename) do
	Application.put_env(:essh, :task_type, "bat")	
	{res, _} = Essh.Bat_run.bat_run(filename)
	Application.put_env(:essh, :bat_cmd, res)
#	exit(:normal)
    end

    def process_templ(args) do
	Application.put_env(:essh, :task_type, "templ")
	case String.split(args) do
		[templ_file, dest] -> 
			case File.exists?(templ_file) do
				true -> Application.put_env(:essh, :templ_file, {templ_file,dest})
				false -> IO.puts "#{templ_file} not exists"; exit(:normal)
			end
		_ -> IO.puts "dest file not given"; exit(:normal)
	end
    end

    defp process_shell() do
	Application.put_env(:essh, :shell, true)
    end

    defp print_help() do
        IO.puts "help"
	exit(:normal)	
    end

end
