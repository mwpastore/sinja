# frozen_string_literal: true
require 'sequel/model/inflections'

module Sinja
  module Helpers
    module Sequel
      include ::Sequel::Inflections

      def self.config(c)
        c.conflict_exceptions << ::Sequel::ConstraintViolation
        c.not_found_exceptions << ::Sequel::NoMatchingRow
        c.validation_exceptions << ::Sequel::ValidationFailed
        c.validation_formatter = ->(e) { e.errors.keys.zip(e.errors.full_messages) }
      end

      def validate!
        raise ::Sequel::ValidationFailed, resource unless resource.valid?
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
      def add_missing(*args, &block)
        add_remove(:add, :-, *args, &block)
      end

      # <= association, rios, block
      def remove_present(*args, &block)
        add_remove(:remove, :&, *args, &block)
      end

      private

      def add_remove(meth_prefix, operator, association, rios)
        meth = "#{meth_prefix}_#{singularize(association)}".to_sym
        transaction do
          resource.lock!
          venn(operator, association, rios) do |subresource|
            resource.send(meth, subresource) \
              unless block_given? && !yield(subresource)
          end
          resource.reload
        end
      end

      def venn(operator, association, rios)
        dataset = resource.send("#{association}_dataset")
        klass = dataset.association_reflection.associated_class
        # does not / will not work with composite primary keys
        rios.map { |rio| rio[:id].to_i }
          .send(operator, dataset.select_map(:id))
          .each { |id| yield klass.with_pk!(id) }
      end
    end
  end
end
