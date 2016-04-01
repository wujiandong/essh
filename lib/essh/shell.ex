defmodule Essh.Shell do

	def loop do
		line = IO.gets("CLI> ")
		case line do
			"quit\n" -> quit
			_ -> 
				Application.put_env(:essh, :task_type, "cmd")
				IO.puts String.strip(line)
				Application.put_env(:essh, :cmd, String.to_char_list(String.strip(line)))
				Essh.Run.task_run
				loop
		end
	end

	defp main do
		IO.puts "minshell, write quit to exit"
		loop
	end

	defp quit do
		IO.puts "Bye!"
		System.halt(0)
		:ok
	end

	def run do
		:io.setopts([{:expand_fun, fn x -> expand_cmd(x) end}])
		main
	end

	defp expand_cmd(_x) do
		{:yes, [], []}
	end
end
