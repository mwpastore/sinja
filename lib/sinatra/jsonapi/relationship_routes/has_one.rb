# frozen_string_literal: true
module Sinatra::JSONAPI::RelationshipRoutes
  module HasOne
    def self.registered(app)
      app.settings.action_conflicts[:place] = true
      %i[prune place].each do |action|
        app.settings.action_roles[action] ||= app.settings.action_roles[:update].dup
      end

      app.get '', :actions=>:pluck do
        serialize_model(pluck(resource))
      end

      app.patch '', :nullif=>proc(&:nil?), :actions=>:prune do
        check_conflict!
        prune(resource)
        status 204
      end

      app.patch '', :actions=>%i[place pluck] do
        check_conflict!
        send_action(:place, resource, data)
        serialize_model(pluck(resource))
      end
    end
  end
end
