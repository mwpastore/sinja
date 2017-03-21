#!/bin/bash

set -eou pipefail

port=3333
posts=100

echo "Starting Rack..."
pushd ../demo-app
APP_ENV=test bundle exec ruby app.rb -p $port -e test -q &
ruby_pid=$!
popd
echo "Done."

function cleanup {
  kill $ruby_pid
  wait $ruby_pid
}
trap cleanup EXIT

sleep 15
echo "Generating Posts..."
./generate-posts -count=$posts -url="http://0.0.0.0:$port/posts"
echo "Done."

sleep 15
ab -n 10000 -c 1 -k -H 'Accept: application/vnd.api+json' \
  "http://0.0.0.0:$port/authors/1/posts?page[size]=5&page[number]=3&page[record-count]=$posts&include=tags"
