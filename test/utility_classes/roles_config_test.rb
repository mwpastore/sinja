# frozen_string_literal: true
require_relative '../test_helper'

require 'sinja/config'

class TestRolesConfig < Minitest::Test
  def setup
    @config = Sinja::RolesConfig.new
  end

  def test_it_inits_and_delegates
    assert_kind_of Sinja::Roles, @config[:create]
    assert_empty @config[:create]
    assert_nil @config[:unknown]
  end
end

class TestRolesConfig1 < Minitest::Test
  def setup
    @config = Sinja::RolesConfig.new
    @config.merge!(:create=>:update)
    @config.merge!(:create=>:admin)
  end

  def test_it_inits_and_delegates
    assert_kind_of Sinja::Roles, @config[:create]
    assert_equal [:admin], @config[:create].to_a
  end

  def test_it_whitelists_keys
    assert_raises SystemExit do
      capture_io { @config.merge!(:ignore_me=>:admin) }
    end
  end

  def test_it_copies_deeply
    @other = @config.dup
    assert_equal @config[:create], @other[:create]
    refute_same @config[:create], @other[:create]
  end
end

class TestRolesConfig2 < Minitest::Test
  def setup
    @config = Sinja::RolesConfig.new.freeze
  end

  def test_it_freezes_deeply
    assert_raises(RuntimeError) { @config.merge!(:create=>:admin) }
  end
end
