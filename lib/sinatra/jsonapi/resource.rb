# frozen_string_literal: true
require 'set'
require 'sinatra/jsonapi/abstract_resource'
require 'sinatra/jsonapi/relationship'
require 'sinatra/jsonapi/resource_routes'

module Sinatra
  module JSONAPI
    module Resource
      module Helpers
        def can?(action)
          roles = settings.action_roles[action]
          roles.empty? || Set[*role].intersect?(roles)
        end

        def has_relationship?(path)
          settings.relationships.key?(path.tr('-', '_').to_sym)
        end

        def has_relationships?(paths)
          paths.all? { |path| has_relationship?(path) }
        end

        def dispatch_relationship_request(path, resource, **opts)
          handler = settings.relationships[path.tr('-', '_').to_sym]
          sja = env['SJA'].merge 'resource'=>resource, 'nested'=>true
          fake_env = env.merge 'PATH_INFO'=>'/', 'SJA'=>sja
          fake_env['REQUEST_METHOD'] = opts[:method].to_s.tap(&:upcase!) if opts[:method]
          fake_env['rack.input'] = StringIO.new(JSON.fast_generate(opts[:body])) if opts.key?(:body)
          handler.call(fake_env)
        end

        def dispatch_relationship_requests!(resource, **opts)
          relationships do |path, body|
            response = dispatch_relationship_request(path, resource, opts.merge(:body=>body))
            halt(*response) unless (200...300).cover?(response[0])
          end
        end
      end

      abort 'JSONAPI resource actions can\'t be HTTP verbs!' \
        if ResourceRoutes::ACTIONS.any? { |action| Base.respond_to?(action) }

      ResourceRoutes::ACTIONS.each do |action|
        define_method(action) do |**opts, &block|
          if opts.key?(:roles)
            fail "Roles not enforced for `#{action}'" unless action_roles.key?(action)
            action_roles[action].replace([*opts[:roles]])
          end
          if opts.key?(:conflicts)
            fail "Conflicts not handled for `#{action}'" unless action_conflicts.key?(action)
            action_conflicts[action].replace([*opts[:conflicts]])
          end
          helpers { define_method(action, &block) } if block
        end
      end

      %i[has_one has_many].each do |rel_type|
        define_method(rel_type) do |rel, **opts, &block|
          relationships[rel] = Sinatra.new(opts.fetch(:base, Base)) do
            register Relationship
            register RelationshipRoutes.const_get \
              rel_type.to_s.split('_').map(&:capitalize).join.to_sym
            instance_eval(&block)
          end
        end
      end

      def role(&block)
        helpers { define_method(__callee__, &block) }
      end

      def self.registered(app)
        app.register AbstractResource

        # TODO: freeze these structures (deeply) at some later time?
        app.set :action_roles, ResourceRoutes::ACTIONS.map { |action| [action, Set.new] }.to_h.freeze
        app.set :action_conflicts, { :create=>[] }.freeze
        app.set :relationships, {}

        app.helpers Helpers

        app.set :actions do |*actions|
          condition do
            actions.each do |action|
              halt 403 unless can?(action)
              halt 405 unless respond_to?(action)
            end
            true
          end
        end

        app.register ResourceRoutes

        rel_router = proc do |id, rel_path|
          not_found unless has_relationship?(rel_path)
          not_found unless resource = find(id)
          dispatch_relationship_request(rel_path, resource)
        end

        %w[/:id/:rel_path /:id/relationships/:rel_path].each do |path|
          app.get(path, :actions=>:find, &rel_router)
        end

        %i[patch post delete].each do |verb|
          app.send(verb, '/:id/relationships/:rel_path', :actions=>%i[find update], &rel_router)
        end
      end

      def inherited(subclass)
        super

        subclass.action_roles =
          Marshal.load(Marshal.dump(subclass.action_roles)).freeze

        subclass.action_conflicts =
          Marshal.load(Marshal.dump(subclass.action_conflicts)).freeze

        subclass.relationships = {}
      end
    end
  end

  register JSONAPI::Resource
end
