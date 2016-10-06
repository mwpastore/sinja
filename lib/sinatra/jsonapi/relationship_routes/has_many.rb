# frozen_string_literal: true
module Sinatra::JSONAPI::RelationshipRoutes
  module HasMany
    ACTIONS = %i[fetch clear merge reject].freeze

    def self.registered(app)
      app.get '/', :actions=>:fetch do
        serialize_models(fetch(resource))
      end

      app.patch '/', :nullish=>proc(&:empty?), :actions=>:clear do
        clear(resource)
        status 204
      end

      app.patch '/', :actions=>%i[clear merge fetch] do
        clear(resource)
        merge(resource, data)
        serialize_models(fetch(resource))
      end

      app.post '/', :actions=>%i[merge fetch] do
        merge(resource, data)
        serialize_models(fetch(resource))
      end

      app.delete '/', :actions=>%i[reject fetch] do
        reject(resource, data)
        serialize_models(fetch(resource))
      end
    end
  end
end
