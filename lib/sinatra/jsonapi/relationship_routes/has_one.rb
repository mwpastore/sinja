# frozen_string_literal: true
module Sinatra::JSONAPI::RelationshipRoutes
  module HasOne
    ACTIONS = %i[pluck prune place].freeze

    def self.registered(app)
      app.get '/', :actions=>:pluck do
        serialize_model(pluck(resource))
      end

      app.patch '/', :nullish=>proc(&:nil?), :actions=>:prune do
        prune(resource)
        status 204
      end

      app.patch '/', :actions=>%i[place pluck] do
        place(resource, data)
        serialize_model(pluck(resource))
      end
    end
  end
end
