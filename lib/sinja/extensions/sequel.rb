# frozen_string_literal: true
require 'sinja/helpers/sequel'

module Sinja
  module Resource
    def sequel_has_one(rel, &block)
      has_one(rel) do
        pluck do
          resource.send(rel)
        end

        prune(sideload_on: :update) do
          resource.send("#{rel}=", nil)
          resource.save_changes
        end

        graft(sideload_on: %i[create update]) do |rio|
          klass = resource.class.association_reflection(rel).associated_class
          resource.send("#{rel}=", klass.with_pk!(rio[:id]))
          resource.save_changes(validate: !sideloaded?)
        end

        instance_eval(&block) if block
      end
    end

    def sequel_has_many(rel, &block)
      has_many(rel) do
        fetch do
          resource.send(rel)
        end

        clear(sideload_on: :update) do
          resource.send("remove_all_#{rel}")
        end

        replace(sideload_on: :update) do |rios|
          add_remove(rel, rios)
        end

        merge(sideload_on: :create) do |rios|
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
