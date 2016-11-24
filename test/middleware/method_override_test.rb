# frozen_string_literal: true
require_relative '../test_helper'

require 'rack/test'
require 'sinatra/base'
require 'sinja/method_override'

class MyApp < Sinatra::Base
  use Sinja::MethodOverride

  %i[get post patch].each do |meth|
    send(meth, '/') { "#{meth} called" }
  end
end

class TestMyApp < Minitest::Test
  include Rack::Test::Methods

  def app
    MyApp.new
  end

  def test_normal_post
    post '/'
    assert last_response.ok?
    assert_match %r{post}, last_response.body
  end

  def test_normal_patch
    patch '/'
    assert last_response.ok?
    assert_match %r{patch}, last_response.body
  end

  def test_post_to_patch
    header 'x-http-method-override', 'patch'.dup
    post '/'
    assert last_response.ok?
    assert_match %r{patch}, last_response.body
  end

  def test_ignore_post_to_get
    header 'x-http-method-override', 'get'.dup
    post '/'
    assert last_response.ok?
    assert_match %r{post}, last_response.body
  end

  def test_ignore_get_to_patch
    header 'x-http-method-override', 'patch'.dup
    get '/'
    assert last_response.ok?
    assert_match %r{get}, last_response.body
  end
end
