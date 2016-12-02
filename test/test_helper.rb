# frozen_string_literal: true
ENV['RACK_ENV'] = ENV['APP_ENV'] = 'test'

require 'bundler/setup'
require 'json'
require 'minitest/autorun'
require 'rack/test'
require 'sinja'

module MyAppTest
  def setup
    header 'Accept', Sinja::MIME_TYPE
    header 'Content-Type', Sinja::MIME_TYPE
  end

  def register(email, real_name, display_name=nil)
    attr = {
      :email=>email,
      'real-name'=>real_name
    }.tap do |h|
      h[:'display-name'] = display_name if display_name
    end

    post '/authors', JSON.generate(:data=>{ :type=>'authors', :attributes=>attr })
    json.dig(:data, :id)
  end

  def login(email)
    header 'X-Email', email
  end

  def json
    @json ||= {}
    @json[last_request.request_method] ||= {}
    @json[last_request.request_method][last_request.path] ||=
      if last_response.body.size > 0
        JSON.parse(last_response.body, :symbolize_names=>true)
      else
        {}
      end
  end

  def assert_ok
    assert last_response.ok? || last_response.created?
    assert_equal Sinja::MIME_TYPE, last_response.content_type
    unless last_request.head?
      assert_equal({ :version=>'1.0' }, json[:jsonapi])
    end
  end

  def assert_error(status, re=nil)
    assert_equal status, last_response.status
    assert_equal Sinja::MIME_TYPE, last_response.content_type
    unless last_request.head?
      assert_kind_of Array, json[:errors]
      refute_empty json[:errors]
      assert_equal status, json[:errors].first[:status].to_i
      assert_match re, json[:errors].first[:detail] if re
    end
  end
end
