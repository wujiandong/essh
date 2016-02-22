defmodule Essh.EtsWorker do
    use GenServer

    def init do
        {:ok, []}
    end

    def start_link do
        GenServer.start_link(__MODULE__,[], [name: :etsworker]) 
    end

    def handle_call(:insert, _from, _state) do
	:ets.update_counter(:essh,:total_exec, 1)	
        {:reply, [], []}
    end

    def handle_call(:look, _from, _state) do
	curr_total = :ets.lookup(:essh,:total_exec)
	{:reply, curr_total[:total_exec], []}
    end

    def handle_cast(:ins_succ, _state) do
	:ets.update_counter(:essh, :succ, 1)
	{:noreply, []}
    end

    def handle_cast(:ins_fail, _state) do
	:ets.update_counter(:essh, :fail, 1)
	{:noreply, []}
    end
end
