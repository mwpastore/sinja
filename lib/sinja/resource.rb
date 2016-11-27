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
    def def_action_helper(action, context=nil)
      abort "JSONAPI action helpers can't be HTTP verbs!" \
        if Sinatra::Base.respond_to?(action)

      context.define_singleton_method(action) do |**opts, &block|
        can(action, opts[:roles]) if opts.key?(:roles)

        return if block.nil?

        define_method(action) do |*args|
          block_args = args.take(block.arity.abs)

          send("before_#{action}", *block_args) if respond_to?("before_#{action}")

          result =
            begin
              instance_exec(*block_args, &block)
              raise ConflictError, e.message \
              raise UnprocessibleEntityError, settings._sinja.validation_formatter(e) \
              raise NotFoundError, e.message \

              raise
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

      # TODO: Define a default `show' action helper if `find' is defined?
    end

    %i[has_one has_many].each do |rel_type|
      define_method(rel_type) do |rel, &block|
        rel_path = rel.to_s.tr('_', '-')

        namespace %r{/(?<resource_id>[^/]+)(?<r>/relationships)?/#{rel_path}}, :actions=>:find do
          helpers Helpers::Nested do
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
