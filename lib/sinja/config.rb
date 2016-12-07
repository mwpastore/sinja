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
      if c.respond_to?(:default_proc)
        c.default_proc = nil
      end

      if c.respond_to?(:values)
        c.values.each do |i|
          if Hash === i
            deep_freeze(i)
          else
            i.freeze
          end
        end
      end

      c.freeze
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
      :query_params,
      :error_logger,
      :resource_config,
      :conflict_exceptions,
      :not_found_exceptions,
      :validation_exceptions,
      :validation_formatter,
      :page_using,
      :serializer_opts

    def initialize
      @query_params = {
        :include=>[], # passthru to JAS
        :fields=>{}, # passthru to JAS
        :filter=>{},
        :page=>{},
        :sort=>{}
      }

      @error_logger = ->(h) { logger.error('sinja') { h } }

      @default_roles = {
        :resource=>RolesConfig.new(%i[show show_many index create update destroy]),
        :has_many=>RolesConfig.new(%i[fetch merge subtract clear]),
        :has_one=>RolesConfig.new(%i[pluck graft prune])
      }

      action_proc = proc { |type, hash, action| hash[action] = {
        :roles=>@default_roles[type][action].dup,
        :sideload_on=>Set.new,
        :filter_by=>Set.new,
        :sort_by=>Set.new
      }}.curry

      @resource_config = Hash.new { |h, k| h[k] = {
        :resource=>Hash.new(&action_proc[:resource]),
        :has_many=>Hash.new { |rh, rk| rh[rk] = Hash.new(&action_proc[:has_many]) },
        :has_one=>Hash.new { |rh, rk| rh[rk] = Hash.new(&action_proc[:has_one]) }
      }}

      @conflict_exceptions = Set.new
      @not_found_exceptions = Set.new
      @validation_exceptions = Set.new
      @validation_formatter = ->{ Array.new }

      @opts = deep_copy(DEFAULT_OPTS)
      @page_using = Hash.new
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
      @conflict_exceptions.replace([*e])
    end

    def not_found_exceptions=(e=[])
      @not_found_exceptions.replace([*e])
    end

    def validation_exceptions=(e=[])
      @validation_exceptions.replace([*e])
    end

    def validation_formatter=(f)
      fail "Invalid validation formatter #{f}" \
        unless f.respond_to?(:call)

      fail "Can't modify frozen proc" \
        if @validation_formatter.frozen?

      @validation_formatter = f
    end

    def default_roles
      @default_roles[:resource]
    end

    def default_roles=(other={})
      @default_roles[:resource].merge!(other)
    end

    def default_has_many_roles
      @default_roles[:has_many]
    end

    def default_has_many_roles=(other={})
      @default_roles[:has_many].merge!(other)
    end

    def default_has_one_roles
      @default_roles[:has_one]
    end

    def default_has_one_roles=(other={})
      @default_roles[:has_one].merge!(other)
    end

    DEFAULT_OPTS.keys.each do |k|
      define_method(k) { @opts[k] }
      define_method("#{k}=") { |v| @opts[k] = v }
    end

    def page_using=(p={})
      @page_using.replace(p)
    end

    def serializer_opts=(h={})
      @serializer_opts.replace(deep_copy(DEFAULT_SERIALIZER_OPTS).merge!(h))
    end

    def freeze
      @query_params.freeze
      @error_logger.freeze

      deep_freeze(@default_roles)
      deep_freeze(@resource_config)

      @conflict_exceptions.freeze
      @not_found_exceptions.freeze
      @validation_exceptions.freeze
      @validation_formatter.freeze

      @opts.freeze
      @page_using.freeze
      deep_freeze(@serializer_opts)

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

    def_delegators :@data, :[], :dig

    def ==(other)
      @data == other.instance_variable_get(:@data)
    end

    def merge!(h={})
      h.each do |action, roles|
        abort "Unknown or invalid action helper `#{action}' in configuration" \
          unless @data.key?(action)
        @data[action].replace([*roles])
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
