defmodule Essh.TasksModule do
	defmacro cmd(arg) do
		quote do
			cmd = toString(unquote(arg))
			[task_type: :cmd, args: String.to_char_list(cmd)]
		end
	end

	defmacro upload(arg) do
		quote do
			[task_type: :upload, args: unquote(arg)]
		end
	end

	defmacro templ(arg) do
		quote do
			[task_type: :templ, args: unquote(arg)]
		end
	end

	def ignore_warn do
	end
	
	def toString(arg) do
		Enum.map(arg, fn x ->  
			  cond do
				is_map(x) -> "#{inspect Map.to_list(x)}"
				is_list(x) -> "#{inspect x}"
				is_atom(x) -> to_string(x)
				is_tuple(x) -> "#{inspect x}"
				true -> x
                          end
		end) |> Enum.join(" ")
	end
end
