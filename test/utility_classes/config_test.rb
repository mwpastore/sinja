# frozen_string_literal: true
require_relative '../test_helper'

require 'sinja/config'

class TestConfig < Minitest::Test
  def setup
    @config = Sinja::Config.new
  end

  def test_it_sets_sane_defaults
    assert_kind_of Hash, @config.query_params
    assert_respond_to @config.error_logger, :call

    assert_kind_of Sinja::RolesConfig, @config.default_roles
    assert_kind_of Sinja::RolesConfig, @config.default_has_many_roles
    assert_kind_of Sinja::RolesConfig, @config.default_has_one_roles

    assert_kind_of Hash, @config.resource_config
    assert_respond_to @config.resource_config.default_proc, :call

    assert_kind_of Set, @config.conflict_exceptions
    assert_kind_of Set, @config.not_found_exceptions
    assert_kind_of Set, @config.validation_exceptions
    assert_respond_to @config.validation_formatter, :call

    assert_kind_of Hash, @config.page_using
    assert_kind_of Hash, @config.serializer_opts

    assert_equal :generate, @config.json_generator
    assert_equal :generate, @config.json_error_generator
  end

  def test_resource_config_default_procs
    @config.default_roles = { :index=>:foo }
    @config.default_has_many_roles = { :fetch=>:bar }
    @config.default_has_one_roles = { :pluck=>:qux }

    assert_equal Sinja::Roles[:foo], @config.resource_config[:foos][:resource][:index][:roles]
    assert_equal Sinja::Roles[:bar], @config.resource_config[:foos][:has_many][:bars][:fetch][:roles]
    assert_equal Sinja::Roles[:qux], @config.resource_config[:foos][:has_one][:qux][:pluck][:roles]

    assert_kind_of Sinja::Roles, @config.resource_config[:bars][:resource][:index][:roles]
    assert_kind_of Sinja::Roles, @config.resource_config[:bars][:has_many][:bars][:fetch][:roles]
    assert_kind_of Sinja::Roles, @config.resource_config[:bars][:has_one][:qux][:pluck][:roles]

    assert_equal @config.resource_config[:foos],
      @config.resource_config[:bars]
    refute_same @config.resource_config[:foos],
      @config.resource_config[:bars]

    assert_equal @config.resource_config[:foos][:resource],
      @config.resource_config[:bars][:resource]
    refute_same @config.resource_config[:foos][:resource],
      @config.resource_config[:bars][:resource]

    assert_equal @config.resource_config[:foos][:resource][:index],
      @config.resource_config[:bars][:resource][:index]
    refute_same @config.resource_config[:foos][:resource][:index],
      @config.resource_config[:bars][:resource][:index]

    assert_equal @config.resource_config[:foos][:resource][:index][:roles],
      @config.resource_config[:bars][:resource][:index][:roles]
    refute_same @config.resource_config[:foos][:resource][:index][:roles],
      @config.resource_config[:bars][:resource][:index][:roles]

    assert_equal @config.resource_config[:foos][:resource][:index][:sideload_on],
      @config.resource_config[:bars][:resource][:index][:sideload_on]
    refute_same @config.resource_config[:foos][:resource][:index][:sideload_on],
      @config.resource_config[:bars][:resource][:index][:sideload_on]

    assert_equal @config.resource_config[:foos][:resource][:index][:filter_by],
      @config.resource_config[:bars][:resource][:index][:filter_by]
    refute_same @config.resource_config[:foos][:resource][:index][:filter_by],
      @config.resource_config[:bars][:resource][:index][:filter_by]

    assert_equal @config.resource_config[:foos][:resource][:index][:sort_by],
      @config.resource_config[:bars][:resource][:index][:sort_by]
    refute_same @config.resource_config[:foos][:resource][:index][:sort_by],
      @config.resource_config[:bars][:resource][:index][:sort_by]
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

  def test_default_has_many_roles_setter
    assert_raises SystemExit do
      capture_io { @config.default_has_many_roles = { :i_am_not_valid=>:foo } }
    end

    roles = { :clear=>:admin, :merge=>:user }
    @config.default_has_many_roles = roles
    assert_equal Sinja::Roles[:admin], @config.default_has_many_roles[:clear]
    assert_equal Sinja::Roles[:user], @config.default_has_many_roles[:merge]
    assert_equal Sinja::Roles.new, @config.default_has_many_roles[:subtract]
  end

  def test_default_has_one_roles_setter
    assert_raises SystemExit do
      capture_io { @config.default_has_one_roles = { :i_am_not_valid=>:foo } }
    end

    roles = { :prune=>:admin, :graft=>:user }
    @config.default_has_one_roles = roles
    assert_equal Sinja::Roles[:admin], @config.default_has_one_roles[:prune]
    assert_equal Sinja::Roles[:user], @config.default_has_one_roles[:graft]
    assert_equal Sinja::Roles.new, @config.default_has_one_roles[:pluck]
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

  def test_page_using
    @config.page_using = { :c=>3 }
    @config.page_using = { :a=>1, :b=>2 }
    assert_equal({ :a=>1, :b=>2 }, @config.page_using)
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

    assert_predicate @config.query_params, :frozen?
    assert_predicate @config.error_logger, :frozen?

    assert_predicate @config.default_roles, :frozen?
    assert_predicate @config.default_has_one_roles, :frozen?
    assert_predicate @config.default_has_many_roles, :frozen?

    assert_predicate @config.resource_config, :frozen?
    assert_nil @config.resource_config.default_proc

    assert_predicate @config.conflict_exceptions, :frozen?
    assert_predicate @config.not_found_exceptions, :frozen?
    assert_predicate @config.validation_exceptions, :frozen?
    assert_predicate @config.validation_formatter, :frozen?

    assert_predicate @config.page_using, :frozen?
    assert_predicate @config.serializer_opts, :frozen?

    assert_predicate @config.instance_variable_get(:@opts), :frozen?
  end

  def test_it_freezes_resource_config_deeply
    assert_kind_of Sinja::Roles, @config.resource_config[:foos][:resource][:index][:roles]
    assert_kind_of Sinja::Roles, @config.resource_config[:foos][:has_many][:bars][:fetch][:roles]
    assert_kind_of Set, @config.resource_config[:foos][:has_many][:bars][:fetch][:sideload_on]
    assert_kind_of Set, @config.resource_config[:foos][:has_many][:bars][:fetch][:filter_by]
    assert_kind_of Set, @config.resource_config[:foos][:has_many][:bars][:fetch][:sort_by]
    assert_kind_of Sinja::Roles, @config.resource_config[:foos][:has_one][:qux][:pluck][:roles]

    @config.freeze

    assert_predicate @config.resource_config[:foos], :frozen?
    assert_nil @config.resource_config[:foos].default_proc

    assert_predicate @config.resource_config[:foos][:has_many], :frozen?
    assert_nil @config.resource_config[:foos][:has_many].default_proc

    assert_predicate @config.resource_config[:foos][:has_one][:qux], :frozen?
    assert_nil @config.resource_config[:foos][:has_one][:qux].default_proc

    assert_predicate @config.resource_config[:foos][:resource][:index], :frozen?
    assert_nil @config.resource_config[:foos][:resource][:index].default_proc

    assert_predicate @config.resource_config[:foos][:has_many][:bars][:fetch][:roles], :frozen?
    assert_predicate @config.resource_config[:foos][:has_many][:bars][:fetch][:sideload_on], :frozen?
    assert_predicate @config.resource_config[:foos][:has_many][:bars][:fetch][:filter_by], :frozen?
    assert_predicate @config.resource_config[:foos][:has_many][:bars][:fetch][:sort_by], :frozen?
  end
end
