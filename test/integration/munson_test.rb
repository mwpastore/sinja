# frozen_string_literal: true
require_relative 'test_helper'
require_relative 'test_client'

class DemoAppTest < SequelTest
  def before_all
    super
    # foo
  end

  def after_all
    # bar
    super
  end

  def test_it_checks_accept_header
    posts = TestClient::Post.fetch
    refute posts.any?
  end

  def test_it_checks_content_type_header
    post = TestClient::Post.new
    refute post.id
  end
end
