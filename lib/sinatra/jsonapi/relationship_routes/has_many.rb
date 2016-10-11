# frozen_string_literal: true
module Sinatra::JSONAPI::RelationshipRoutes
  module HasMany
    def self.registered(app)
      app.settings.action_conflicts[:merge] = true
      %i[clear merge reject].each do |action|
        app.settings.action_roles[action] ||= app.settings.action_roles[:update].dup
      end

      app.get '', :actions=>:fetch do
        serialize_models(fetch(resource))
      end

      app.patch '', :nullif=>proc(&:empty?), :actions=>:clear do
        check_conflict!
        clear(resource)
        status 204
      end

      app.patch '', :actions=>%i[clear merge fetch] do
        check_conflict!
        clear(resource)
        send_action(:merge, resource, data)
        serialize_models(fetch(resource))
      end

      app.post '', :actions=>%i[merge fetch] do
        merge(resource, data)
        serialize_models(fetch(resource))
      end

      app.delete '', :actions=>%i[reject fetch] do
        reject(resource, data)
        serialize_models(fetch(resource))
      end
    end
  end
end
