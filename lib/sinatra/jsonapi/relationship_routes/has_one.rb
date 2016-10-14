# frozen_string_literal: true
module Sinatra::JSONAPI::RelationshipRoutes
  module HasOne
    ACTIONS = %i[pluck prune graft].freeze

    def self.registered(app)
      app.def_action_helpers ACTIONS
      app.action_conflicts :graft=>true

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
