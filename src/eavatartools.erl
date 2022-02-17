%%%-------------------------------------------------------------------
%%% @author Ilya Kalashnikov <ilya.kalashnikov@redsolution.com>
%%% @copyright (C) 2022, Redsolution OÜ
%%% @doc
%%%
%%% @end
%%% Created : 14 Feb. 2022
%%%-------------------------------------------------------------------
-module(eavatartools).
-author('ilya.kalashnikov@redsolution.com').

-type file_path() :: binary() | list().
-type file_name() :: binary().
-type file_data() :: binary().

%% API
-export([make_avatar/0,merge_avatars/2]).

-define(BG_LIGHT, [
  {red, <<"#FFEBEE">>},
  {pink, <<"#FCE4EC">>},
  {purple, <<"#F3E5F5">>},
  {deeppurple, <<"#EDE7F6">>},
  {indigo, <<"#E8EAF6">>},
  {blue, <<"#E3F2FD">>},
  {lightblue, <<"#E1F5FE">>},
  {cyan, <<"#E0F7FA">>},
  {teal, <<"#E0F2F1">>},
  {green, <<"#E8F5E9">>},
  {lightgreen, <<"#F1F8E9">>},
  {lime, <<"#F9FBE7">>},
  {yellow, <<"#FFFDE7">>},
  {amber, <<"#FFF8E1">>},
  {orange, <<"#FFF3E0">>},
  {brown, <<"#FFF3E0">>},
  {grey, <<"#FFF3E0">>},
  {bluegrey, <<"#FFF3E0">>}]).
-define(BG_DARK,[
  {red900, <<"#b71c1c">>},
  {pink900, <<"#880e4f">>},
  {purple900, <<"#4a148c">>},
  {deeppurple900, <<"#311b92">>},
  {indigo900, <<"#1a237e">>},
  {blue900, <<"#0d47a1">>},
  {lightblue900, <<"#01579b">>},
  {cyan900, <<"#006064">>},
  {teal900, <<"#004d40">>},
  {green900, <<"#1b5e20">>},
  {lightgreen900, <<"#33691e">>},
  {lime900, <<"#827717">>},
  {brown900, <<"#3e2723">>},
  {grey900, <<"#212121">>},
  {bluegrey900, <<"#263238">>}]).

%% API

-spec make_avatar() -> {ok, file_name(), file_data()} | {error, any()}.
make_avatar() ->
  case get_random_image() of
    {ok, FileName, FilePath} ->
      case get_random_color() of
        error ->
          {error, nocolors};
        Color ->
          make_avatar(FileName, FilePath, Color)
      end;
    Err ->
      Err
  end.

make_avatar(FileName, FilePath, Color) ->
  ColorName = proplists:get_value(<<"name">>,Color),
  AvatarFileName = <<ColorName/binary," ", FileName/binary>>,
  Extension =  lists:last(binary:split(FileName,<<".">>,[global])),
  ColorHex = proplists:get_value(<<"hex">>,Color),
  {_,AvatarBG} = determine_bg_color(Color),
  PortCommand = binary_to_list(<<"convert '", FilePath/binary,"' -colorspace gray -fill '",ColorHex/binary,
    "' -colorize 100 -background '",AvatarBG/binary,"' -flatten ",Extension/binary,":-">>),

  %% execute as port
  PortOpts = [stream, use_stdio, exit_status, binary],
  Port = erlang:open_port({spawn, PortCommand}, PortOpts),

  Result  = case receive_until_exit(Port, []) of
              {ok, Data, 0} -> {ok, AvatarFileName, Data};
              _ -> {error, cmderror}
            end,
  case erlang:port_info(Port) of
    undefined -> ok;
    _ -> erlang:port_close(Port)
  end,
  Result.


-spec merge_avatars(file_path(), file_path()) -> {ok, file_name(), file_data()} | {error, any()}.
merge_avatars(Avatar1,Avatar2) ->
  [File1, File2] = lists:map(fun(F) ->
    if
      is_list(F) -> list_to_binary(F);
      true -> F
    end end, [Avatar1,Avatar2]),
  case filelib:is_regular(File1) of
    true ->
      case filelib:is_regular(File2) of
        true ->
          merge_checked_avatars(File1,File2);
        _ ->
          {error, 'bad_file_2'}
      end;
    _ ->
      {error, 'bad_file_1'}
  end.



merge_checked_avatars(Avatar1,Avatar2) ->
  PortCommand = binary_to_list(<<"convert \\( ",Avatar1/binary," -resize 128x128^ -gravity center -extent 128x128 -crop 64x128-16 \\) "
   "\\( ",Avatar2/binary,"  -resize 128x128^ -gravity center -extent 128x128 -crop 64x128+16 \\) "
    "+append +repage -background '#F0F0F0' -flatten  png:-">>),

  %% execute as port
  PortOpts = [stream, use_stdio, exit_status, binary],
  Port = erlang:open_port({spawn, PortCommand}, PortOpts),

  Result  = case receive_until_exit(Port, []) of
              {ok, Data, 0} ->
                RandomStr = random_string(),
                {ok, <<RandomStr/binary,".png">>, Data};
              _ -> {error, cmderror}
            end,
  case erlang:port_info(Port) of
    undefined -> ok;
    _ -> erlang:port_close(Port)
  end,
  Result.


%% Internal

get_random_image() ->
  get_random_image(code:priv_dir(?MODULE)).

get_random_image({error, Why}) -> {error, Why};
get_random_image(Dir) ->
  case file:list_dir(filename:join([Dir, "images"])) of
    {ok, []} ->
      {error,emptydir};
    {ok, Files} ->
      FileName = lists:nth(rand:uniform(length(Files)), Files),
      FullPath = list_to_binary(filename:join([Dir, "images", FileName])),
      {ok, list_to_binary(FileName), FullPath};
    Err ->
      Err
  end.

get_random_color() ->
  get_random_color(code:priv_dir(?MODULE)).

get_random_color({error, _}) -> error;
get_random_color(Dir) ->
  ColorsFile = filename:join(Dir, "colors.json"),
  case get_colors(ColorsFile) of
    {Colors} ->
      {_, {ColorProps}} = lists:nth(rand:uniform(length(Colors)), Colors),
      ColorProps;
    _ ->
      error
  end.

get_colors(File) ->
  case filelib:is_regular(File) of
    true ->
      try
        {ok, Data} = file:read_file(File),
        jiffy:decode(Data)
      catch
          _:_  -> error
      end;
    false ->
      error
  end.

receive_until_exit(Port, ReverseBuffer) ->
  receive
    {Port, {exit_status, Status}} ->
      Data = iolist_to_binary(lists:reverse(ReverseBuffer)),
      {ok, Data, Status};
    {Port, {data, Data}} ->
      receive_until_exit(Port, [Data | ReverseBuffer])
  after
    30000 ->
      {error, timeout}
  end.

%%  function to determine brightness of the color
luminance(ColorProp) ->
  [R,G,B] = proplists:get_value(<<"rgb">>,ColorProp),
  round(R*0.299 + G*0.587 + B*0.114).

%% Returns one of the background colors, light or dark, for best use with given color
determine_bg_color(ColorProp) ->
  Lum = luminance(ColorProp),
  if
    Lum > 200 ->
      lists:nth(rand:uniform(length(?BG_DARK)), ?BG_DARK);
    true ->
      lists:nth(rand:uniform(length(?BG_LIGHT)), ?BG_LIGHT)
  end.

%% random string
random_string()->
  <<U0:32, U1:16, U2:16, U3:16, U4:48>> = crypto:strong_rand_bytes(16),
  list_to_binary(
    lists:flatten(
      io_lib:format("~8.16.0b~4.16.0b~4.16.0b~4.16.0b~12.16.0b", [U0, U1, U2, U3, U4]))).
