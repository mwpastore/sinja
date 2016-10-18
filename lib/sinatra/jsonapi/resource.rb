# frozen_string_literal: true
require 'json'
require 'set'
require 'sinatra/base'
require 'sinatra/namespace'
require 'sinatra/jsonapi/relationship_routes/has_many'
require 'sinatra/jsonapi/relationship_routes/has_one'
require 'sinatra/jsonapi/resource_routes'

module Sinatra
  module JSONAPI
    module Resource
      ActionHelperError = Class.new(StandardError)

      module RelationshipHelpers
        def dispatch_relationship_request(id, path, **opts)
          fake_env = env.merge 'PATH_INFO'=>"/#{id}/relationships/#{path}"
          fake_env['REQUEST_METHOD'] = opts[:method].to_s.tap(&:upcase!) if opts[:method]
          fake_env['rack.input'] = StringIO.new(JSON.fast_generate(opts[:body])) if opts.key?(:body)
          call(fake_env) # TODO: we may need to bypass postprocessing here
        end

        def dispatch_relationship_requests!(id, **opts)
          data.fetch(:relationships, {}).each do |path, body|
            response = dispatch_relationship_request(id, path, opts.merge(:body=>body))
            # TODO: Gather responses and report all errors instead of only first?
            halt(*response) unless (200...300).cover?(response[0])
          end
        end
      end

      def def_action_helpers(actions)
        [*actions].each { |action| def_action_helper(action) }
      end

      def def_action_helper(action)
        abort 'JSONAPI resource actions can\'t be HTTP verbs!' if Base.respond_to?(action)

        define_singleton_method(action) do |**opts, &block|
          sinja.resource_roles[@resource_name].merge!(action=>opts[:roles]) if opts.key?(:roles)

          helpers do
            define_method(action) do |*args|
              result =
                begin
                  instance_exec(*args.take(block.arity.abs), &block)
                rescue Exception=>e
                  raise e unless %i[create update graft merge].include?(action) \
                    && settings.sinja.conflict_exceptions.include?(e.class)

                  halt 409, e.message
                end

              # TODO: This is a nightmare.
              if action == :create
                raise ActionHelperError, "`#{action}' must return primary key and resource object" \
                  unless result.is_a?(Array) && result.length >= 2 && !result[1].instance_of?(Hash)
                return result if result.length == 3
                return *result, {}
              else
                return result \
                  if result.is_a?(Array) && result.length == 2 && result.last.instance_of?(Hash)
                return nil, result if result.instance_of?(Hash)
                return result, {}
              end
            end
          end
        end
      end

      def self.registered(app)
        app.helpers RelationshipHelpers do
          attr_accessor :resource

          def sanity_check!(id=nil)
            halt 409, 'Resource type in payload does not match endpoint' \
              if data[:type] != request.path.split('/').last # TODO

            halt 409, 'Resource ID in payload does not match endpoint' \
              if id && data[:id].to_s != id.to_s
          end
        end

        app.register ResourceRoutes
      end

      %i[has_one has_many].each do |rel_type|
        define_method(rel_type) do |rel, &block|
          namespace %r{/(?<resource_id>[^/]+)(?<foo>/relationships)?/#{rel.to_s.tr('_', '-')}}, :actions=>:find do
            helpers do
              def setter_path?
                # TODO: Can't mix named and positional capture groups?
                !params[:foo].nil?
              end

              def resource
                super || self.resource = find(params[:resource_id]).first
              end

              def sanity_check!
                super(params[:resource_id])
              end
            end

            before do
              not_found unless setter_path? ^ request.get?
              not_found unless resource
            end

            register RelationshipRoutes.const_get \
              rel_type.to_s.split('_').map(&:capitalize).join.to_sym

            if block
              instance_eval(&block)
            elsif rel_type == :has_one
              pluck do
                resource.send(rel)
              end
            elsif rel_type == :has_many
              fetch do
                resource.send(rel)
              end
            end
          end
        end
      end
    end
  end
end
