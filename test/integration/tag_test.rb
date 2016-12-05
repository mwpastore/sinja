# frozen_string_literal: true
require_relative 'test_helper'
require_relative '../../demo-app/app'

class PostTest < SequelTest
  include MyAppTest
  include Rack::Test::Methods

  def app
    Sinatra::Application.dump_errors = true
    Sinatra::Application.new
  end

  def test_uncoalesced_find_head
    head '/tags'
    assert_ok
    assert_equal 'GET,POST', last_response.headers['Allow']
  end

  def test_uncoalesced_find
    DB[:tags].multi_insert [
      { :name=>'teapots' },
      { :name=>'sassafrass' },
      { :name=>'whimsy' },
      { :name=>'horseshoe' }
    ]
    get '/tags'
    assert_ok
    vals = json[:data].map { |t| { :id=>t[:id].to_i, :name=>t[:attributes][:name] } }
    assert_equal DB[:tags].all, vals
  end

  def test_coalesced_find_head
    head '/tags?filter[id]=1,2'
    assert_ok
    assert_equal 'GET', last_response.headers['Allow']
  end

  def test_coalesced_find
    DB[:tags].multi_insert [
      { :name=>'teapots' },
      { :name=>'sassafrass' },
      { :name=>'whimsy' },
      { :name=>'horseshoe' }
    ]
    get '/tags?filter[id]=2,3'
    assert_ok
    vals = json[:data].map { |t| { :id=>t[:id].to_i, :name=>t[:attributes][:name] } }
    assert_equal DB[:tags].where(:id=>[2, 3]).all, vals
  end

  def test_sort_denied
    get '/tags?sort=id'
    assert_error 400
  end

  def test_sort
    DB[:tags].multi_insert [
      { :name=>'teapots' },
      { :name=>'sassafrass' },
      { :name=>'whimsy' },
      { :name=>'horseshoe' }
    ]
    get '/tags?sort=-name'
    assert_ok
    assert_equal 'whimsy', json[:data].first[:attributes][:name]
    assert_equal 'horseshoe', json[:data].last[:attributes][:name]
  end

  def test_filter_denied
    get '/tags?filter[foo]=bar'
    assert_error 400
  end

  def test_filter
    DB[:tags].multi_insert [
      { :name=>'teapots' },
      { :name=>'sassafrass' },
      { :name=>'whimsy' },
      { :name=>'horseshoe' }
    ]
    get '/tags?filter[name]=sassafrass'
    assert_ok
    assert_equal DB[:tags].first(:name=>'sassafrass')[:id], json[:data].first[:id].to_i
    assert_equal 1, json[:data].length
  end

  def test_page_denied
    get '/tags?page[offset]=100'
    assert_error 400
  end

  def test_page
    DB[:tags].multi_insert [
      { :name=>'teapots' },
      { :name=>'sassafrass' },
      { :name=>'whimsy' },
      { :name=>'horseshoe' }
    ]

    get '/tags?page[size]=1&sort=name'
    assert_ok
    assert_equal 1, json[:data].length
    assert_equal 4, json[:data].first[:id].to_i

    get json[:links][:next]
    assert_ok
    assert_equal 1, json[:data].length
    assert_equal 2, json[:data].first[:id].to_i

    get json[:links][:last]
    assert_ok
    assert_equal 1, json[:data].length
    assert_equal 3, json[:data].first[:id].to_i
  end
end
