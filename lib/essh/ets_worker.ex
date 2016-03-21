defmodule Essh.EtsWorker do
    use GenServer

    def init([ipl]) do
        {:ok, ipl}
    end

    def start_link do
	ipl = Application.get_env(:essh, :iplist)
        GenServer.start_link(__MODULE__,[ipl], [name: :etsworker]) 
    end

    def handle_call(:insert, _from, state) do
	:ets.update_counter(:essh,:total_exec, 1)	
        {:reply, [], state}
    end

    def handle_call(:look, _from, state) do

	curr_total = :ets.lookup(:essh,:total_exec)
	{:reply, curr_total[:total_exec], state}
    end

    def handle_cast(:ins_succ, state) do

	:ets.update_counter(:essh, :succ, 1)
	{:noreply, state}
    end

    def handle_cast(:ins_fail, state) do

	:ets.update_counter(:essh, :fail, 1)
	{:noreply, state}
    end
end
