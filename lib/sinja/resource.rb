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
    def def_action_helper(context, action, allow_opts=[])
      abort "Action helper names can't overlap with Sinatra DSL" \
        if Sinatra::Base.respond_to?(action)

      context.define_singleton_method(action) do |**opts, &block|
        abort "Unexpected option(s) for `#{action}' action helper" \
          unless (opts.keys - [*allow_opts]).empty?

        resource_config[action].each do |k, v|
          v.replace([*opts[k]]) if opts.key?(k)
        end

        return unless block ||=
          case !method_defined?(action) && action
          when :show
            proc { |id| find(id) } if method_defined?(:find)
          end

        # TODO: Move this to a constant or configurable?
        required_arity = {
          :create=>2,
          :index=>-1,
          :fetch=>-1,
          :show_many=>-1
        }.freeze[action] || 1

        define_method(action) do |*args|
          raise ArgumentError, "Unexpected argument(s) for `#{action}' action helper" \
            unless args.length == block.arity

          public_send("before_#{action}", *args) \
            if respond_to?("before_#{action}")

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

    def self.registered(app)
      app.helpers Helpers::Relationships do
        attr_accessor :resource
      end

      app.register ResourceRoutes
    end

    %i[has_one has_many].each do |rel_type|
      define_method(rel_type) do |rel, &block|
        rel = rel.to_s
          .send(rel_type == :has_one ? :singularize : :pluralize)
          .dasherize
          .to_sym

        config = _resource_config[rel_type][rel] # trigger default proc

        namespace %r{/[^/]+(?<r>/relationships)?/#{rel}} do
          define_singleton_method(:resource_config) { config }

          helpers Helpers::Nested do
            define_method(:can?) do |action, *args|
              parent = sideloaded? && env['sinja.passthru'].to_sym

              roles, sideload_on = config.fetch(action, {}).values_at(:roles, :sideload_on)
              roles.nil? || roles.empty? || roles === memoized_role ||
                parent && sideload_on.include?(parent) && super(parent, *args)
            end

            define_method(:serialize_linkage) do |*args|
              super(resource, rel, *args)
            end
          end

          register RelationshipRoutes.const_get(rel_type.to_s.camelize)

          instance_eval(&block) if block
        end
      end
    end
  end
end
