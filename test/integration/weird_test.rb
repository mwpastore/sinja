# frozen_string_literal: true
require_relative 'test_helper'

class MyWeirdApp < Sinatra::Base
  register Sinja

  get '/' do
    not_found
  end

  resource :foos do
    get '/bar' do
      content_type :text
      'hello'
    end
  end
end

class MyWeirdAppTest < Minitest::Test
  include MyAppTest
  include Rack::Test::Methods

  def app
    MyWeirdApp.new
  end

  def test_not_found
    get '/'
    assert_error 404
  end

  def test_custom_route
    get '/foos/bar'
    assert last_response.ok?
    assert_equal 'hello', last_response.body
    assert_match %r{^text/plain}, last_response['Content-Type']
  end
end
