# frozen_string_literal: true
module Sinja
  module ResourceRoutes
    ACTIONS = %i[index show create update destroy].freeze
    CONFLICT_ACTIONS = %i[create update].freeze

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
          self.resource, opts = show(id)
          raise NotFoundError, "Resource '#{id}' not found" unless resource
          resource
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
        raise ForbiddenError, 'Client-generated IDs not supported' \
          if data[:id] && method(:create).arity != 2

        _, self.resource, opts = transaction do
          create(attributes, data[:id]).tap do |id, *|
            dispatch_relationship_requests!(id, :from=>:create, :method=>:patch)

            validate if respond_to?(:validate)
          end
        end

        if resource
          content = serialize_model(resource, opts)
          if content.respond_to?(:dig) && self_link = content.dig(*%w[data links self])
            headers 'Location'=>self_link
          end
          [201, content]
        elsif data[:id]
          204
        else
          raise ActionHelperError, "Unexpected return value(s) from `create' action helper"
        end
      end

      app.head '/:id' do
        allow :get=>:show, :patch=>[:find, :update], :delete=>[:find, :destroy]
      end

      app.get '/:id', :actions=>:show do |id|
        self.resource, opts = show(id)
        raise NotFoundError, "Resource '#{id}' not found" unless resource
        serialize_model(resource, opts)
      end

      app.patch '/:id', :actions=>%i[find update] do |id|
        sanity_check!(id)
        self.resource = find(id)
        raise NotFoundError, "Resource '#{id}' not found" unless resource
        serialize_model?(transaction do
          update(attributes).tap do
            dispatch_relationship_requests!(id, :from=>:update, :method=>:patch)

            validate if respond_to?(:validate)
          end
        end)
      end

      app.delete '/:id', :actions=>%i[find destroy] do |id|
        self.resource = find(id)
        raise NotFoundError, "Resource '#{id}' not found" unless resource
        _, opts = destroy
        serialize_model?(nil, opts)
      end
    end
  end
end
