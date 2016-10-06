# frozen_string_literal: true
require 'set'
require 'sinatra/jsonapi/abstract_resource'
require 'sinatra/jsonapi/relationship_routes/has_many'
require 'sinatra/jsonapi/relationship_routes/has_one'

module Sinatra
  module JSONAPI
    module Relationship
      ACTIONS = Set.new
      ACTIONS.merge RelationshipRoutes::HasMany::ACTIONS
      ACTIONS.merge RelationshipRoutes::HasOne::ACTIONS
      ACTIONS.freeze

      abort 'JSONAPI relationship actions can\'t be HTTP verbs!' \
        if ACTIONS.any? { |action| Sinatra::Base.respond_to?(action) }

      ACTIONS.each do |action|
        define_method(action) do |**opts, &block|
          if opts.key?(:roles)
            fail "Roles not enforced for `#{action}'" unless action_roles.key?(action)
            action_roles[action].replace([*opts[:roles]])
          end
          helpers { define_method(action, &block) } if block
        end
      end

      def self.registered(app)
        app.register AbstractResource

        # TODO: freeze these structures (deeply) at some later time?
        app.set :action_roles, ACTIONS.map { |action| [action, Set.new] }.to_h.freeze

        app.helpers do
          def resource
            env['jsonapi.resource']
          end

          def role
            env['jsonapi.role']
          end
        end

        app.set :nullish do |nullish|
          condition { nullish.(data) }
        end
      end
    end
  end
end
