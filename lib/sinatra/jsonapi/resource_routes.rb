# frozen_string_literal: true
module Sinatra::JSONAPI
  module ResourceRoutes
    ACTIONS = %i[index show create update destroy].freeze
    CONFLICT_ACTIONS = %i[create update].freeze

    def self.registered(app)
      app.def_action_helpers(ACTIONS, app)

      app.get '', :actions=>:index do
        serialize_models(*index)
      end

      app.get '/:id', :actions=>:show do |id|
        self.resource, opts = show(id)
        not_found "Resource '#{id}' not found" unless resource
        serialize_model(resource, opts)
      end

      app.post '', :actions=>:create do
        sanity_check!
        halt 403, 'Client-generated IDs not supported' \
          if data[:id] && method(:create).arity != 2

        _, self.resource, opts = transaction do
          create(data.fetch(:attributes, {}), data[:id]).tap do |id, *|
            dispatch_relationship_requests!(id, :method=>:patch)
          end
        end

        if resource
          content = serialize_model(resource, opts)
          if content.respond_to?(:dig) && self_link = content.dig(*%w[data links self])
            headers 'Location'=>self_link
          end
          [201, content]
        elsif data[:id]
          204
        else
          raise ActionHelperError, "Unexpected return value(s) from `create' action helper"
        end
      end

      app.patch '/:id', :actions=>%i[show update] do |id|
        sanity_check!(id)
        self.resource, = show(id)
        not_found "Resource '#{id}' not found" unless resource
        serialize_model?(transaction do
          update(data.fetch(attributes, {})).tap do
            dispatch_relationship_requests!(id, :method=>:patch)
          end
        end)
      end

      app.delete '/:id', :actions=>%i[show destroy] do |id|
        self.resource, = show(id)
        not_found "Resource '#{id}' not found" unless resource
        _, opts = destroy
        serialize_model?(nil, opts)
      end
    end
  end
end
