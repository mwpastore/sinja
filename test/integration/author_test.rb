# frozen_string_literal: true
require_relative 'test_helper'
require_relative '../../demo-app/app'

class AuthorTest < SequelTest
  include MyAppTest
  include Rack::Test::Methods

  def app
    Sinatra::Application.new
  end

  def test_register
    id = register 'foo@example.com', 'Foo Bar'
    assert_ok
    refute_nil id
    assert_equal 'Anonymous Coward', json[:data][:attributes][:'display-name']

    author = DB[:authors].first(:id=>id)
    refute_nil author
    assert_nil author[:display_name]
    assert_equal 'Foo Bar', author[:real_name]
    assert_equal 'foo@example.com', author[:email]
    refute author[:admin]
  end

  def test_show
    id = register 'foo@example.com', 'Foo Bar'
    get "/authors/#{id}"
    assert_ok
  end

  def test_index
    id1 = register 'foo@example.com', 'Foo Bar'
    id2 = register 'bar@example.com', 'Bar Qux'
    get '/authors'
    assert_ok
    assert json[:data].any? { |d| d[:type] == 'authors' && d[:id] == id1 }
    assert json[:data].any? { |d| d[:type] == 'authors' && d[:id] == id2 }
  end

  def test_destroy_self
    id = register 'foo@example.com', 'Foo Bar'
    login 'foo@example.com'
    delete "/authors/#{id}"
    assert_equal 204, last_response.status
    assert_nil DB[:authors].first(:id=>id)
  end

  def test_superuser_destroy
    id = register 'foo@example.com', 'Foo Bar'
    login 'all@yourbase.com'
    delete "/authors/#{id}"
    assert_equal 204, last_response.status
    assert_nil DB[:authors].first(:id=>id)
  end

  def test_update_self
    id = register 'foo@example.com', 'Foo Bar'
    login 'foo@example.com'
    patch "/authors/#{id}", JSON.generate(data: { type: 'authors', id: id, attributes: {
      admin: true,
      'real-name': 'Bar Qux Foo',
      'display-name': 'Bar Qux'
    }})
    assert_ok
    assert_equal 'Bar Qux', json[:data][:attributes][:'display-name']

    author = DB[:authors].first(:id=>id)
    refute_nil author
    assert_equal 'Bar Qux', author[:display_name]
    assert_equal 'Bar Qux Foo', author[:real_name]
    assert_equal 'foo@example.com', author[:email]
    refute author[:admin]
  end

  def test_superuser_update
    id = register 'foo@example.com', 'Foo Bar'
    login 'all@yourbase.com'
    patch "/authors/#{id}", JSON.generate(data: { type: 'authors', id: id, attributes: {
      admin: true
    }})
    assert_ok

    author = DB[:authors].first(:id=>id)
    refute_nil author
    assert author[:admin]
  end

  def prep_posts_comments
    author_id = register 'foo@example.com', 'Foo Bar'
    post_slug = 'foo-post'
    DB[:posts].insert \
      slug: post_slug,
      author_id: author_id,
      title: 'I am a little teapot',
      body: 'short and stout!'
    comment_id = DB[:comments].insert \
      author_id: author_id,
      post_slug: post_slug,
      body: 'you are no teapot'

    [author_id, post_slug, comment_id]
  end

  def test_related_posts
    author, post, _ = prep_posts_comments
    get "/authors/#{author}/posts"
    assert_ok
    assert json[:data].any? { |d| d[:type] == 'posts' && d[:id] == post && d[:attributes] }
  end

  def test_posts_relationship
    author, post, _ = prep_posts_comments
    get "/authors/#{author}/relationships/posts"
    assert_ok
    assert json[:data].any? { |d| d[:type] == 'posts' && d[:id] == post && !d[:attributes] }
  end

  def test_related_comments_forbidden
    author, * = prep_posts_comments
    get "/authors/#{author}/comments"
    assert_error 403
  end

  def test_related_comments_allowed
    author, _, comment = prep_posts_comments
    login 'foo@example.com'
    get "/authors/#{author}/comments"
    assert_ok
    assert json[:data].any? { |d| d[:type] == 'comments' && d[:id] == comment.to_s && d[:attributes] }
  end

  def test_comments_relationship
    author, _, comment = prep_posts_comments
    get "/authors/#{author}/relationships/comments"
    assert_ok
    assert json[:data].any? { |d| d[:type] == 'comments' && d[:id] == comment.to_s && !d[:attributes] }
  end

  def test_no_sideunload
    author, post, comment = prep_posts_comments
    get "/authors/#{author}"
    assert_ok
    refute json[:included].any? { |d| d[:type] == 'posts' && d[:id] == post }
    refute json[:included].any? { |d| d[:type] == 'comments' && d[:id] == comment.to_s }
  end

  def test_sideunload_forbidden
    author, post, comment = prep_posts_comments
    get "/authors/#{author}", include: 'comments,posts'
    assert_ok
    assert json[:included].any? { |d| d[:type] == 'posts' && d[:id] == post }
    refute json[:included].any? { |d| d[:type] == 'comments' && d[:id] == comment.to_s }
  end

  def test_sideunload_allowed
    login 'foo@example.com'
    author, post, comment = prep_posts_comments
    get "/authors/#{author}", include: 'comments,posts'
    assert_ok
    assert json[:included].any? { |d| d[:type] == 'posts' && d[:id] == post }
    assert json[:included].any? { |d| d[:type] == 'comments' && d[:id] == comment.to_s }
  end
end
