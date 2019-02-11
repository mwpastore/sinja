# frozen_string_literal: true
module Sinja
  module ResourceRoutes
    def self.registered(app)
      app.def_action_helper(app, :show, :roles)
      app.def_action_helper(app, :show_many)
      app.def_action_helper(app, :index, %i[roles filter_by sort_by])
      app.def_action_helper(app, :create, :roles)
      app.def_action_helper(app, :update, :roles)
      app.def_action_helper(app, :destroy, :roles)

      app.options '', :qcaptures=>{ :filter=>:id } do
        allow :get=>:show
      end

      app.get '', :qcaptures=>{ :filter=>:id }, :qparams=>%i[include fields], :actions=>:show do
        ids = @qcaptures.first # TODO: Get this as a block parameter?
        ids = ids.split(',') if ids.instance_of?(String)
        ids = Array(ids).tap(&:uniq!)

        collection, opts =
          if respond_to?(:show_many)
            show_many(ids)
          else
            finder =
              if respond_to?(:find)
                method(:find)
              else
                proc { |id| show(id).first }
              end

            [ids.map!(&finder).tap(&:compact!), {}]
          end

        raise NotFoundError, "Resource(s) not found" \
          unless ids.length == collection.length

        serialize_models(collection, opts)
      end

      app.options '' do
        allow :get=>:index, :post=>:create
      end

      app.get '', :qparams=>%i[include fields filter sort page], :actions=>:index do
        fsp_opts = filter_sort_page?(:index)
        collection, opts = index
        collection, pagination = filter_sort_page(collection, fsp_opts.to_h)
        opts[:collection_from] = :index
        serialize_models(collection, opts, pagination)
      end

      app.post '', :qparams=>%i[include fields], :actions=>:create do
        sanity_check!

        opts = {}
        transaction do
          id, self.resource, opts =
            begin
              create(*[attributes].tap { |a| a << data[:id] if data.key?(:id) })
            rescue ArgumentError
              kind = data.key?(:id) ? 'supported' : 'provided'

              raise ForbiddenError, "Client-generated ID not #{kind}"
            end

          dispatch_relationship_requests!(id, :from=>:create, :only=>:has_one)
          validate! if respond_to?(:validate!)
          id = after_create || id if respond_to?(:after_create)
          dispatch_relationship_requests!(id, :from=>:create, :only=>:has_many, :methods=>{ :has_many=>:post })
        end

        if resource
          content = serialize_model(resource, opts)
          if content.respond_to?(:dig) && self_link = content.dig(*%w[data links self])
            headers 'Location'=>self_link
          end
          [201, content]
        elsif data.key?(:id)
          204
        else
          raise ActionHelperError, "Unexpected return value(s) from `create' action helper"
        end
      end

      pkre = app._resource_config[:route_opts][:pkre]

      app.options %r{/#{pkre}} do
        allow :get=>:show, :patch=>:update, :delete=>:destroy
      end

      app.get %r{/(#{pkre})}, :qparams=>%i[include fields], :actions=>:show do |id|
        tmp, opts = show(*[].tap { |a| a << id unless respond_to?(:find) })
        raise NotFoundError, "Resource '#{id}' not found" unless tmp
        serialize_model(tmp, opts)
      end

      app.patch %r{/(#{pkre})}, :qparams=>%i[include fields], :actions=>:update do |id|
        sanity_check!(id)
        tmp, opts = transaction do
          update(attributes).tap do
            dispatch_relationship_requests!(id, :from=>:update)
            validate! if respond_to?(:validate!)
            after_update if respond_to?(:after_update)
          end
        end
        serialize_model?(tmp, opts)
      end

      app.delete %r{/#{pkre}}, :actions=>:destroy do
        _, opts = destroy
        serialize_model?(nil, opts)
      end
    end
  end
end
