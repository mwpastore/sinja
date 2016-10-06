# frozen_string_literal: true
require 'set'
require 'sinatra/jsonapi/abstract_resource'
require 'sinatra/jsonapi/relationship'
require 'sinatra/jsonapi/resource_routes'

module Sinatra
  module JSONAPI
    module Resource
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

        app.set :actions do |*actions|
          condition do
            actions.all? do |action|
              roles = settings.action_roles[action]
              halt 403 unless roles.empty? || Set[*role].intersect?(roles)
              halt 405 unless respond_to?(action)
              true
            end
          end
        end

        app.register ResourceRoutes

        delegator = proc do |id, rel_path|
          rel = rel_path.to_s.tr('-', '_').to_sym
          not_found unless settings.relationships.key?(rel)
          resource = find(id)
          not_found unless resource

          fake_env = env.merge \
            'PATH_INFO'=>'/',
            'jsonapi.resource'=>resource,
            'jsonapi.bypass'=>false

          settings.relationships[rel].call(fake_env).tap do
            # TODO: There has to be a better way to do this.
            env['jsonapi.bypass'] = true
          end
        end

        %w[/:id/:rel /:id/relationships/:rel].each do |path|
          app.get(path, :actions=>:find, &delegator)
        end

        %i[patch post delete].each do |verb|
          app.send(verb, '/:id/relationships/:rel', :actions=>%i[find update], &delegator)
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
