%% -*- coding: utf-8 -*-
%% Automatically generated, do not edit
%% Generated by gpb_compile version 4.10.5

-ifndef(erl_playground_pb).
-define(erl_playground_pb, true).

-define(erl_playground_pb_gpb_version, "4.10.5").

-ifndef('CREATE_SESSION_PB_H').
-define('CREATE_SESSION_PB_H', true).
-record(create_session,
        {
        }).
-endif.

-ifndef('SERVER_MESSAGE_PB_H').
-define('SERVER_MESSAGE_PB_H', true).
-record(server_message,
        {message                :: iodata()         % = 1
        }).
-endif.

-ifndef('OPERATOR_MESSAGE_PB_H').
-define('OPERATOR_MESSAGE_PB_H', true).
-record(operator_message,
        {message                :: iodata()         % = 1
        }).
-endif.

-ifndef('REQ_PB_H').
-define('REQ_PB_H', true).
-record(req,
        {type                   :: create_session | server_message | random_joke_req | get_unique_caller_id | operator_req | integer(), % = 1, enum req.type_enum
         create_session_data    :: erl_playground_pb:create_session() | undefined, % = 2
         server_message_data    :: erl_playground_pb:server_message() | undefined, % = 3
         operator_msg_data      :: erl_playground_pb:operator_message() | undefined % = 4
        }).
-endif.

-ifndef('ENVELOPE_PB_H').
-define('ENVELOPE_PB_H', true).
-record(envelope,
        {uncompressed_data      :: erl_playground_pb:req() % = 2
        }).
-endif.

-endif.
