# frozen_string_literal: true
require_relative '../test_helper'
require 'minitest/hooks/test'

class SequelTest < Minitest::Test
  include Minitest::Hooks

  def around
    Sequel::Model.db.transaction(:rollback=>:always, :savepoint=>true, :auto_savepoint=>true) { super }
  end

  def around_all
    Sequel::Model.db.transaction(:rollback=>:always) { super }
  end
end
