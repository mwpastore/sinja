# frozen_string_literal: true
require_relative '../test_helper'

require 'sinatra/base'
require 'sinja/config'

class TestRoles < Minitest::Test
  def setup
    @roles = Sinja::Roles[:a, :a, :b]
  end

  def test_it_is_setlike
    assert_equal [:a, :b], @roles.to_a
  end

  def test_it_is_switchable
    assert_respond_to @roles, :===
    assert_operator @roles, :===, :a
    assert_operator @roles, :===, [:a, :b]
    refute_operator @roles, :===, :c
  end
end
