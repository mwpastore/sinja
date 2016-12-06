# frozen_string_literal: true
require_relative '../base'
require_relative '../database'

DB.create_table?(:authors) do
  primary_key :id
  String :email, :null=>false, :unique=>true
  String :real_name
  String :display_name
  TrueClass :admin, :default=>false
  DateTime :created_at
  DateTime :updated_at
end

class Author < Sequel::Model
  plugin :timestamps
  plugin :boolean_readers

  finder def self.by_email(arg)
    where(:email=>arg)
  end

  one_to_many :comments
  one_to_many :posts
end

# We have to create an admin user here, otherwise we have no way to create one.
Author.create(email: 'all@yourbase.com', admin: true)

class AuthorSerializer < BaseSerializer
  attribute(:display_name) { object.display_name || 'Anonymous Coward' }

  has_many :comments
  has_many :posts
end

AuthorController = proc do
  helpers do
    def find(id)
      Author[id.to_i]
    end

    def role
      [*super].tap do |a|
        a << :myself if resource == current_user
      end
    end

    def settable_fields
      %i[email real_name display_name].tap do |a|
        a << :admin if role?(:superuser)
      end
    end
  end

  show

  index do
    Author.dataset
  end

  create do |attr|
    author = Author.new
    author.set_fields(attr, settable_fields)
    next_pk author.save(validate: false)
  end

  update(roles: %i[myself superuser]) do |attr|
    resource.update_fields(attr, settable_fields, validate: false, missing: :skip)
  end

  destroy(roles: %i[myself superuser]) do
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
