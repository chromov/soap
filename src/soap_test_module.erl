%%
%% %CopyrightBegin%
%%
%% Copyright Hillside Technology Ltd. 2016. All Rights Reserved.
%%
%% Licensed under the Apache License, Version 2.0 (the "License");
%% you may not use this file except in compliance with the License.
%% You may obtain a copy of the License at
%%
%%     http://www.apache.org/licenses/LICENSE-2.0
%%
%% Unless required by applicable law or agreed to in writing, software
%% distributed under the License is distributed on an "AS IS" BASIS,
%% WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
%% See the License for the specific language governing permissions and
%% limitations under the License.
%%
%% %CopyrightEnd%
%%

%%%
%%% Create a module with a function for each SOAP operation. The functions
%%% call the operation with a valid parameter.
%%%
%%% The generated module can either be used directly (unchanged) to perform 
%%% test the implementation in a very limited way, or the generated parameters
%%% can be modified to do more relaistic tests.
%%%
%%% The information about the SOAP service is read from the client module that 
%%% is generated by wsdl2soap. This is possible because these modules expose a 
%%% fucntion 'interface/0'. This function returns an #interface{} record which 
%%% contains the required information.
%%%
-module(soap_test_module).

%% Create a set of functions that call the operations
%% from a client module.

-export([from_client/1]).
-export([from_client/2]).
-export([from_interface/5]).

-include("include/soap.hrl").

-type option() :: 
    {hrl_name, string()} |    %% name of the .hrl file that must be included
    {test_module, string()} | %% name of the generated module
    {soap_options, any()} |
    {soap_headers, any()}. 

-type function_name() :: atom().

%%% ============================================================================
%%% Exported functions
%%% ============================================================================

-spec from_client(Module::atom()) -> {ok, [function_name()]}.
from_client(Module) ->
    from_client(Module, []).

-spec from_client(Module::atom(), [option()]) -> {ok, [function_name()]}.
from_client(Module, Options) ->
    Module_string = atom_to_list(Module),
    %% the generated module needs to include the .hrl file that was generated by 
    %% wsdl2erlang. In general it will be possible to derive the name of that file
    %% from the name of the client module, but if not it can be passed explictly
    %% using the {hrl_name, string()} option.
    Default_hrl = 
        case re:run(Module_string, ".*_client$") of
            {match, [{0, L}]} ->
                    lists:sublist(Module_string, 1, L - 7) ++ ".hrl";
            nomatch ->
                Module_string ++ ".hrl"
        end,
    Hrl_file_raw = proplists:get_value(hrl_name, Options, Default_hrl),
    Hrl_file = filename:rootname(Hrl_file_raw, ".hrl") ++ ".hrl",
    Default_test_module = Module_string ++ "_test",
    Test_module = proplists:get_value(test_module, Options, Default_test_module),
    Interface = Module:interface(),
    from_interface(Interface, Module_string, Test_module, Hrl_file, Options).


-spec from_interface(Interface::#interface{}, 
                     Module::string(), Test_module::string(), Hrl_file::string(),
                     [option()]) -> {ok, [function_name()]}.
from_interface(Interface, Module, Test_module, Hrl_file, Options) ->
    Default_soap_options = [{url, Interface#interface.url}],
    Soap_options = proplists:get_value(soap_options, Options, Default_soap_options),
    Soap_headers = proplists:get_value(soap_headers, Options, []),
    Header = header(list_to_atom(Test_module), Hrl_file),
    {Functions, Function_code} = lists:unzip(make_functions(list_to_atom(Module), 
                                                            Interface, Soap_headers, 
                                                            Soap_options)),
    Output_file = Test_module ++ ".erl", 
    ok = file:write_file(Output_file,
                         lists:flatten([Header, Function_code])),
    io:format("==> Generated file ~s~n", [Output_file]),
    {ok, Functions}.


%%% ============================================================================
%%% Internal functions
%%% ============================================================================

make_functions(Module, #interface{ops = Operations, model = Model}, Headers, Options) ->
    [make_function(Module, Op, Model, Headers, Options) || Op <- Operations].

make_function(Module, #op{name = Name, in_type = In}, Model, Headers, Options) ->
    Atom_name = atom_string(Name),
    Function_name = [atom_string(Module), $:, Atom_name],
    In_value = erlsom_example_value:from_model(In, Model, [{indent_level, 2}]),
    {list_to_atom(Name), 
     [Atom_name, "() -> \n    ", Function_name, "(\n", In_value, 
        ",\n    _Soap_headers = ", term_string(Headers),
        ",\n    _Soap_options = ", term_string(Options), ").\n\n"]}. 

header(Module, Hrl_file) ->
    ["-module(", atom_string(Module), ").\n",
     "-compile(export_all).\n",
     "\n",
     "-include(\"", Hrl_file, "\").\n",
     "\n\n"].

atom_string(String) when is_list(String) ->
    Atom = list_to_atom(String),
    term_string(Atom);
atom_string(Atom) when is_atom(Atom) ->
    term_string(Atom).

term_string(Term) ->
    [Term_string] = io_lib:format("~p", [Term]),
    Term_string.
