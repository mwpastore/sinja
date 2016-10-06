# frozen_string_literal: true
require 'set'
require 'sinatra/jsonapi'
require 'sinatra/jsonapi/resource/helpers'
require 'sinatra/jsonapi/resource/relationships'

module Sinatra
  module JSONAPI
    module Resource
      ACTIONS = %i[
        create
        destroy
        find
        list
        replace
        update
      ].freeze

      abort 'JSONAPI actions can\'t be HTTP verbs!' \
        if ACTIONS.any? { |action| Sinatra::Base.respond_to?(action) }

      ACTIONS.each do |action|
        define_method(action) do |**opts, &block|
          if opts.key?(:roles)
            fail "Roles not enforced for `#{action}'" unless action_roles.key?(action)
            action_roles[action].replace([*opts[:roles]])
          end
          if opts.key?(:conflicts)
            fail "Conflicts not handled for `#{action}'" unless action_conflicts.key?(action)
            action_conflicts[action].replace([*opts[:conflicts]])
          end
          helpers { define_method(action, &block) } if block
        end
      end

      include Relationships

      def role(&block)
        helpers { define_method(__callee__, &block) }
      end

      def self.registered(app)
        app.register JSONAPI

        # TODO: freeze these structures deeply at some later time?
        app.set :action_roles,
          ACTIONS.map { |action| [action, Set.new] }.to_h.freeze

        app.set :action_conflicts,
          { :create=>[] }.freeze

        app.set :actions do |*actions|
          condition do
            actions.all? do |action|
              roles = settings.action_roles[action]
              halt 403 unless roles.empty? || Set[*role].intersect?(roles)
              halt 405 unless respond_to?(action)
              true
            end
          end
        end

        app.helpers Helpers

        app.before do
          normalize_params!
        end

        app.after do
          body serialize_response_body if response.ok?
        end

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
          if self_link = response.body['data']['links']['self']
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

        Relationships.registered(app)
      end

      def inherited(subclass)
        super

        subclass.action_roles =
          Marshal.load(Marshal.dump(subclass.action_roles)).freeze

        subclass.action_conflicts =
          Marshal.load(Marshal.dump(subclass.action_conflicts)).freeze

        Relationships.inherited(subclass)
      end
    end
  end

  register JSONAPI::Resource
end
