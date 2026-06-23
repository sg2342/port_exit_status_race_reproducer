
# port_exit_status_race_reproducer

try to reproduce the race condition that causes `{Port, {exit_status, _}}` not sent to the port owner.

## in Podman/Docker

```
time podman run -it --rm --workdir /repro --security-opt label=disable -v=`pwd`:/repro:rw erlang:29.0.2.0-slim  ./go.sh  100 10000
```


## on host, with erl in PATH 
```
$ ./go.sh
```

## from shell
```
$ erl
Erlang/OTP 29 [erts-17.0.2] [source] [64-bit] [smp:16:16] [ds:16:16:10] [async-threads:1] [jit:ns] [dtrace] [sharing-preserving]

Eshell V17.0.2 (press Ctrl+G to abort, type help(). for help)
1> c(reproducer).
{ok,reproducer}
2> reproducer:doit(100, 10000).
.. starting 100 workers for 10000 iterations/worker
Command is taking a long time, type Ctrl+G, then enter 'i' to interrupt

<0.139.0>        FAILED!
        {message_queue_len,0}
        no exit_status received for 10000 ms
        spawned OS process is dead, (kill -0 of OS_PID failed: "kill: 51723: No such process\n")
        data received: 11872
        #Port<0.18748> info: [{name,"dd if=/dev/zero count=23"},
                              {links,[<0.139.0>]},
                              {id,149984},
                              {connected,<0.139.0>},
                              {input,11872},
                              {output,0},
                              {os_pid,51723}]

        active ports: 101
.. <0.139.0>    :{failed,{error,{race,hit}},9812}

BREAK: (a)bort (A)bort with dump (c)ontinue (p)roc info (i)nfo
       (l)oaded (v)ersion (k)ill (D)b-tables (d)istribution
```
