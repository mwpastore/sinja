# frozen_string_literal: true
require_relative 'test_helper'

class HelpersApp < MyAppBase
  before do
    env['sinja.passthru'] = true # let exceptions propagate
  end

  configure_jsonapi do |c|
    %i[code body roles].each do |sym|
      c.query_params[sym] = nil
    end
  end

  post '/attributes' do
    attributes
  end

  post '/content' do
    halt(content? ? 200 : 204)
  end

  post '/data' do
    data
  end

  get '/halt' do
    halt params[:code].to_i, params[:body]
  end

  get '/normalize_params' do
    params
  end

  get('/role') {{ :role=>memoized_role.to_a }}

  get('/role_q') {{ :role_q=>role?(params[:roles].split(',')) }}

  get('/sideloaded') {{ :sideloaded=>sideloaded? }}

  get('/transaction') {{ :yielded=>transaction { 11 } }}
end

class TestHelpers < Minitest::Test
  include MyAppTest
  include Rack::Test::Methods

  def app
    HelpersApp.new
  end

  def test_allow
    pass 'tested in integration'
  end

  def test_attributes
    post '/attributes', JSON.generate(:data=>{ :attributes=>{ :foo=>'bar' } })
    assert last_response.ok?
    assert_equal({ :foo=>'bar' }, json)
  end

  def test_can
    pass 'tested in integration'
  end

  def test_content
    post '/content', JSON.generate(true)
    assert_equal 200, last_response.status
  end

  def test_no_content
    post '/content'
    assert_equal 204, last_response.status
  end

  def test_data
    post '/data', JSON.generate(:data=>{ :foo=>'bar' })
    assert last_response.ok?
    assert_equal({ :foo=>'bar' }, json)
  end

  def test_halt
    e = assert_raises(Sinja::HttpError) do
      get '/halt', :code=>418, :body=>"I'm a teapot"
    end
    assert_equal 418, e.http_status
    assert_equal "I'm a teapot", e.message
  end

  def test_halt_400
    assert_raises(Sinja::BadRequestError) do
      get '/halt', :code=>400
    end
  end

  def test_not_found
    assert_raises(Sinja::NotFoundError) do
      get '/halt', :code=>404
    end
  end

  def test_normalize_params
    get '/normalize_params'
    assert last_response.ok?
    assert_kind_of Hash, json.delete(:filter)
    assert_kind_of Hash, json.delete(:fields)
    assert_kind_of Hash, json.delete(:page)
    assert_kind_of Array, json.delete(:include)
    assert_kind_of Hash, json.delete(:sort)
    json.delete(:captures) # Sinatra 2.0 adds this to every request
    assert_empty json
  end

  def test_role
    get '/role'
    assert last_response.ok?
    assert_empty json[:role]
  end

  def test_role_q
    get '/role_q', :roles=>'any'
    assert last_response.ok?
    refute json[:role_q]
  end

  def test_sanity_check
    pass 'tested in integration'
  end

  def test_sideload
    pass 'tested in integration'
  end

  def test_sideloaded
    get '/sideloaded'
    assert last_response.ok?
    assert_equal true, json[:sideloaded]
  end

  def test_transaction
    get '/transaction'
    assert last_response.ok?
    assert_equal 11, json[:yielded]
  end
end
