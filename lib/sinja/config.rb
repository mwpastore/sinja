# frozen_string_literal: true
require 'forwardable'
require 'set'

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
      :resource_roles,
      :resource_sideload,
      :conflict_exceptions,
      :not_found_exceptions,
      :validation_exceptions,
      :validation_formatter,
      :serializer_opts

    def initialize
      @error_logger = ->(eh) { logger.error('sinja') { eh } }

      @default_roles = RolesConfig.new
      @resource_roles = Hash.new { |h, k| h[k] = @default_roles.dup }
      @resource_sideload = Hash.new { |h, k| h[k] = SideloadConfig.new }

      @conflict_exceptions = Set.new
      @not_found_exceptions = Set.new
      @validation_exceptions = Set.new
      @validation_formatter = ->{ Array.new }

      @opts = deep_copy(DEFAULT_OPTS)
      @serializer_opts = {}
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

    def initialize
      @data = [
        ResourceRoutes::ACTIONS,
        RelationshipRoutes::HasMany::ACTIONS,
        RelationshipRoutes::HasOne::ACTIONS
      ].reduce(Set.new, :merge).map { |action| [action, Roles.new] }.to_h
    end

    def_delegator :@data, :[]

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

    def initialize
      @data = Resource::SIDELOAD_ACTIONS.map { |child| [child, Set.new] }.to_h
    end

    def_delegator :@data, :[]

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
