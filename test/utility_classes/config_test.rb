# frozen_string_literal: true
require_relative '../test_helper'

require 'sinja/config'

class TestConfig < Minitest::Test
  def setup
    @config = Sinja::Config.new
  end

  def test_it_sets_sane_defaults
    assert_respond_to @config.error_logger, :call
    assert_kind_of Sinja::RolesConfig, @config.default_roles
    assert_kind_of Hash, @config.resource_roles
    assert_respond_to @config.resource_roles.default_proc, :call
    assert_kind_of Hash, @config.resource_sideload
    assert_respond_to @config.resource_sideload.default_proc, :call
    assert_equal Set.new, @config.conflict_exceptions
    assert_equal Set.new, @config.not_found_exceptions
    assert_equal Set.new, @config.validation_exceptions
    assert_respond_to @config.validation_formatter, :call
    assert_kind_of Hash, @config.serializer_opts
    assert_equal :generate, @config.json_generator
    assert_equal :generate, @config.json_error_generator
  end

  def test_resource_roles_default_proc
    assert_kind_of Sinja::RolesConfig, @config.resource_roles[:foos]
    assert_kind_of Sinja::RolesConfig, @config.resource_roles[:bars]
    assert_equal @config.resource_roles[:foos], @config.resource_roles[:bars]
    refute_same @config.resource_roles[:foos], @config.resource_roles[:bars]
  end

  def test_resource_sideload_default_proc
    assert_kind_of Sinja::SideloadConfig, @config.resource_sideload[:foos]
    assert_kind_of Sinja::SideloadConfig, @config.resource_sideload[:bars]
    assert_equal @config.resource_sideload[:foos], @config.resource_sideload[:bars]
    refute_same @config.resource_sideload[:foos], @config.resource_sideload[:bars]
  end

  def test_error_logger_setter
    assert_raises(RuntimeError) { @config.error_logger = :i_am_not_callable }

    lam = proc { |h| logger.error(h) }
    @config.error_logger = lam
    assert_equal lam, @config.error_logger
  end

  def test_default_roles_setter
    assert_raises SystemExit do
      capture_io { @config.default_roles = { :i_am_not_valid=>:foo } }
    end

    roles = { :create=>:admin, :update=>:user }
    @config.default_roles = roles
    assert_equal Sinja::Roles[:admin], @config.default_roles[:create]
    assert_equal Sinja::Roles[:user], @config.default_roles[:update]
    assert_equal Sinja::Roles.new, @config.default_roles[:destroy]
  end

  def test_conflict_exceptions_setter
    @config.conflict_exceptions = [:c]
    @config.conflict_exceptions = [:a, :a, :b]
    assert_equal Set[:a, :b], @config.conflict_exceptions
  end

  def test_not_found_exceptions_setter
    @config.not_found_exceptions = [:c]
    @config.not_found_exceptions = [:a, :a, :b]
    assert_equal Set[:a, :b], @config.not_found_exceptions
  end

  def test_validation_exceptions_setter
    @config.validation_exceptions = [:c]
    @config.validation_exceptions = [:a, :a, :b]
    assert_equal Set[:a, :b], @config.validation_exceptions
  end

  def test_validation_formatter_setter
    assert_raises(RuntimeError) { @config.validation_formatter = :i_am_not_callable }

    lam = proc { [[:a, 1]] }
    @config.validation_formatter = lam
    assert_equal lam, @config.validation_formatter
  end

  def test_serializer_opts_setter
    default = @config.serializer_opts[:jsonapi]
    @config.serializer_opts = { :meta=>{ :what=>1 } }
    assert_equal({ :what=>1 }, @config.serializer_opts[:meta])
    assert_equal default, @config.serializer_opts[:jsonapi]
  end

  def test_json_generator_setter
    @config.json_generator = :fast_generate
    assert_equal :fast_generate, @config.json_generator
  end

  def test_it_freezes_deeply
    @config.freeze

    assert_predicate @config.error_logger, :frozen?
    assert_predicate @config.default_roles, :frozen?
    assert_predicate @config.resource_roles, :frozen?
    assert_nil @config.resource_roles.default_proc
    assert_predicate @config.resource_sideload, :frozen?
    assert_nil @config.resource_sideload.default_proc
    assert_predicate @config.conflict_exceptions, :frozen?
    assert_predicate @config.not_found_exceptions, :frozen?
    assert_predicate @config.validation_exceptions, :frozen?
    assert_predicate @config.validation_formatter, :frozen?
    assert_predicate @config.serializer_opts, :frozen?
    assert_predicate @config.instance_variable_get(:@opts), :frozen?
  end
end
