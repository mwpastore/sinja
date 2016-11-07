# frozen_string_literal: true
require 'sequel/model/inflections'

module Sinatra::JSONAPI
  module Helpers
    module Sequel
      include ::Sequel::Inflections

      def self.config(c)
        c.conflict_exceptions = [::Sequel::ConstraintViolation]
        #c.not_found_exceptions = [::Sequel::RecordNotFound]
        #c.validation_exceptions = [::Sequel::ValidationVailed], proc do
        #  format exception to json:api source.pointer and detail
        #end
      end

      def database
        ::Sequel::DATABASES.first
      end

      def transaction(&block)
        database.transaction(&block)
      end

      def next_pk(resource, **opts)
        [resource.pk, resource, opts]
      end

      def add_missing(association, *args)
        meth = "add_#{singularize(association)}".to_sym
        transaction do
          resource.lock!
          venn(:-, association, *args) do |subresource|
            resource.send(meth, subresource)
          end
          resource.reload
        end
      end

      def remove_present(association, *args)
        meth = "remove_#{singularize(association)}".to_sym
        transaction do
          resource.lock!
          venn(:&, association, *args) do |subresource|
            resource.send(meth, subresource)
          end
          resource.reload
        end
      end

      private

      def venn(operator, association, rios)
        klass = resource.class.association_reflection(association) # get e.g. ProductType for :types
        dataset = resource.send("#{association}_dataset")
        rios.map { |rio| rio[:id] }.tap(&:uniq!) # unique PKs in request payload
          .send(operator, dataset.select_map(klass.primary_key)) # set operation with existing PKs in dataset
          .each { |id| yield klass.with_pk!(id) } # TODO: return 404 if not found?
      end
    end
  end
end
