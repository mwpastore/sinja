# frozen_string_literal: true
require 'sequel/model/inflections'

module Sinja
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

      # <= association, rios, block
      def add_missing(*args)
        add_remove(:add, :-, *args)
      end

      # <= association, rios, block
      def remove_present(*args)
        add_remove(:remove, :&, *args)
      end

      def update_present(association, rios)
        transaction do
          venn(:&, association, rios) do |subresource, rio|
            subresource.update(yield(rio))
          end
          resource.reload
        end
      end

      def ampup(*args, &block)
        transaction do
          add_missing(*args, &block)
          update_present(*args, &block)
        end
      end

      private

      def add_remove(meth_prefix, operator, association, rios)
        meth = "#{meth_prefix}_#{singularize(association)}".to_sym
        transaction do
          resource.lock!
          venn(operator, association, rios) do |subresource, rio|
            args = [subresource]
            args.push(yield(rio)) if block_given?
            resource.send(meth, *args)
          end
          resource.reload
        end
      end

      def venn(operator, association, rios)
        dataset = resource.send("#{association}_dataset")
        klass = resource.class.association_reflection(association)
        rios = rios.map { |rio| [rio[:id], rio] }.to_h
        rios.keys.send(operator, dataset.select_map(klass.primary_key)).each do |id|
          yield klass.with_pk!(id), rios[id]
        end
      end
    end
  end
end
