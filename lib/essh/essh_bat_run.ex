defmodule Essh.Bat_run do
	use Essh.Bat
	def bat_run(filename) do
		{:ok, res} = Essh.Bat.include(filename)
		res = "defmodule B do \n" <>"use Essh.Bat\n" <> res <>"\n end\n" <> "B.run"
#		Code.eval_string(res,[], requires: [Essh.Bat])
		Code.eval_string(res)

	end
end
