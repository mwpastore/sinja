# frozen_string_literal: true
module Sinja
  module ResourceRoutes
    ACTIONS = %i[index show create update destroy].freeze

    def self.registered(app)
      app.def_action_helpers(ACTIONS, app)

      app.head '', :pfilters=>:id do
        allow :get=>:show
      end

      app.get '', :pfilters=>:id, :actions=>:show do
        ids = params['filter'].delete('id')
        ids = ids.split(',') if ids.respond_to?(:split)

        opts = {}
        resources = [*ids].tap(&:uniq!).map! do |id|
          tmp, opts = show(id)
          raise NotFoundError, "Resource '#{id}' not found" unless tmp
          tmp
        end

        # TODO: Serialize collection with opts from last model found?
        serialize_models(resources, opts)
      end

      app.head '' do
        allow :get=>:index, :post=>:create
      end

      app.get '', :actions=>:index do
        serialize_models(*index)
      end

      app.post '', :actions=>:create do
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

      app.get '/:id', :actions=>:show do |id|
        tmp, opts = show(id)
        raise NotFoundError, "Resource '#{id}' not found" unless tmp
        serialize_model(tmp, opts)
      end

      app.patch '/:id', :actions=>:update do |id|
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
