defmodule Essh.TaskMacro do
	defmacro _left >>> right do
		[curr_task] = Agent.get(:curr_task, fn x -> x end)
		quote do
			res = unquote(right)
			case unquote(curr_task) do
				:pretask -> update_taskinfo(:pretask, res) 
				:dotask ->  update_taskinfo(:dotask, res)
				:potask ->  update_taskinfo(:potask, res)
			end
		end
	end

	defmacro pretask(steps \\[], do: do_block) do
		Agent.update(:curr_task, fn _ -> [:pretask] end)
		update_tasksteps(:pretask, steps)
		quote do
			unquote(do_block)
		end
	end

	defmacro dotask(steps \\[], do: do_block) do
		Agent.update(:curr_task, fn _ -> [:dotask] end)
		update_tasksteps(:dotask, steps)
		quote do
			unquote(do_block)
		end
	end

	defmacro posttask(steps \\[], do: do_block) do
		Agent.update(:curr_task, fn _ -> [:potask] end)
		update_tasksteps(:potask, steps)
		quote do
			unquote(do_block)
		end
	end

	defp update_tasksteps(currtask, steps) do
		case steps do
			[] -> Agent.update(:task_info, fn x -> Map.update(x, currtask, [], fn {_,0} -> {[],0} end) end)
			[sts] ->  
				Agent.update(:task_info, fn x -> Map.update(x, currtask, [], fn {_,0} -> {[],sts} end) end)
		end

	end

	def update_taskinfo(curr_task, res) do
		Agent.update(:task_info, fn x -> Map.update(x, curr_task, [], fn {xx, steps} -> {xx ++ [res], steps} end) end)
	end

	def getstate do
		res = Agent.get(:task_info, fn x -> x end)
#		Agent.stop(:curr_task)
#		Agent.stop(:task_info)
		case Enum.filter(res, fn {_, {x,xx}} -> length(x) != xx end) do
			[] -> res
			x -> IO.puts "task steps incorrect"; IO.inspect x; exit(:normal)
		end

	end
end
