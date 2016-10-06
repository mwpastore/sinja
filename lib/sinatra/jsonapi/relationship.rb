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
        if ACTIONS.any? { |action| Base.respond_to?(action) }

      ACTIONS.each do |action|
        define_method(action) do |&block|
          helpers { define_method(action, &block) }
        end
      end

      def self.registered(app)
        app.register AbstractResource

        app.helpers do
          def resource
            env['jsonapi.resource']
          end
        end

        app.set :actions do |*actions|
          condition do
            actions.all? do |action|
              halt 405 unless respond_to?(action)
              true
            end
          end
        end

        app.set :nullish do |nullish|
          condition { nullish.(data) }
        end
      end
    end
  end
end
