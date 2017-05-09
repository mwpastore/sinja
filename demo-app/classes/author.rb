# frozen_string_literal: true
require_relative 'base'

DB.create_table?(:authors) do
  primary_key :id
  String :email, null: false, unique: true
  String :real_name
  String :display_name
  TrueClass :admin, default: false
  Float :created_at
  Float :updated_at
end

class Author < Sequel::Model
  plugin :boolean_readers
  plugin :finder
  plugin :timestamps

  set_allowed_columns :email, :real_name, :display_name, :admin

  finder def self.by_email(arg)
    where(email: arg)
  end

  one_to_many :comments
  one_to_many :posts
end

# We have to create an admin user here, otherwise we have no way to create one.
Author.create(email: 'all@yourbase.com', admin: true) if Author.where(admin: true).empty?

class AuthorSerializer < BaseSerializer
  attribute(:display_name) { object.display_name || 'Anonymous Coward' }

  has_many :comments
  has_many :posts
end

AuthorController = proc do
  helpers do
    def before_create(attr)
      halt 403, 'Only admins can admin admins' if attr.key?(:admin) && !role?(:superuser)
    end

    alias before_update before_create

    def find(id)
      Author.with_pk(id.to_i)
    end

    def role
      Array(super).tap do |a|
        a << :self if resource == current_user
      end
    end
  end

  show

  show_many do |ids|
    Author.where_all(id: ids.map!(&:to_i))
  end

  index do
    Author.dataset
  end

  create do |attr|
    author = Author.new(attr)
    author.save(validate: false)
    next_pk author
  end

  update(roles: %i[self superuser]) do |attr|
    resource.set(attr)
    resource.save_changes(validate: false)
  end

  destroy(roles: %i[self superuser]) do
    resource.destroy
  end

  has_many :comments do
    fetch(roles: :logged_in) do
      resource.comments_dataset
    end
  end

  has_many :posts do
    fetch do
      resource.posts_dataset
    end
  end
end
