-module(sockserv).
-behaviour(gen_server).
-behaviour(ranch_protocol).

-include("erl_playground_pb.hrl").

%% ------------------------------------------------------------------
%% API Function Exports
%% ------------------------------------------------------------------

-export([start_link/4]). -ignore_xref([{start_link, 4}]).
-export([start/0]).

%% ------------------------------------------------------------------
%% gen_server Function Exports
%% ------------------------------------------------------------------

-export([init/1, terminate/2, code_change/3]).
-export([handle_call/3, handle_cast/2, handle_info/2]).

%% ------------------------------------------------------------------
%% ranch_protocol Function Exports
%% ------------------------------------------------------------------

-export([init/4]). -ignore_xref([{init, 4}]).

%% ------------------------------------------------------------------
%% Record Definitions
%% ------------------------------------------------------------------

-record(state, {
    socket :: any(), %ranch_transport:socket(),
    transport,
    unique_id
}).
-type state() :: #state{}.

%% ------------------------------------------------------------------
%% Macro Definitions
%% ------------------------------------------------------------------

-define(SERVER, ?MODULE).
-define(CB_MODULE, ?MODULE).

%% ------------------------------------------------------------------
%% API Function Definition
%% ------------------------------------------------------------------

start() ->
    {ok, Port} = application:get_env(erl_playground, tcp_port),
    {ok, MaxConnections} = application:get_env(erl_playground, max_connections),

    TcpOptions = [
        {backlog, 100}
    ],

    {ok, _} = ranch:start_listener(
        sockserv_tcp,
        ranch_tcp,
        [{port, Port},
        {num_acceptors, 100}] ++ TcpOptions,
        sockserv,
        [none]
    ),

    ranch:set_max_connections(sockserv_tcp, MaxConnections),
    lager:info("server listening on tcp port ~p", [Port]),
    ok.

start_link(Ref, Socket, Transport, Opts) ->
    proc_lib:start_link(?MODULE, init, [Ref, Socket, Transport, Opts]).

%% ------------------------------------------------------------------
%% ranch_protocol Function Definitions
%% ------------------------------------------------------------------

init(Ref, Socket, Transport, [_ProxyProtocol]) ->
    lager:info("sockserv init'ed ~p",[Socket]),

    ok = proc_lib:init_ack({ok, self()}),
    ok = ranch:accept_ack(Ref),

    Opts = [{packet, 2}, {packet_size, 16384}, {active, once}, {nodelay, true}],
    _ = Transport:setopts(Socket, Opts),

    State = #state{
        socket = Socket,
        transport = Transport,
        unique_id = show_caller_id()
    },

    gen_server:enter_loop(?MODULE, [], State).

%% ------------------------------------------------------------------
%% gen_server Function Definitions
%% ------------------------------------------------------------------

%% This function is never called. We only define it so that
%% we can use the -behaviour(gen_server) attribute.
init([]) -> undefined.

handle_cast(Message, State) ->
    _ = lager:notice("unknown handle_cast ~p", [Message]),
    {noreply, State}.

handle_info({tcp, _Port, <<>>}, State) ->
    _ = lager:notice("empty handle_info state: ~p", [State]),
    {noreply, State};
handle_info({tcp, _Port, Packet}, State = #state{socket = Socket}) ->
    self() ! {packet, Packet},
    ok = inet:setopts(Socket, [{active, once}]),
    {noreply, State};
handle_info({tcp_closed, _Port}, State) ->
    {stop, normal, State};
handle_info({tcp_error, _Socket, Reason}, State) -> 
    io:fwrite("Error: ~p~n", [Reason]),
    {stop, normal, State};
handle_info({packet, Packet}, State) ->
    Req = utils:open_envelope(Packet),
    NewState = process_packet(Req, State, utils:unix_timestamp()),
    {noreply, NewState};

handle_info(Message, State) ->
    _ = lager:notice("unknown handle_info ~p -- ~p", [Message, State]),
    {noreply, State}.

handle_call(Message, _From, State) ->
    _ = lager:notice("unknown handle_call ~p", [Message]),
    {noreply, State}.

terminate(normal, _State) ->
    _ = lager:info("Goodbye!"),
    ok;
terminate(Reason, _State) ->
    _ = lager:notice("No terminate for ~p", [Reason]),
    ok.

code_change(_OldVsn, State, _Extra) ->
    {ok, State}.

%% ------------------------------------------------------------------
%% Internal Function Definitions
%% ------------------------------------------------------------------

-spec process_packet(Req :: #req{}, State :: state(), Now :: integer()) -> NewState :: state().
process_packet(undefined, State, _Now) ->
    _ = lager:notice("client sent invalid packet, ignoring ~p",[State]),
    State;
process_packet(#req{ type = Type } = Req, State = #state{}, _Now) ->
    case handle_request(Type, Req, State) of
        {noreply, NewState} -> NewState;
        {Response, NewState} -> send(Response, NewState), NewState
    end.

send(Response, #state{socket = Socket, transport = Transport}) ->
	send(Response, Socket, Transport).

send(Response, Socket, Transport) ->
    Data = utils:add_envelope(Response),
    Transport:send(Socket, Data).
    
server_message(Msg) ->
    #req{
        type = server_message,
        server_message_data = #server_message {
            message = Msg
        }
    }.

handle_request(create_session, #req{}, State) ->
    NewState = State#state{},
    {noreply, NewState};
handle_request(random_joke_req, _Req, State) ->
    {server_message(request_random_joke()), State};
handle_request(get_unique_caller_id, _Req, #state{unique_id = UID} = State) ->
    {server_message(
        io_lib:format("Unique Caller Id : ~p \n", [UID])
      ), State};
handle_request(operator_req,
            #req{
                operator_msg_data = #operator_message{
                    message = Msg
                }
            },
            #state{} = State) ->
    {server_message(operator_algorithm(Msg)), State}.


request_random_joke() ->
    Num = rand:uniform(4),
    io_lib:format("Random Joke \n ~s\n", [lists:nth(Num, populate_list_joke())]).

populate_list_joke() ->
    List1 = ["I'll Delete your OS Now! :D ",
             "Valve present Half-life 3!!!", 
             "Who read this algorithm probably make seppuku at the end... XD", 
             "Ducks say 'Quak' but there isn't sign of quak...e! D:"],
    List1.

show_caller_id() -> 
    Id = erlang:phash2({node(), now()}), 
    Id.

operator_algorithm(Msg) ->
    {Num,Rest} = string:to_integer(Msg),
    if Num == error ->
        Msg
    ; true ->
        check_number_is_even(Num)
    end.

check_number_is_even(Num) ->
    Rest = Num rem 2,
    Result = 
        if Rest == 0 ->
            "This Number is Even! \n"
        ;  true ->
            "This Number is Odd! \n"
        end,
    Result.