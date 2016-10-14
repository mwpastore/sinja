# frozen_string_literal: true
module Sinatra::JSONAPI::RelationshipRoutes
  module HasMany
    ACTIONS = %i[fetch clear merge subtract].freeze

    def self.registered(app)
      app.def_action_helpers ACTIONS
      app.action_conflicts :merge=>true

      app.get '', :actions=>:fetch do
        serialize_models!(*fetch(resource))
      end

      app.patch '', :nullif=>proc(&:empty?), :actions=>:clear do
        _, opts = clear(resource)
        serialize_models?([], opts)
      end

      app.patch '', :actions=>%i[clear merge] do
        _, clear_opts = clear(resource)
        subresources, merge_opts = merge(resource, data)
        serialize_models?(subresources, clear_opts.merge(merge_opts)) # TODO: DWIM?
      end

      app.post '', :actions=>%i[merge] do
        serialize_models?(*merge(resource, data))
      end

      app.delete '', :actions=>%i[subtract] do
        serialize_models?(*subtract(resource, data))
      end
    end
  end
end
