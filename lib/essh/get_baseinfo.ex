defmodule Hostname do
	defmacro __using__([]) do
		quote do
			'hostname'
		end
	end

end

defmodule Ips do
	defmacro __using__([]) do
		quote do
			'hostname -I'
		end
	end
end

defmodule Cpunums do
	defmacro __using__([]) do
		quote do
			'cat /proc/cpuinfo| grep "processor"| wc -l'
		end
	end
end
