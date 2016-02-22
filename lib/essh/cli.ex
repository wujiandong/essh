defmodule Essh.CLI do
    def main(args) do
        case check_args(args ++ ["--no-stdin"]) do
            :help -> print_help(); exit(:normal)
            nil -> case OptionParser.parse(args,aliases: [f: :file, h: :help, c: :cmd, 
				u: :upload], switches: [stdin: :boolean]) do
                        {pargs, [], []} -> 
				case process(pargs) do
					:nfo -> IO.puts "-f/--file or --stdin not given"; exit(:normal)
					:exist -> process_args(pargs)
				end
                        {_, _, error } -> IO.puts "#{args} error: #{error} "; print_help()  
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
		_   -> read_file(args[:file]); :exist
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
		is_nil(args[:cmd]) == false -> process_cmd(String.to_char_list(args[:cmd]))
		is_nil(args[:upload]) == false -> upload_file(args[:upload])

		true  -> IO.puts "-c/--cmd or -u/--upload not given"; exit(:normal)
	end
    end

    defp read_file(filename) do
	case File.exists?(filename) do
		true -> 
			case File.read(filename) do
			    {:ok, res} -> 
				parse_iplist(res)
					
			    {:error, reason} -> IO.puts "#{filename}: #{reason}"; exit(:normal)
			end
		false -> IO.puts "#{filename} not exists"; exit(:normal)
	end
    end

    defp parse_iplist(res) do
	iplist = String.split(res,"\n",trim: true)
		|> Enum.map(&(String.strip(&1)))
		|> Enum.filter(fn x -> 
			String.starts_with?(x,"#") == false
		end)
		|> Enum.filter(fn x ->
			String.ends_with?(x,"#") == false
		end)

	Application.put_env(:essh, :iplist, iplist)
	Application.put_env(:essh, :iplist_length, length(iplist))
    end

    defp process_cmd(cmd) do
	Application.put_env(:essh, :task_type, "cmd")
	Application.put_env(:essh, :cmd, cmd)
    end
	
    defp upload_file(args) do
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

    defp print_help() do
        IO.puts "help"
	exit(:normal)	
    end

end
