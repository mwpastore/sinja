# frozen_string_literal: true
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
    CONFLICT_ACTIONS = Set.new(%i[create update graft merge]).freeze
    SIDELOAD_ACTIONS = Set.new(%i[graft merge]).freeze

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

        define_method(action) do |*args|
          block_args = args.take(block.arity.abs)

          public_send("before_#{action}", *block_args) \
            if respond_to?("before_#{action}")

          result =
            begin
              instance_exec(*block_args, &block)
            rescue *settings._sinja.not_found_exceptions=>e
              raise NotFoundError, e.message
            rescue *settings._sinja.conflict_exceptions=>e
              raise(e) unless CONFLICT_ACTIONS.include?(action)

              raise ConflictError, e.message
            rescue *settings._sinja.validation_exceptions=>e
              raise UnprocessibleEntityError, settings._sinja.validation_formatter(e)
            end

          # TODO: Move this to a constant or configurable?
          required_arity = {
            :create=>2,
            :index=>-1,
            :fetch=>-1
          }.freeze[action] || 1

          case result
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
        rel_path = Helpers::Serializers.dasherize(rel.to_s)

        _resource_roles[rel_type][rel.to_sym] # trigger default proc

        namespace %r{/(?<resource_id>[^/]+)(?<r>/relationships)?/#{rel_path}}, :actions=>:find do
          define_singleton_method(:resource_roles) do
            _resource_roles[rel_type][rel.to_sym]
          end

          helpers Helpers::Nested do
            define_method(:can?) do |*args|
              super(*args, rel_type, rel.to_sym)
            end

            define_method(:linkage) do
              # TODO: This is extremely wasteful. Refactor JAS to expose the linkage serializer?
              serialize_model(resource, :include=>rel_path)['data']['relationships'][rel_path]
            end
          end

          before do
            raise NotFoundError, 'Parent resource not found' unless resource
          end

          register RelationshipRoutes.const_get \
            rel_type.to_s.split('_').map(&:capitalize).join.to_sym

          instance_eval(&block) if block
        end
      end
    end
  end
end
