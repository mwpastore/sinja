# frozen_string_literal: true
require 'sinja/sequel/core'

module Sinja
  module Sequel
    module Helpers
      def self.included(base)
        base.prepend Core
      end

      def next_pk(resource, opts={})
        [resource.pk, resource, opts]
      end

      def add_remove(association, rios, try_convert=:to_i)
        meth_suffix = association.to_s.singularize
        add_meth = "add_#{meth_suffix}".to_sym
        remove_meth = "remove_#{meth_suffix}".to_sym

        dataset = resource.send("#{association}_dataset")
        klass = dataset.association_reflection.associated_class

        # does not / will not work with composite primary keys
        new_ids = rios.map { |rio| rio[:id].send(try_convert) }
        transaction do
          resource.lock!
          old_ids = dataset.select_map(klass.primary_key)
          in_common = old_ids & new_ids

          (new_ids - in_common).each do |id|
            subresource = klass.with_pk!(id)
            resource.send(add_meth, subresource) \
              unless block_given? && !yield(subresource)
          end

          (old_ids - in_common).each do |id|
            subresource = klass.with_pk!(id)
            resource.send(remove_meth, subresource) \
              unless block_given? && !yield(subresource)
          end

          resource.reload
        end
      end

      def add_missing(*args, &block)
        add_or_remove(:add, :-, *args, &block)
      end

      def remove_present(*args, &block)
        add_or_remove(:remove, :&, *args, &block)
      end

      private

      def add_or_remove(meth_prefix, operator, association, rios, try_convert=:to_i)
        meth = "#{meth_prefix}_#{association.to_s.singularize}".to_sym
        transaction do
          resource.lock!
          venn(operator, association, rios, try_convert) do |subresource|
            resource.send(meth, subresource) \
              unless block_given? && !yield(subresource)
          end
          resource.reload
        end
      end

      def venn(operator, association, rios, try_convert)
        dataset = resource.send("#{association}_dataset")
        klass = dataset.association_reflection.associated_class
        # does not / will not work with composite primary keys
        rios.map { |rio| rio[:id].send(try_convert) }
          .send(operator, dataset.select_map(klass.primary_key))
          .each { |id| yield klass.with_pk!(id) }
      end
    end
  end
end
