# frozen_string_literal: true
require 'set'
require 'sinatra/jsonapi'
require 'sinatra/jsonapi/relationship_routes/has_many'
require 'sinatra/jsonapi/relationship_routes/has_one'
require 'sinatra/jsonapi/resource_routes'
require 'sinatra/namespace'

module Sinatra
  module JSONAPI
    module Resource
      ActionHelperError = Class.new(StandardError)

      module RequestHelpers
        def can?(action)
          roles = settings._action_roles[action]
          roles.nil? || roles.empty? || Set[*role].intersect?(roles)
        end

        def data
          @data ||= deserialize_request_body[:data]
        end

        def normalize_params!
          # TODO: halt 400 if other params, or params not implemented?
          {
            :filter=>{},
            :fields=>{},
            :page=>{},
            :include=>[]
          }.each { |k, v| params[k] ||= v }
        end
      end

      module ResponseHelpers
        def serialize_model!(model=nil, options={})
          options[:is_collection] = false
          options[:skip_collection_check] = defined?(Sequel) && model.is_a?(Sequel::Model)
          options[:include] ||= params[:include] unless params[:include].empty?

          ::JSONAPI::Serializer.serialize model,
            settings._jsonapi_serializer_opts.merge(options)
        end

        def serialize_model?(model=nil, options={})
          if model
            serialize_model!(model, options)
          elsif options.key?(:meta)
            serialize_model!(nil, :meta=>options[:meta])
          else
            204
          end
        end

        def serialize_models!(models=[], options={})
          options[:is_collection] = true
          options[:include] ||= params[:include] unless params[:include].empty?

          ::JSONAPI::Serializer.serialize [*models],
            settings._jsonapi_serializer_opts.merge(options)
        end

        def serialize_models?(models=[], options={})
          if [*models].any?
            serialize_models!(models, options)
          elsif options.key?(:meta)
            serialize_models!([], :meta=>options[:meta])
          else
            204
          end
        end
      end

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
            halt(*response) unless (200...300).cover?(response[0])
          end
        end
      end

      def def_action_helpers(actions, take_block=true)
        [*actions].each { |action| def_action_helper(action, take_block) }
      end

      def def_action_helper(action, take_block=true)
        abort 'JSONAPI resource actions can\'t be HTTP verbs!' if Base.respond_to?(action)

        define_singleton_method(action) do |**opts, &block|
          _action_roles[action] = Set[*opts[:roles]] if opts.key?(:roles)
          _action_conflicts[action] = !!opts[:conflicts] if opts.key?(:conflicts)

          fail if block && !take_block # TODO
          return unless block

          helpers do
            define_method(action) do |*args|
              result =
                begin
                  instance_exec(*args.take(block.arity.abs), &block)
                rescue Exception=>e
                  raise e unless settings._action_conflicts[action] \
                    && settings._conflict_exceptions.include?(e.class)

                  halt 409, e.message
                end

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

      def role(&block)
        helpers { define_method(__callee__, &block) }
      end

      def transaction(&block)
        helpers { define_method(__callee__, &block) }
      end

      def action_conflicts(h={})
        _action_conflicts.tap { |c| c.merge!(h) }
      end

      def action_roles(h={})
        _action_roles.tap { |c| c.merge!(h) }
      end

      def conflict_exceptions(e=[])
        _conflict_exceptions.tap { |c| c.concat([*e]) }
      end

      def jsonapi_serializer_opts(h={})
        _jsonapi_serializer_opts.tap { |c| c.merge!(h) }
      end

      def self.registered(app)
        app.register JSONAPI, Namespace

        app.set :_action_roles, {}
        app.set :_action_conflicts, {}
        app.set :_conflict_exceptions, []
        app.set :_jsonapi_serializer_opts, :jsonapi=>{ :version=>'1.0' }

        app.helpers RequestHelpers, ResponseHelpers do
          def sanity_check!(id=nil)
            halt 409, 'Resource type in payload does not match endpoint' \
              if data[:type] != request.path.split('/').last # TODO

            halt 409, 'Resource ID in payload does not match endpoint' \
              if id && data[:id].to_s != id.to_s
          end

          def transaction
            yield
          end
        end

        app.set :actions do |*actions|
          condition do
            actions.each do |action|
              halt 403 unless can?(action)
              halt 405 unless respond_to?(action)
            end
            true
          end
        end

        app.set :nullif do |nullish|
          condition { nullish.(data) }
        end

        app.before do
          normalize_params!
        end

        app.after do
          body serialize_response_body if response.ok?
        end

        app.def_action_helpers ResourceRoutes::ACTIONS, false
        app.def_action_helpers RelationshipRoutes::HasMany::ACTIONS, false
        app.def_action_helpers RelationshipRoutes::HasOne::ACTIONS, false

        # TODO: Skip this for abstract controllers?
        app.namespace '/' do
          app.helpers RelationshipHelpers
          app.register ResourceRoutes
        end
      end

      %i[has_one has_many].each do |rel_type|
        define_method(rel_type) do |rel, &block|
          namespace %r{/(?<resource_id>[^/]+)(/relationships)?/#{rel.to_s.tr('_', '-')}}, :actions=>:find do
            helpers do
              def setter_path?
                !params[:captures][1].nil?
              end

              def resource
                @resource ||= find(params[:resource_id]).first
              end

              def sanity_check!
                super(params[:resource_id])
              end
            end

            before do
              not_found unless nil ^ setter_path? ^ request.get? # TODO: yuck
              not_found unless resource
            end

            register RelationshipRoutes.const_get \
              rel_type.to_s.split('_').map(&:capitalize).join.to_sym

            instance_eval(&block)
          end
        end
      end

      def freeze!
        _action_conflicts.freeze
        _action_roles.tap { |c| c.values.each(&:freeze) }.freeze
        _conflict_exceptions.freeze
        _jsonapi_serializer_opts.tap { |c| c.values.each(&:freeze) }.freeze
      end

      def inherited(subclass)
        super

        %i[
          _action_roles
          _action_conflicts
          _conflict_exceptions
          _jsonapi_serializer_opts
        ].each do |setting|
          subclass.send "#{setting}=", Marshal.load(Marshal.dump(subclass.send(setting)))
        end
      end
    end
  end

  register JSONAPI::Resource
end
