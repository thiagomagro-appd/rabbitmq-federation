%%  The contents of this file are subject to the Mozilla Public License
%%  Version 1.1 (the "License"); you may not use this file except in
%%  compliance with the License. You may obtain a copy of the License
%%  at http://www.mozilla.org/MPL/
%%
%%  Software distributed under the License is distributed on an "AS IS"
%%  basis, WITHOUT WARRANTY OF ANY KIND, either express or implied. See
%%  the License for the specific language governing rights and
%%  limitations under the License.
%%
%%  The Original Code is RabbitMQ.
%%
%%  The Initial Developer of the Original Code is GoPivotal, Inc.
%%  Copyright (c) 2007-2016 Pivotal Software, Inc.  All rights reserved.
%%

-module('Elixir.RabbitMQ.CLI.Ctl.Commands.FederationStatusCommand').

-behaviour('Elixir.RabbitMQ.CLI.CommandBehaviour').

-export([
         usage/0,
         flags/0,
         validate/2,
         merge_defaults/2,
         banner/2,
         run/2,
         switches/0,
         aliases/0,
         output/2,
         scopes/0
        ]).


%%----------------------------------------------------------------------------
%% Callbacks
%%----------------------------------------------------------------------------
usage() ->
     <<"federation_status [--down]">>.

flags() ->
    [].

validate(_,_) ->
    ok.

merge_defaults(A, Opts) ->
    {A, maps:merge(#{down => false}, Opts)}.

banner(_, #{node := Node, down := true}) ->
    erlang:iolist_to_binary([<<"Federation links down on node ">>,
                             atom_to_binary(Node, utf8)]);
banner(_, #{node := Node, down := false}) ->
    erlang:iolist_to_binary([<<"Federation status of node ">>,
                             atom_to_binary(Node, utf8)]).

run(_Args, #{node := Node, down := Down}) ->
    case rabbit_misc:rpc_call(Node, rabbit_federation_status, status, []) of
        {badrpc, _} = Error ->
            Error;
        Status ->
            {stream, filter(Status, Down)}
    end.

switches() ->
    [{down, boolean}].

aliases() ->
    [].

output({stream, FederationStatus}, _) ->
    Formatted = [begin
                     Timestamp = proplists:get_value(timestamp, St),
                     Map0 = maps:remove(timestamp, maps:from_list(St)),
                     Map1 = maps:merge(#{queue => <<>>,
                                         exchange => <<>>,
                                         upstream_queue => <<>>,
                                         upstream_exchange => <<>>,
                                         local_connection => <<>>,
                                         error => <<>>}, Map0),
                     Map1#{last_changed => fmt_ts(Timestamp)}
                 end || St <- FederationStatus],
    {stream, Formatted};
output(E, Opts) ->
    'Elixir.RabbitMQ.CLI.DefaultOutput':output(E, Opts, ?MODULE).

scopes() ->
    ['ctl', 'diagnostics'].

%%----------------------------------------------------------------------------
%% Formatting
%%----------------------------------------------------------------------------
fmt_ts({{YY, MM, DD}, {Hour, Min, Sec}}) ->
    erlang:list_to_binary(
      io_lib:format("~4..0w-~2..0w-~2..0w ~2..0w:~2..0w:~2..0w", 
                    [YY, MM, DD, Hour, Min, Sec])).

filter(Status, _IsDown = false) ->
    Status;
filter(Status, _IsDown = true) ->
    [St || St <- Status,
           not lists:member(proplists:get_value(status, St), [running, starting])].
