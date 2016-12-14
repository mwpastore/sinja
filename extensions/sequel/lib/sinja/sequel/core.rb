# frozen_string_literal: true
require 'forwardable'
require 'sequel'

module Sinja
  module Sequel
    module Core
      extend Forwardable

      def self.prepended(base)
        base.sinja do |c|
          c.conflict_exceptions << ::Sequel::ConstraintViolation
          c.not_found_exceptions << ::Sequel::NoMatchingRow
          c.validation_exceptions << ::Sequel::ValidationFailed
          c.validation_formatter = ->(e) { e.errors.keys.zip(e.errors.full_messages) }
        end

        base.include Pagination if ::Sequel::Database::EXTENSIONS.key?(:pagination)
      end

      def_delegator ::Sequel::Model, :db, :database

      def_delegator :database, :transaction

      define_method :filter, proc(&:where)

      def sort(collection, fields)
        collection.order(*fields.map { |k, v| ::Sequel.send(v, k) })
      end

      define_method :finalize, proc(&:all)

      def validate!
        raise ::Sequel::ValidationFailed, resource unless resource.valid?
      end
    end

    module Pagination
      def self.included(base)
        base.sinja { |c| c.page_using = {
          :number=>1,
          :size=>10,
          :record_count=>nil
        }}
      end

      def page(collection, opts)
        collection = collection.dataset unless collection.respond_to?(:paginate)

        opts = settings._sinja.page_using.merge(opts)
        collection = collection.paginate opts[:number].to_i, opts[:size].to_i,
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
      end
    end
  end
end
