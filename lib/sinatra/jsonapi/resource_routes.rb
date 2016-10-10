# frozen_string_literal: true
module Sinatra::JSONAPI::ResourceRoutes
  ACTIONS = %i[create destroy find list replace update].freeze

  def self.registered(app)
    app.get '/', :actions=>:list do
      serialize_models(list)
    end

    app.post '/', :actions=>:create do
      not_found unless has_relationships?(relationships.keys)

      item =
        begin
          create(*data.values_at(:attributes, :id))
        rescue Exception=>e
          raise e unless settings.action_conflicts[:create].include?(e.class)
          halt 409, e.message
        end

      dispatch_relationship_requests!(item, :method=>:patch)

      if item
        status 201
        content = serialize_model(item)
        if content.respond_to?(:dig) && self_link = content.dig(*%w[data links self])
          headers 'Location'=>self_link
        end
        body content
      elsif data.key?(:id) && method(:create).arity == 2
        status 204
      else
        status 202
      end
    end

    app.get '/:id', :actions=>:find do |id|
      not_found unless item = find(id)
      serialize_model(item)
    end

    %i[put post].each do |verb|
      app.send verb, '/:id', :actions=>%i[find replace] do |id|
        not_found unless item = find(id)
        replace(item, data)
        serialize_model(item)
      end
    end

    app.patch '/:id', :actions=>%i[find update] do |id|
      not_found unless item = find(id)
      update(item, attributes)
      serialize_model(item)
    end

    app.delete '/:id', :actions=>%i[find destroy] do |id|
      not_found unless item = find(id)
      destroy(item)
      status 204
    end
  end
end
