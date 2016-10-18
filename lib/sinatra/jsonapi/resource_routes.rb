# frozen_string_literal: true
module Sinatra::JSONAPI::ResourceRoutes
  ACTIONS = %i[list find create update destroy].freeze

  def self.registered(app)
    app.def_action_helpers ACTIONS

    app.get '', :actions=>:list do
      serialize_models!(*list)
    end

    app.get '/:id', :actions=>:find do |id|
      self.resource, opts = find(id)
      not_found unless resource
      serialize_model!(resource, opts)
    end

    app.post '', :actions=>:create do
      sanity_check!
      halt 403, 'Client-generated IDs not supported' \
        if data[:id] && method(:create).arity != 2

      self.resource, _, opts = transaction do
        create(data.fetch(:attributes, {}), data[:id]).tap do |_, id, _|
          dispatch_relationship_requests!(id, :method=>:patch)
        end
      end

      if resource
        content = serialize_model!(resource, opts)
        if content.respond_to?(:dig) && self_link = content.dig(*%w[data links self])
          headers 'Location'=>self_link
        end
        [201, content]
      elsif data[:id]
        204
      else
        raise ActionHelperError, "Bad return value from `create' action helper"
      end
    end

    app.patch '/:id', :actions=>%i[find update] do |id|
      sanity_check!(id)
      self.resource, = find(id)
      not_found unless resource
      serialize_model?(transaction do
        update(data.fetch(attributes, {})).tap do
          dispatch_relationship_requests!(id, :method=>:patch)
        end
      end)
    end

    app.delete '/:id', :actions=>%i[find destroy] do |id|
      self.resource, = find(id)
      not_found unless resource
      _, opts = destroy
      serialize_model?(nil, opts)
    end
  end
end
