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

      app.head '', :qcapture=>{ :filter=>:id } do
        allow :get=>:show
      end

      app.get '', :qcapture=>{ :filter=>:id }, :qparams=>%i[include fields], :actions=>:show do
        ids = @qcaptures.first # TODO: Get this as a block parameter?
        ids = ids.split(',') if String === ids
        ids = [*ids].tap(&:uniq!)

        resources, opts = [], {}
        if respond_to?(:show_many)
          resources, opts = show_many(ids)
          raise NotFoundError, "Resource(s) not found" \
            unless ids.length == resources.length
        else
          ids.each do |id|
            tmp, opts = show(id)
            raise NotFoundError, "Resource '#{id}' not found" unless tmp
            resources << tmp
          end
        end

        serialize_models(resources, opts)
      end

      app.head '' do
        allow :get=>:index, :post=>:create
      end

      app.get '', :qparams=>%i[include fields filter sort page], :actions=>:index do
        fsp_opts = filter_sort_page?(:index)
        collection, opts = index
        collection, pagination = filter_sort_page(collection, fsp_opts)
        serialize_models(collection, opts, pagination)
      end

      app.post '', :qparams=>:include, :actions=>:create do
        sanity_check!

        opts = {}
        transaction do
          id, self.resource, opts =
            begin
              args = [attributes]
              args << data[:id] if data.key?(:id)
              create(*args)
            rescue ArgumentError
              if data.key?(:id)
                raise ForbiddenError, 'Client-generated ID not supported'
              else
                raise ForbiddenError, 'Client-generated ID not provided'
              end
            end

          dispatch_relationship_requests!(id, :from=>:create, :methods=>{ :has_many=>:post })
          validate! if respond_to?(:validate!)
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

      app.head '/:id' do
        allow :get=>:show, :patch=>:update, :delete=>:destroy
      end

      app.get '/:id', :qparams=>%i[include fields], :actions=>:show do |id|
        tmp, opts = show(id)
        raise NotFoundError, "Resource '#{id}' not found" unless tmp
        serialize_model(tmp, opts)
      end

      app.patch '/:id', :qparams=>:include, :actions=>:update do |id|
        sanity_check!(id)
        tmp, opts = transaction do
          update(attributes).tap do
            dispatch_relationship_requests!(id, :from=>:update)
            validate! if respond_to?(:validate!)
          end
        end
        serialize_model?(tmp, opts)
      end

      app.delete '/:id', :actions=>:destroy do |id|
        _, opts = destroy
        serialize_model?(nil, opts)
      end
    end
  end
end
