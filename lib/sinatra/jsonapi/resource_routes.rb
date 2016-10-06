# frozen_string_literal: true
module Sinatra::JSONAPI::ResourceRoutes
  ACTIONS = %i[create destroy find list replace update].freeze

  def self.registered(app)
    app.get '/', :actions=>:list do
      serialize_models(list)
    end

    app.post '/', :actions=>:create do
      item =
        begin
          create(data)
        rescue Exception=>e
          raise e unless settings.action_conflicts[:create].include?(e.class)
          halt 409, e.message
        end

      status 201
      body serialize_model(item)
      if respond.body.respond_to?(:dig) && self_link = response.body.dig('data', 'links', 'self')
        headers 'Location'=>self_link
      end
    end

    app.get '/:id', :actions=>:find do |id|
      item = find(id)
      not_found unless item

      serialize_model(item)
    end

    %i[put post].each do |verb|
      app.send verb, '/:id', :actions=>%i[find replace] do |id|
        item = find(id)
        not_found unless item
        replace(item, data)

        serialize_model(item)
      end
    end

    app.patch '/:id', :actions=>%i[find update] do |id|
      item = find(id)
      not_found unless item
      update(item, data)

      serialize_model(item)
    end

    app.delete '/:id', :actions=>%i[find destroy] do |id|
      item = find(id)
      not_found unless item
      destroy(item)

      status 204
      body nil
    end
  end
end
