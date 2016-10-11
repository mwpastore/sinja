# frozen_string_literal: true
module Sinatra::JSONAPI::ResourceRoutes
  def self.registered(app)
    app.settings._action_conflicts[:create] = true

    app.get '', :actions=>:list do
      serialize_models(*list)
    end

    app.post '', :actions=>:create do
      sanity_check!
      resource, = create(data.fetch(:attributes, {}), data[:id])
      dispatch_relationship_requests!(:method=>:patch)

      if resource
        status 201
        content = serialize_model(resource)
        if content.respond_to?(:dig) && self_link = content.dig(*%w[data links self])
          headers 'Location'=>self_link
        end
        body content
      elsif data.key?(:id) && method(:create).arity == 2
        status 204
      else
        # TODO???
        status 202
      end
    end

    app.get '/:id', :actions=>:find do |id|
      resource, = find(id)
      not_found unless resource
      serialize_model(resource)
    end

    %i[put post].each do |verb|
      app.send verb, '/:id', :actions=>%i[find replace] do |id|
        resource, = find(id)
        not_found unless resource
        replace(resource, data)
        serialize_model(resource)
      end
    end

    app.patch '/:id', :actions=>%i[find update] do |id|
      resource, = find(id)
      not_found unless resource
      update(resource, data.fetch(attributes, {}))
      serialize_model(resource)
    end

    app.delete '/:id', :actions=>%i[find destroy] do |id|
      resource, = find(id)
      not_found unless resource
      destroy(resource)
      status 204
    end
  end
end
