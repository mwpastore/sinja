# frozen_string_literal: true
require 'forwardable'
require 'set'

require 'sinja/relationship_routes/has_many'
require 'sinja/relationship_routes/has_one'
require 'sinja/resource_routes'
require 'sinja/role_list'

module Sinja
  module ConfigUtils
    def deep_copy(c)
      Marshal.load(Marshal.dump(c))
    end

    def deep_freeze(c)
      c.tap { |i| i.values.each(&:freeze) }.freeze
    end
  end

  class Config
    include ConfigUtils
    extend Forwardable

    DEFAULT_SERIALIZER_OPTS = {
      :jsonapi=>{ :version=>'1.0' }.freeze
    }.freeze

    DEFAULT_OPTS = {
      :json_generator=>(Sinatra::Base.development? ? :pretty_generate : :generate),
      :json_error_generator=>(Sinatra::Base.development? ? :pretty_generate : :generate)
    }.freeze

    attr_reader \
      :error_logger,
      :default_roles,
      :resource_roles,
      :conflict_actions,
      :conflict_exceptions,
      :not_found_exceptions,
      :validation_exceptions,
      :validation_formatter,
      :serializer_opts

    def initialize
      @error_logger = ->(eh) { logger.error('sinja') { eh } }

      @default_roles = RolesConfig.new
      @resource_roles = Hash.new { |h, k| h[k] = @default_roles.dup }

      @conflict_actions = [
        ResourceRoutes::CONFLICT_ACTIONS,
        RelationshipRoutes::HasMany::CONFLICT_ACTIONS,
        RelationshipRoutes::HasOne::CONFLICT_ACTIONS
      ].reduce(Set.new, :merge)
      @conflict_exceptions = Set.new
      @not_found_exceptions = Set.new
      @validation_exceptions = Set.new
      @validation_formatter = ->{ Array.new }

      @opts = deep_copy(DEFAULT_OPTS)
      @serializer_opts = {}
    end

    def conflict_actions=(e=[])
      @conflict_actions.replace(Set[*e])
    end

    def error_logger=(f)
      fail "Invalid error formatter #{f}" \
        unless f.respond_to?(:call)

      fail "Can't modify frozen proc" \
        if @error_logger.frozen?

      @error_logger = f
    end

    def conflict_exceptions=(e=[])
      @conflict_exceptions.replace(Set[*e])
    end

    def conflict_exception?(action, exception_class)
      @conflict_actions.include?(action) &&
        @conflict_exceptions.include?(exception_class)
    end

    def not_found_exceptions=(e=[])
      @not_found_exceptions.replace(Set[*e])
    end

    def_delegator :@not_found_exceptions, :include?, :not_found_exception?

    def validation_exceptions=(e=[])
      @validation_exceptions.replace(Set[*e])
    end

    def validation_formatter=(f)
      fail "Invalid validation formatter #{f}" \
        unless f.respond_to?(:call)

      fail "Can't modify frozen proc" \
        if @validation_formatter.frozen?

      @validation_formatter = f
    end

    def_delegator :@validation_exceptions, :include?, :validation_exception?

    def_delegator :@default_roles, :merge!, :default_roles=

    def serializer_opts=(h={})
      @serializer_opts.replace(deep_copy(DEFAULT_SERIALIZER_OPTS).merge!(h))
    end

    DEFAULT_OPTS.keys.each do |k|
      define_method(k) { @opts[k] }
      define_method("#{k}=") { |v| @opts[k] = v }
    end

    def freeze
      @error_logger.freeze
      @default_roles.freeze
      @resource_roles.default_proc = nil
      deep_freeze(@resource_roles)
      @conflict_actions.freeze
      @conflict_exceptions.freeze
      @not_found_exceptions.freeze
      @validation_exceptions.freeze
      @validation_formatter.freeze
      deep_freeze(@serializer_opts)
      @opts.freeze
      super
    end
  end

  class RolesConfig
    include ConfigUtils
    extend Forwardable

    def initialize
      @data = [
        ResourceRoutes::ACTIONS,
        RelationshipRoutes::HasMany::ACTIONS,
        RelationshipRoutes::HasOne::ACTIONS
      ].reduce([], :concat).map { |action| [action, RoleList.new] }.to_h
    end

    def_delegator :@data, :[]

    def merge!(h={})
      h.each do |action, roles|
        abort "Unknown or invalid action helper `#{action}' in configuration" \
          unless @data.key?(action)
        @data[action].replace(RoleList[*roles])
      end
      @data
    end

    def initialize_copy(other)
      super
      @data = deep_copy(other.instance_variable_get(:@data))
    end

    def freeze
      deep_freeze(@data)
      super
    end
  end
end
