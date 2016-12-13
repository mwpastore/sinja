# frozen_string_literal: true
require 'forwardable'

module Sinja
  module Helpers
    module Sequel
      include ::Sequel::Inflections
      extend Forwardable

      def self.config(c)
        c.conflict_exceptions << ::Sequel::ConstraintViolation
        c.not_found_exceptions << ::Sequel::NoMatchingRow
        c.validation_exceptions << ::Sequel::ValidationFailed
        c.validation_formatter = ->(e) { e.errors.keys.zip(e.errors.full_messages) }

        c.page_using = {
          :number=>1,
          :size=>10,
          :record_count=>nil
        } if ::Sequel::Database::EXTENSIONS.key?(:pagination)
      end

      def_delegator ::Sequel::Model, :db, :database
      def_delegator :database, :transaction

      def sort(collection, fields)
        collection.order(*fields.map { |k, v| ::Sequel.send(v, k) })
      end

      def page(collection, opts)
        opts = settings._sinja.page_using.merge(opts)
        collection = collection.dataset \
          unless collection.respond_to?(:paginate)
        collection = collection.paginate \
          opts[:number].to_i,
          opts[:size].to_i,
          (opts[:record_count].to_i if opts[:record_count])

        # Attributes common to all pagination links
        base = {
          :size=>collection.page_size,
          :record_count=>collection.pagination_record_count
        }
        pagination = {
          :first=>base.merge(:number=>1),
          :self=>base.merge(:number=>collection.current_page),
          :last=>base.merge(:number=>collection.page_count)
        }
        pagination[:next] = base.merge(:number=>collection.next_page) if collection.next_page
        pagination[:prev] = base.merge(:number=>collection.prev_page) if collection.prev_page

        return collection, pagination
      end if ::Sequel::Database::EXTENSIONS.key?(:pagination)

      define_method :filter, proc(&:where)
      define_method :finalize, proc(&:all)

      def validate!
        raise ::Sequel::ValidationFailed, resource unless resource.valid?
      end

      def next_pk(resource, **opts)
        [resource.pk, resource, opts]
      end

      # <= association, rios, block
      def add_missing(*args, &block)
        add_or_remove(:add, :-, *args, &block)
      end

      # <= association, rios, block
      def remove_present(*args, &block)
        add_or_remove(:remove, :&, *args, &block)
      end

      def add_remove(association, rios)
        meth_suffix = association.to_s.singularize
        add = "add_#{meth_suffix}".to_sym
        remove = "remove_#{meth_suffix}".to_sym

        dataset = resource.send("#{association}_dataset")
        klass = dataset.association_reflection.associated_class

        # does not / will not work with composite primary keys
        new_ids = rios.map { |rio| rio[:id].to_s }
        transaction do
          resource.lock!
          old_ids = dataset.select_map(::Sequel.cast(klass.primary_key, String))
          in_common = old_ids & new_ids

          (new_ids - in_common).each do |id|
            resource.send(add, klass.with_pk!(id)) \
              unless block_given? && !yield(subresource)
          end

          (old_ids - in_common).each do |id|
            resource.send(remove, klass.with_pk!(id)) \
              unless block_given? && !yield(subresource)
          end

          resource.reload
        end
      end

      private

      def add_or_remove(meth_prefix, operator, association, rios)
        meth = "#{meth_prefix}_#{association.to_s.singularize}".to_sym
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
        rios.map { |rio| rio[:id].to_s }
          .send(operator, dataset.select_map(::Sequel.cast(klass.primary_key, String)))
          .each { |id| yield klass.with_pk!(id) }
      end
    end
  end
end
