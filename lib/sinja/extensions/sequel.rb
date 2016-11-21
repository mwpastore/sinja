# frozen_string_literal: true
require 'sinja/helpers/sequel'

module Sinja
  module Resource
    alias_method :core_has_one, :has_one

    def has_one(rel, &block)
      core_has_one(rel) do
        pluck do
          resource.send(rel)
        end

        prune do
          resource.send("#{rel}=", nil)
          resource.save_changes
        end

        graft do |rio|
          klass = resource.class.association_reflection(rel).associated_class
          resource.send("#{rel}=", klass.with_pk!(rio[:id]))
          resource.save_changes
        end

        instance_eval(&block) if block
      end
    end

    alias_method :core_has_many, :has_many

    def has_many(rel, &block)
      core_has_many(rel) do
        fetch do
          resource.send(rel)
        end

        clear do
          resource.send("remove_all_#{rel}")
        end

        merge do |rios|
          add_missing(rel, rios)
        end

        subtract do |rios|
          remove_present(rel, rios)
        end

        instance_eval(&block) if block
      end
    end
  end
end
