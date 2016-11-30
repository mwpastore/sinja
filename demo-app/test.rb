require 'sinatra/base'

class MyApp < Sinatra::Base
  get '/raise' do
    raise Sinatra::BadRequest
  end

  get '/halt' do
    halt 400
  end

  error Sinatra::BadRequest, 400 do
    body "received error"
  end

  run!
end
