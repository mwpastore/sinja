# frozen_string_literal: true
require_relative '../test_helper'

require 'sinja/config'

class TestSideloadConfig < Minitest::Test
  def setup
    @config = Sinja::SideloadConfig.new
  end

  def test_it_inits_and_delegates
    assert_kind_of Set, @config[:graft]
    assert_empty @config[:graft]
    assert_nil @config[:unknown]
  end
end

class TestSideloadConfig1 < Minitest::Test
  def setup
    @config = Sinja::SideloadConfig.new
    @config.merge!(:graft=>:update)
    @config.merge!(:graft=>:create)
  end

  def test_it_inits_and_delegates
    assert_kind_of Set, @config[:graft]
    assert_equal [:create], @config[:graft].to_a
  end

  def test_it_whitelists_keys
    assert_raises SystemExit do
      capture_io { @config.merge!(:ignore_me=>:create) }
    end
  end
end

class TestSideloadConfig2 < Minitest::Test
  def setup
    @config = Sinja::SideloadConfig.new.freeze
  end

  def test_it_freezes_deeply
    assert_raises(RuntimeError) { @config.merge!(:graft=>:create) }
  end
end
