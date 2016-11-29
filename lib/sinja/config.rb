# frozen_string_literal: true
require 'forwardable'
require 'set'
require 'sinatra/base'

require 'sinja/resource'
require 'sinja/relationship_routes/has_many'
require 'sinja/relationship_routes/has_one'
require 'sinja/resource_routes'

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
      :default_has_many_roles,
      :default_has_one_roles,
      :resource_roles,
      :resource_sideload,
      :conflict_exceptions,
      :not_found_exceptions,
      :validation_exceptions,
      :validation_formatter,
      :serializer_opts

    def initialize
      @error_logger = ->(eh) { logger.error('sinja') { eh } }

      @default_roles = RolesConfig.new(ResourceRoutes::ACTIONS)
      @default_has_many_roles = RolesConfig.new(RelationshipRoutes::HasMany::ACTIONS)
      @default_has_one_roles = RolesConfig.new(RelationshipRoutes::HasOne::ACTIONS)

      @resource_roles = Hash.new { |h, k| h[k] = {
        :resource=>@default_roles.dup,
        :has_many=>Hash.new { |rh, rk| rh[rk] = @default_has_many_roles.dup },
        :has_one=>Hash.new { |rh, rk| rh[rk] = @default_has_one_roles.dup }
      }}

      @resource_sideload = Hash.new do |h, k|
        h[k] = SideloadConfig.new(Resource::SIDELOAD_ACTIONS)
      end

      @conflict_exceptions = Set.new
      @not_found_exceptions = Set.new
      @validation_exceptions = Set.new
      @validation_formatter = ->{ Array.new }

      @opts = deep_copy(DEFAULT_OPTS)
      @serializer_opts = deep_copy(DEFAULT_SERIALIZER_OPTS)
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

    def not_found_exceptions=(e=[])
      @not_found_exceptions.replace(Set[*e])
    end

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

    def_delegator :@default_roles, :merge!, :default_roles=
    def_delegator :@default_has_many_roles, :merge!, :default_has_many_roles=
    def_delegator :@default_has_one_roles, :merge!, :default_has_one_roles=

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
      @default_has_many_roles.freeze
      @default_has_one_roles.freeze

      @resource_roles.default_proc = nil
      @resource_roles.values.each do |h|
        h[:resource].freeze
        h[:has_many].default_proc = nil
        deep_freeze(h[:has_many])
        h[:has_one].default_proc = nil
        deep_freeze(h[:has_one])
      end
      deep_freeze(@resource_roles)

      @resource_sideload.default_proc = nil
      deep_freeze(@resource_sideload)

      @conflict_exceptions.freeze
      @not_found_exceptions.freeze
      @validation_exceptions.freeze
      @validation_formatter.freeze

      deep_freeze(@serializer_opts)

      @opts.freeze

      super
    end
  end

  class Roles < Set
    def ===(other)
      self.intersect?(Set === other ? other : Set[*other])
    end
  end

  class RolesConfig
    include ConfigUtils
    extend Forwardable

    def initialize(actions=[])
      @data = actions.map { |action| [action, Roles.new] }.to_h
    end

    def_delegator :@data, :[]

    def ==(other)
      @data == other.instance_variable_get(:@data)
    end

    def merge!(h={})
      h.each do |action, roles|
        abort "Unknown or invalid action helper `#{action}' in configuration" \
          unless @data.key?(action)
        @data[action].replace(Roles[*roles])
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

  class SideloadConfig
    include ConfigUtils
    extend Forwardable

    def initialize(actions=[])
      @data = actions.map { |child| [child, Set.new] }.to_h
    end

    def_delegator :@data, :[]

    def ==(other)
      @data == other.instance_variable_get(:@data)
    end

    def merge!(h={})
      h.each do |child, parents|
        abort "Unknown or invalid action helper `#{child}' in configuration" \
          unless @data.key?(child)
        @data[child].replace(Set[*parents])
      end
      @data
    end

    def freeze
      deep_freeze(@data)
      super
    end
  end
end
