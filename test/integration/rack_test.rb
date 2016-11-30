# frozen_string_literal: true
require_relative 'test_helper'
require_relative '../../demo-app/app'

# Munson doesn't support error-handling (yet) so let's poke at the demo app
# until it breaks and examine the pieces.

class DemoAppTest1 < Minitest::Test
  include MyAppTest
  include Rack::Test::Methods

  def app
    Sinatra::Application.new
  end

  def test_it_passes_accept_header
    head '/'
    assert_error 404
  end

  def test_it_fails_accept_header
    header 'Accept', 'application/json'
    get '/'
    assert_error 406
  end

  def test_it_fails_content_type_header
    header 'Content-Type', 'application/json'
    post '/comments', JSON.generate(:data=>{ :type=>'comments' })
    assert_error 415
  end

  def test_it_denies_access
    post '/comments', JSON.generate(:data=>{ :type=>'comments' })
    assert_error 403
  end

  def test_it_sanity_checks_create
    post '/authors', JSON.generate(:data=>{ :type=>'bea_arthurs' })
    assert_error 409
  end

  def test_it_sanity_checks_update
    login 'all@yourbase.com'
    patch '/authors/1', JSON.generate(:data=>{ :type=>'authors', :id=>11 })
    assert_error 409
  end

  def test_it_handles_malformed_json
    post '/authors', '{"foo":}}'
    assert_error 400
  end

  def test_it_handles_missing_routes
    get '/teapots'
    assert_error 404
  end

  def test_it_handles_missing_resources
    get '/authors/8675309'
    assert_error 404
  end

  def test_it_handles_unimplemented_routes
    get '/comments'
    assert_error 405
  end

  def test_it_handles_empty_collections
    get '/posts'
    assert_ok
    assert_empty json[:data]
  end

  def test_it_returns_a_resource
    get '/authors/1'
    assert_ok
    assert_equal 'authors', json[:data][:type]
    assert_equal '1', json[:data][:id]
  end

  def test_it_returns_a_collection
    get '/authors'
    assert_ok
    assert_equal 'authors', json[:data].first[:type]
    assert_equal '1', json[:data].first[:id]
  end

  def test_it_returns_linkage_for_restricted_relationship
    get '/authors/1/relationships/comments'
    assert_ok
    assert_equal '/authors/1/comments', json[:links][:related]
  end

  def test_it_denies_access_to_restricted_relationship
    get '/authors/1/comments'
    assert_error 403
  end

  def test_it_returns_related_objects
    get '/authors/1/posts'
    assert_ok
    assert_kind_of Array, json[:data]
  end

  def test_it_handles_relationships_for_missing_resources
    get '/authors/8675309/relationships/posts'
    assert_error 404
  end

  def test_it_handles_missing_relationships_for_resources
    get '/authors/1/relationships/teapots'
    assert_error 404
  end

  def test_it_handles_related_for_missing_resources
    get '/authors/8675309/posts'
    assert_error 404
  end

  def test_it_handles_missing_related_for_resources
    get '/authors/1/teapots'
    assert_error 404
  end

  def test_head_for_a_collection
    head '/authors'
    assert_ok
    assert_equal 'GET,POST', last_response.headers['Allow']
  end

  def test_head_for_a_resource
    head '/authors/1'
    assert_ok
    assert_equal 'GET,PATCH,DELETE', last_response.headers['Allow']
  end

  def test_head_for_related
    head '/authors/1/posts'
    assert_ok
    assert_equal 'GET', last_response.headers['Allow']
  end

  def test_head_for_relationship
    head '/authors/1/relationships/posts'
    assert_ok
    assert_equal 'GET', last_response.headers['Allow']
  end
end
