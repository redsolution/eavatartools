rebar = /usr/lib/erlang/bin/escript rebar

all: compile

clean:
	$(rebar) clean

deps:
	$(rebar) get-deps

compile: deps
	$(rebar) compile

test:
	$(rebar) skip_deps=true eunit

.PHONY: all clean test
