# frozen_string_literal: true
require 'active_support/inflector'
require 'set'
require 'sinatra/base'
require 'sinatra/namespace'

require 'sinja/helpers/nested'
require 'sinja/helpers/relationships'
require 'sinja/relationship_routes/has_many'
require 'sinja/relationship_routes/has_one'
require 'sinja/resource_routes'

module Sinja
  module Resource
    SIDELOAD_ACTIONS = Set.new(%i[graft merge clear]).freeze

    def def_action_helper(action, context)
      abort "JSONAPI action helpers can't be HTTP verbs!" \
        if Sinatra::Base.respond_to?(action)

      context.define_singleton_method(action) do |**opts, &block|
        resource_roles.merge!(action=>opts[:roles]) if opts.key?(:roles)
        resource_sideload.merge!(action=>opts[:sideload_on]) if opts.key?(:sideload_on)

        return unless block ||=
          case !method_defined?(action) && action
          when :show
            proc { |id| find(id) } if method_defined?(:find)
          end

        # TODO: Move this to a constant or configurable?
        required_arity = {
          :create=>2,
          :index=>-1,
          :fetch=>-1
        }.freeze[action] || 1

        define_method(action) do |*args|
          raise ArgumentError, "Unexpected block signature for `#{action}' action helper" \
            unless args.length == block.arity

          public_send("before_#{action}", *args) if respond_to?("before_#{action}")

          case result = instance_exec(*args, &block)
          when Array
            opts = {}
            if Hash === result.last
              opts = result.pop
            elsif required_arity < 0 && !(Array === result.first)
              result = [result]
            end

            raise ActionHelperError, "Unexpected return value(s) from `#{action}' action helper" \
              unless result.length == required_arity.abs

            result.push(opts)
          when Hash
            Array.new(required_arity.abs).push(result)
          else
            [result, nil].take(required_arity.abs).push({})
          end
        end

        define_singleton_method("remove_#{action}") do
          remove_method(action) if respond_to?(action)
        end
      end
    end

    def def_action_helpers(actions, context=nil)
      [*actions].each { |action| def_action_helper(action, context) }
    end

    def self.registered(app)
      app.helpers Helpers::Relationships do
        attr_accessor :resource
      end

      app.register ResourceRoutes
    end

    %i[has_one has_many].each do |rel_type|
      define_method(rel_type) do |rel, &block|
        rel_path = rel.to_s
          .send(rel_type == :has_one ? :singularize : :pluralize)
          .dasherize
          .to_sym

        _resource_roles[rel_type][rel.to_sym] # trigger default proc

        namespace %r{/[^/]+(?<r>/relationships)?/#{rel_path}} do
          define_singleton_method(:resource_roles) do
            _resource_roles[rel_type][rel.to_sym]
          end

          helpers Helpers::Nested do
            define_method(:can?) do |*args|
              super(*args, rel_type, rel.to_sym)
            end

            define_method(:serialize_linkage) do |*args|
              super(resource, rel_path, *args)
            end
          end

          register RelationshipRoutes.const_get \
            rel_type.to_s.split('_').map(&:capitalize).join.to_sym

          instance_eval(&block) if block
        end
      end
    end
  end
end
