rebar = /usr/lib/erlang/bin/escript rebar

all: compile

clean:
	$(rebar) clean

avatartools: get_tools copy_files

get_tools:
	@echo "Getting images and colors"
	@if [ ! -d  deps ]; then (mkdir deps); fi
	@cd deps; if [ ! -d  avatartools ]; then (git clone https://github.com/redsolution/avatartools.git); fi

copy_files:
	@cd deps/avatartools && git checkout -q master
	@if [ ! -d  priv ]; then (mkdir priv); fi
	@cp -r deps/avatartools/images priv/
	@cp  deps/avatartools/colors.json priv/colors.json

deps:
	$(rebar) get-deps

compile: deps avatartools
	$(rebar) compile

test:
	$(rebar) skip_deps=true eunit

.PHONY: all clean test
