defmodule Essh.TaskMacroRun do
	import Essh.TaskMacro
	import Essh.TasksModule 
	defmacro __using__(_opts) do
	end

	def run(filename) do
		ignore_warn
		
		case File.read(filename) do
			{:ok, res} ->  
				Code.eval_string(res, [], __ENV__)
				getstate
			{:error, reason} -> IO.puts "reason: #{reason}"; exit(:normal)
		end
		
	end	

end
