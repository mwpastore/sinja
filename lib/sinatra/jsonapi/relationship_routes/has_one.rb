# frozen_string_literal: true
module Sinatra::JSONAPI
  module RelationshipRoutes
    module HasOne
      ACTIONS = %i[pluck prune graft].freeze
      CONFLICT_ACTIONS = %i[graft].freeze

      def self.registered(app)
        app.def_action_helpers ACTIONS

        app.get '', :actions=>:pluck do
          serialize_model!(*pluck)
        end

        app.patch '', :nullif=>proc(&:nil?), :actions=>:prune do
          _, opts = prune
          serialize_model?(nil, opts)
        end

        app.patch '', :actions=>:graft do
          serialize_model?(*graft(data))
        end
      end
    end
  end
end
