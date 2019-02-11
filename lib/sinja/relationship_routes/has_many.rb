# frozen_string_literal: true
module Sinja
  module RelationshipRoutes
    module HasMany
      def self.registered(app)
        app.def_action_helper(app, :fetch, %i[roles sideunload_on filter_by sort_by])
        app.def_action_helper(app, :clear, %i[roles sideload_on])
        app.def_action_helper(app, :replace, %i[roles sideload_on])
        app.def_action_helper(app, :merge, %i[roles sideload_on])
        app.def_action_helper(app, :subtract, :roles)

        app.options '' do
          unless relationship_link?
            allow :get=>:fetch
          else
            allow :get=>:show, :patch=>[:clear, :replace], :post=>:merge, :delete=>:subtract
          end
        end

        app.get '', :on=>proc { relationship_link? }, :actions=>:show do
          serialize_linkage
        end

        app.get '', :qparams=>%i[include fields filter sort page], :actions=>:fetch do
          fsp_opts = filter_sort_page?(:fetch)
          collection, opts = fetch
          collection, pagination = filter_sort_page(collection, fsp_opts.to_h)
          serialize_models(collection, opts, pagination)
        end

        app.patch '', :on=>proc { data.empty? }, :actions=>:clear do
          serialize_linkages?(*clear)
        end

        app.patch '', :actions=>:replace do
          serialize_linkages?(*replace(data))
        end

        app.post '', :actions=>:merge do
          serialize_linkages?(*merge(data))
        end

        app.delete '', :actions=>:subtract do
          serialize_linkages?(*subtract(data))
        end
      end
    end
  end
end
