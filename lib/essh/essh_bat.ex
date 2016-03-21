defmodule Essh.Bat do
  defmacro __using__(_options) do
    quote do
      import unquote(__MODULE__)
      Module.register_attribute __MODULE__, :descs, accumulate: true
      @before_compile unquote(__MODULE__)
    end
  end

  defmacro __before_compile__(_env) do
    quote do
      def run, do: Essh.Bat.Run.run(@descs, __MODULE__)
    end
  end
  
  defmacro desc(desci, do: do_block) do
    case do_block do
	{:__block__, _, block} -> 
	    len = length(block)-1 
	    block_desc = 0..len |> Enum.map(fn x -> {Enum.at(block, x), String.to_atom(desci <> to_string(x))} end)
    	    check_desc = String.to_atom(desci)
	    Enum.map(block_desc, fn {block, check_desc} -> 
		quote do

			@descs {unquote(check_desc), unquote(desci)}
			def unquote(check_desc)() do
				unquote(block)
			end
		end
	    end)
	block -> 
    	    check_desc = String.to_atom(desci)
	    quote do
		@descs {unquote(check_desc), unquote(desci)}
		def unquote(check_desc)() do
			unquote(block)
		end
	     end
    end
  end

  defmacro command(cmd, clause) do
    Essh.Bat.Run.build_command(cmd, clause)
  end

  defmacro include(filename) do
	quote do
		case File.exists?(unquote(filename)) do
			true -> File.read(unquote(filename))
			false -> IO.puts "#{unquote(filename)} not exists"; exit(:normal)
		end
	end
  end

end

defmodule Essh.Bat.Run do
  def run(descs, module) do
    Enum.map Enum.reverse(descs), fn{check_desc, desc} -> 
      		case apply(module, check_desc, []) do
       			res -> Keyword.put(res, :desc, desc)
      		end
    end 
  end

  def build_command(cmd, expect: clause, else: else_clause) do
    quote do
	[{:cmd,unquote(cmd)}, {:expect,unquote(clause)}, {:else,unquote(else_clause)}]
    end      
  end

  def build_command(_cmd, _args) do
    raise(ArgumentError,"expect and else not given")
  end

end
