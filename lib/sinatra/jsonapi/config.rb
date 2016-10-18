# frozen_string_literal: true
require 'forwardable'
require 'set'
require 'sinatra/jsonapi/relationship_routes/has_many'
require 'sinatra/jsonapi/relationship_routes/has_one'
require 'sinatra/jsonapi/resource_routes'

module Sinatra
  module JSONAPI
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
        :logger_progname=>'sinja'
      }.freeze

      attr_reader \
        :default_roles,
        :resource_roles,
        :conflict_exceptions,
        :serializer_opts

      def initialize
        @default_roles = Sinatra::JSONAPI::RolesConfig.new
        @resource_roles = Hash.new { |h, k| h[k] = @default_roles.dup }
        @conflict_exceptions = []
        @opts = deep_copy(DEFAULT_OPTS)
        self.serializer_opts = ()
      end

      def conflict_exceptions=(e=[])
        @conflict_exceptions = [].concat([*e])
      end

      def_delegator :@default_roles, :merge!, :default_roles=

      def serializer_opts=(h={})
        @serializer_opts = deep_copy(DEFAULT_SERIALIZER_OPTS).merge!(h)
      end

      def logger_progname
        @opts[:logger_progname]
      end

      def logger_progname=(progname)
        @opts[:logger_progname] = progname
      end

      def freeze
        @default_roles.freeze
        deep_freeze(@resource_roles)
        @conflict_exceptions.freeze
        deep_freeze(@serializer_opts)
        @opts.freeze
      end
    end

    class RolesConfig
      include ConfigUtils

      def initialize
        @data = [
          Sinatra::JSONAPI::ResourceRoutes::ACTIONS,
          Sinatra::JSONAPI::RelationshipRoutes::HasMany::ACTIONS,
          Sinatra::JSONAPI::RelationshipRoutes::HasOne::ACTIONS
        ].reduce([], :concat).map { |action| [action, Set.new] }.to_h
      end

      def merge!(h={})
        h.each do |action, roles|
          fail unless @data.key?(action)
          @data[action].replace(Set[*roles])
        end
        @data
      end

      def initialize_copy(other)
        @data = deep_copy(other.instance_variable_get(:@data))
      end

      def freeze
        deep_freeze(@data)
      end
    end
  end
end
