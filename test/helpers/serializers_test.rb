# frozen_string_literal: true
require_relative 'test_helper'

class SerializersApp < MyAppBase
  before do
    env['sinja.passthru'] = true # let exceptions propagate
  end

  get '/dasherize' do
    res = dasherize(params.fetch('str') { params.fetch('sym').to_sym })
    { :class_name=>res.class.name, :output=>res }
  end

  get '/dedasherize' do
    res = dedasherize(params.fetch('str') { params.fetch('sym').to_sym })
    { :class_name=>res.class.name, :output=>res }
  end

  post '/dedasherize_names' do
    dedasherize_names(deserialize_request_body)
  end

  get '/include_exclude' do
    opts = {
      :include=>params.delete('_include'),
      :exclude=>params.delete('_exclude')
    }

    include_exclude!(opts)
  end

  post '/serialize_model' do
    serialize_model?(*deserialize_request_body.values_at(:model, :options))
  end

  post '/serialize_models' do
    serialize_models?(*deserialize_request_body.values_at(:models, :options))
  end

  post '/serialize_linkage' do
    serialize_linkage?(false, deserialize_request_body[:options])
  end

  post '/serialize_linkages' do
    serialize_linkages?(false, deserialize_request_body[:options])
  end

  post '/error_hash' do
    error_hash(deserialize_request_body)
  end
end

class TestSerializers < MyAppTest
  def app
    SerializersApp.new
  end

  def test_dasherize
    get '/dasherize', :str=>"hello_world"
    assert last_response.ok?
    assert_equal 'String', json[:class_name]
    assert_equal 'hello-world', json[:output]
  end

  def test_dasherize_sym
    get '/dasherize', :sym=>"hello_world"
    assert last_response.ok?
    assert_equal 'Symbol', json[:class_name]
    assert_equal 'hello-world', json[:output]
  end

  def test_dedasherize
    get '/dedasherize', :str=>"hello-world"
    assert last_response.ok?
    assert_equal 'String', json[:class_name]
    assert_equal 'hello_world', json[:output]
  end

  def test_dedasherize_sym
    get '/dedasherize', :sym=>"hello-world"
    assert last_response.ok?
    assert_equal 'Symbol', json[:class_name]
    assert_equal 'hello_world', json[:output]
  end

  def test_dedasherize_names
    post '/dedasherize_names', JSON.generate('foo-bar'=>{'bar-qux'=>{'qux-frob'=>11}})
    assert last_response.ok?
    assert_equal 11, json.dig(:foo_bar, :bar_qux, :qux_frob)
  end

  def test_deserialize_request_body
    pass 'tested implicitly'
  end

  def test_serialize_response_body
    pass 'tested implicitly'
  end

  def test_include_exclude_none
    get '/include_exclude'
    assert last_response.ok?
    assert_empty json
  end

  def test_include_exclude_default
    get '/include_exclude', :_include=>'foo,bar'
    assert last_response.ok?
    assert_equal %w[foo bar], json
  end

  def test_include_exclude_param
    get '/include_exclude', :_include=>'foo,bar', :include=>'bar,qux'
    assert last_response.ok?
    assert_equal %w[foo bar qux], json
  end

  def test_include_exclude_full
    get '/include_exclude', :_exclude=>'qux', :include=>'bar,qux'
    assert last_response.ok?
    assert_equal %w[bar], json
  end

  def test_include_exclude_partial
    get '/include_exclude', :_exclude=>'bar,qux.foos', :include=>'bar,qux,qux.foos.bar'
    assert last_response.ok?
    assert_equal %w[qux], json
  end

  def test_serialize_model
    pass 'tested in integration'
  end

  def test_serialize_model_meta
    post '/serialize_model', JSON.generate(:options=>{ :meta=>{ :foo=>'bar' } })
    assert last_response.ok?
    assert_equal({ :foo=>'bar' }, json[:meta])
  end

  def test_serialize_model_no_content
    post '/serialize_model', JSON.generate(:options=>{})
    assert_equal 204, last_response.status
    assert_empty last_response.body
  end

  def test_serialize_models
    pass 'tested in integration'
  end

  def test_serialize_models_meta
    post '/serialize_models', JSON.generate(:models=>[], :options=>{ :meta=>{ :foo=>'bar' } })
    assert last_response.ok?
    assert_equal({ :foo=>'bar' }, json[:meta])
  end

  def test_serialize_models_no_content
    post '/serialize_models', JSON.generate(:models=>[], :options=>{})
    assert_equal 204, last_response.status
    assert_empty last_response.body
  end

  def test_serialize_linkage
    pass 'tested in integration'
  end

  def test_serialize_linkage_meta
    post '/serialize_linkage', JSON.generate(:options=>{ :meta=>{ :foo=>'bar' } })
    assert last_response.ok?
    assert_equal({ :foo=>'bar' }, json[:meta])
  end

  def test_serialize_linkages_meta
    post '/serialize_linkages', JSON.generate(:options=>{ :meta=>{ :foo=>'bar' } })
    assert last_response.ok?
    assert_equal({ :foo=>'bar' }, json[:meta])
  end

  def test_error_hash
    post '/error_hash', JSON.generate({})
    assert last_response.ok?
    assert_equal 1, json.length
    assert_equal [:id, :status], json.first.keys
    assert_match %r{[a-z0-9-]{10,}}, json.first[:id]
    assert_equal '200', json.first[:status]
  end

  def test_error_hash_keywords
    post '/error_hash', JSON.generate(:detail=>'foo bar')
    assert last_response.ok?
    assert_equal 1, json.length
    assert_equal [:id, :detail, :status], json.first.keys
    assert_match %r{[\w-]{10,}}, json.first[:id]
    assert_equal '200', json.first[:status]
    assert_equal 'foo bar', json.first[:detail]

    assert_raises ArgumentError do
      post '/error_hash', JSON.generate(:nonsense=>'ignore')
    end
  end

  def test_serialize_errors
    pass 'tested in integration'
  end
end
