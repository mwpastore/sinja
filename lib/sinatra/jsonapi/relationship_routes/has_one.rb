# frozen_string_literal: true
module Sinatra::JSONAPI::RelationshipRoutes
  module HasOne
    def self.registered(app)
      app.settings._action_conflicts[:place] = true
      %i[prune place].each do |action|
        app.settings._action_roles[action] ||= app.settings._action_roles[:update].dup
      end

      app.get '', :actions=>:pluck do
        serialize_model(*pluck(resource))
      end

      app.patch '', :nullif=>proc(&:nil?), :actions=>:prune do
        sanity_check!
        prune(resource)
        status 204
      end

      app.patch '', :actions=>%i[place pluck] do
        sanity_check!
        place(resource, data)
        serialize_model(*pluck(resource))
      end
    end
  end
end
