-module(reproducer).

-export([doit/2]).
-export([sh/1]).

-define(EXIT_STATUS_TIMEOUT, 10000).

doit(NumWorkers, Iterations)
  when is_integer(NumWorkers), is_integer(Iterations), NumWorkers > 1, Iterations > 1 ->
    register(collector, self()),
    io:format(standard_error, ".. starting ~p workers for ~p iterations/worker~n", [NumWorkers, Iterations]),
    Workers = [spawn_link(
		 fun() ->
			 worker(Iterations, "dd if=/dev/zero count=23")
		 end) ||
		  _ <- lists:duplicate(NumWorkers, x)],
    collect(Workers).

collect([]) -> io:format(standard_error, ".. all done~n", []);
collect(Workers) ->
    receive
	{Pid, Msg} ->
	    io:format(standard_error, ".. ~p\t:~p~n", [Pid, Msg]),
	    collect(lists:delete(Pid, Workers))
    end.

worker(0, _) ->
    collector ! {self(), finished};
worker(Iterations, Cmd) ->
    case sh(Cmd) of
	ok -> worker(Iterations - 1, Cmd);
	E -> collector ! {self(), {failed, E, Iterations - 1}}
    end.

sh(Command) ->
    PortSettings = [exit_status, use_stdio, stderr_to_stdout, binary],
    Port = open_port({spawn, Command}, PortSettings),
    try
        case sh_loop(Port, []) of
            ok -> ok;
            {error, {_Rc, _Output}} = Err -> Err
        end
    after
        try port_close(Port) catch _:_ -> ignored end
    end.

sh_loop(Port, Acc) ->
    receive
        {Port, {data, Data}} -> sh_loop(Port, [Data | Acc]);
        {Port, {exit_status, 0}} -> ok;
        {Port, {exit_status, Rc}} -> {error, Rc}
    after ?EXIT_STATUS_TIMEOUT ->
            PI = erlang:port_info(Port),
            OS_PID = proplists:get_value(os_pid, PI),
            case os:cmd("kill -0 " ++ integer_to_list(OS_PID)) of
                [] -> sh_loop(Port, Acc); %% OS proc still alive
                Kill0Msg ->
		    print_info(Kill0Msg, Port, PI, byte_size(iolist_to_binary(Acc))),
                    case os:getenv("ABORT_ON_RACE_HIT") of
                        false -> {error, {race, hit}};
                        _ ->
                            timer:sleep(1000),
                            erlang:halt(abort)
                    end
            end
    end.

print_info(Kill0Msg, Port, PI, ByteSize) ->
    io:format(standard_error,
	      "~n~p\t FAILED!~n"
	      "\t~p~n"
	      "\tno exit_status received for ~b ms~n"
	      "\tspawned OS process is dead, (kill -0 of OS_PID failed: ~p)~n"
	      "\tdata received: ~p~n"
	      "\t~p info: ~p~n~n"
	      "\tactive ports: ~p~n" ,
	      [self(), erlang:process_info(self(), message_queue_len),
	       ?EXIT_STATUS_TIMEOUT,
	       Kill0Msg, ByteSize, Port, PI, length(erlang:ports())]).
