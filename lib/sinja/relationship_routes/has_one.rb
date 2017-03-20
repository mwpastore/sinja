# frozen_string_literal: true
module Sinja
  module RelationshipRoutes
    module HasOne
      def self.registered(app)
        app.def_action_helper(app, :pluck, :roles)
        app.def_action_helper(app, :prune, %i[roles sideload_on])
        app.def_action_helper(app, :graft, %i[roles sideload_on])

        app.options '' do
          unless relationship_link?
            allow :get=>:pluck
          else
            allow :get=>:show, :patch=>[:prune, :graft]
          end
        end

        app.get '', :on=>proc { relationship_link? }, :actions=>:show do
          serialize_linkage
        end

        app.get '', :qparams=>%i[include fields], :actions=>:pluck do
          serialize_model(*pluck)
        end

        app.patch '', :on=>proc { data.nil? }, :actions=>:prune do
          serialize_linkage?(*prune)
        end

        app.patch '', :actions=>:graft do
          serialize_linkage?(*graft(data))
        end
      end
    end
  end
end
