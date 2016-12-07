# frozen_string_literal: true
module Sinja
  module RelationshipRoutes
    module HasMany
      def self.registered(app)
        app.def_action_helper(app, :fetch, %i[roles filter_by sort_by])
        app.def_action_helper(app, :clear, %i[roles sideload_on])
        app.def_action_helper(app, :merge, %i[roles sideload_on])
        app.def_action_helper(app, :subtract, :roles)

        app.head '' do
          unless relationship_link?
            allow :get=>:fetch
          else
            allow :get=>:show, :patch=>[:clear, :merge], :post=>:merge, :delete=>:subtract
          end
        end

        app.get '', :actions=>:show do
          pass unless relationship_link?

          serialize_linkage
        end

        app.get '', :qparams=>%i[include fields filter sort page], :actions=>:fetch do
          filter_sort_page?(:fetch)
          collection, opts = fetch
          collection, links = filter_sort_page(collection)
          (opts[:links] ||= {}).merge!(links)
          serialize_models(collection, opts)
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
