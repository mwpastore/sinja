# frozen_string_literal: true
require 'active_support/inflector'
require 'set'
require 'sinatra/jsonapi'

module Sinatra
  module JSONAPI
    module Resource
      Conflict = Class.new(StandardError)

      module Helpers
        def normalize_params!
          {
            :filter=>{},
            :fields=>{},
            :page=>{},
            :include=>[]
          }.each { |k, v| params[k] ||= v }
        end

        def data
          deserialize_request_body[:data]
        end

        def serialize_model(model=nil, options={})
          options[:is_collection] = false
          options[:skip_collection_check] = defined?(Sequel)

          ::JSONAPI::Serializer.serialize(model, options)
        end

        def serialize_models(models=[], options={})
          options[:is_collection] = true

          ::JSONAPI::Serializer.serialize([*models], options)
        end

        def singular?(noun)
          noun == ActiveSupport::Inflector.singularize(ActiveSupport::Inflector.pluralize(noun))
        end
      end

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

      def role(&block)
        helpers { define_method(__callee__, &block) }
      end

      ACTIONS.each do |action|
        define_method(action) do |**opts, &block|
          if opts.key?(:roles)
            fail "Roles not checked for `#{action}'" unless action_roles.key?(action)
            action_roles[action].replace([*opts[:roles]])
          end
          if opts.key?(:conflicts)
            fail "Conflicts not handled for `#{action}'" unless action_conflicts.key?(action)
            action_conflicts[action].replace([*opts[:conflicts]])
          end
          helpers { define_method(action, &block) } if block
        end
      end

      def self.registered(app)
        app.register JSONAPI

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

=begin
        has_one.each do |rel|
          ["/:id/relationships/#{rel.tr('_', '-')}", "/:id/#{rel.tr('_', '-')}"].each do |path|
            app.send :get, path, :actions=>[:find, "find_#{rel}".to_sym] do |id, rel|
              item = find(id)
              not_found unless item
        end

        has_many.each do |rel|
        end


            meth = "find_#{rel.tr('-', '_')}"
            if singular?(rel)
              not_found "To-one relationship `#{rel}' not found" unless respond_to?(meth)
              serialize_model(send(meth, item))
            else
              not_found "To-many relationship `#{rel}' not found" unless respond_to?(meth)
              serialize_models(send(meth, item))
            end
          end
        end

        app.patch '/:id/relationships/:rel', :actions=>%i[find] do |id, rel|
          item = find(id)
          not_found unless item
          if singular?(rel)
            meth, *args =
              if data.nil?
                ["clear_#{rel.tr('-', '_')}"]
              else
                ["update_#{rel.tr('-', '_')}", data]
              end

            not_found "To-one relationship `#{rel}' not found" unless item.respond_to?(meth)

            send(meth, *args)
            status 204
          else
            meth, *args =
              if data.empty?
                ["clear_#{rel.tr('-', '_')}"]
              else
                ["replace_#{rel.tr('-', '_')}", data]
              end

            not_found "To-many relationship `#{rel}' not found" unless item.respond_to?(meth)

            send(meth, *args)
            status 204
          end
        end

        app.post '/:id/relationships/:rel', :actions=>%i[find] do |id, rel|
          item = find(id)
          not_found unless item
          not_found "To-many relationship `#{rel}' not found" unless item.relationship?(rel)
                ["add_#{rel.tr('-', '_')}", data]

          # add member(s) to to-many relationship
        end

        app.delete '/:id/relationships/:rel', :actions=>%i[find] do |id, rel|
          item = find(id)
          not_found unless item
          not_found "To-many relationship `#{rel}' not found" unless item.relationship?(rel)

          # remove member(s) from to-many relationship
        end
=end
      end

      def inherited(subclass)
        super

        subclass.action_roles =
          Marshal.load(Marshal.dump(subclass.action_roles)).freeze

        subclass.action_conflicts =
          Marshal.load(Marshal.dump(subclass.action_conflicts)).freeze
      end
    end
  end

  register JSONAPI::Resource
end
