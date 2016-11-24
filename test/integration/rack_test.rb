# frozen_string_literal: true
require_relative 'test_helper'
require_relative '../helpers/test_helper'
require_relative '../../demo-app/app'

# Munson doesn't support error-handling (yet) so let's poke at the demo app
# until it breaks and examine the pieces.

class DemoAppTest1 < MyAppTest
  def app
    Sinatra::Application.new
  end

  def before_all
    super
    # foo
  end

  def after_all
    # bar
    super
  end

  def assert_error(status)
    assert_equal status, last_response.status
    refute_empty json[:errors]
    assert_equal status, json[:errors].first[:status].to_i
  end

  def test_it_passes_accept_header
    get '/'
    last_response.ok?
  end

  def test_it_fails_accept_header
    header 'Accept', 'application/json'
    get '/'
    assert_error 406
  end

  def test_it_fails_content_type_header
    header 'Content-Type', 'application/json'
    post '/comments', JSON.generate({ :data=>{ :type=>'comments' } })
    assert_error 415
  end

  def test_it_denies_access
    post '/comments', JSON.generate({ :data=>{ :type=>'comments' } })
    assert_error 403
  end

  def test_it_sanity_checks_create
    post '/authors', JSON.generate({ :data=>{ :type=>'bea_arthurs' } })
    assert_error 409
  end

  def test_it_sanity_checks_update
    patch '/authors/1', JSON.generate({ :data=>{ :type=>'authors', :id=>11 } })
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
    assert last_response.ok?
    assert_empty json[:data]
  end

  def test_it_returns_resources
    get '/authors/1'
    assert last_response.ok?
    assert_equal 'authors', json[:data][:type]
    assert_equal '1', json[:data][:id]
  end

  def test_it_returns_collections
    get '/authors'
    assert last_response.ok?
    assert_equal 'authors', json[:data].first[:type]
    assert_equal '1', json[:data].first[:id]
  end

  def test_it_returns_linkage_for_restricted_relationship
    get '/authors/1/relationships/comments'
    assert last_response.ok?
    assert_equal '/authors/1/comments', json[:links][:related]
  end

  def test_it_denies_access_to_restricted_relationship
    get '/authors/1/comments'
    assert_error 403
  end

  def test_it_returns_relationships
    get '/authors/1/posts'
    assert last_response.ok?
    # TODO: Left off here...
  end
end
