# frozen_string_literal: true
module Sinatra::JSONAPI::RelationshipRoutes
  module HasMany
    ACTIONS = %i[fetch clear merge subtract].freeze

    def self.registered(app)
      app.def_action_helpers ACTIONS

      app.get '', :actions=>:fetch do
        serialize_models!(*fetch)
      end

      app.patch '', :nullif=>proc(&:empty?), :actions=>:clear do
        _, opts = clear
        serialize_models?([], opts)
      end

      app.patch '', :actions=>%i[clear merge] do
        _, clear_opts = clear
        subresources, merge_opts = merge(data)
        serialize_models?(subresources, clear_opts.merge(merge_opts)) # TODO: DWIM?
      end

      app.post '', :actions=>%i[merge] do
        serialize_models?(*merge(data))
      end

      app.delete '', :actions=>%i[subtract] do
        serialize_models?(*subtract(data))
      end
    end
  end
end
