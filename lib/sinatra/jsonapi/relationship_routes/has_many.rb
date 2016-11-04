# frozen_string_literal: true
module Sinatra::JSONAPI
  module RelationshipRoutes
    module HasMany
      ACTIONS = %i[fetch clear merge subtract].freeze
      CONFLICT_ACTIONS = %i[merge].freeze

      def self.registered(app)
        app.def_action_helpers(ACTIONS, app)

        app.get '', :actions=>:fetch do
          serialize_models(*fetch)
        end

        app.patch '', :nullif=>proc(&:empty?), :actions=>:clear do
          serialize_linkages?(*clear)
        end

        app.patch '', :actions=>%i[clear merge] do
          clear_updated, clear_opts = clear
          merge_updated, merge_opts = merge(data)
          serialize_linkages?(clear_updated||merge_updated, clear_opts.merge(merge_opts)) # TODO: DWIM?
        end

        app.post '', :actions=>%i[merge] do
          serialize_linkages?(*merge(data))
        end

        app.delete '', :actions=>%i[subtract] do
          serialize_linkages?(*subtract(data))
        end
      end
    end
  end
end
