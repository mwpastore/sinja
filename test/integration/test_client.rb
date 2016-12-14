# frozen_string_literal: true
require_relative '../../demo-app/app'
require 'munson'

Munson.configure \
  adapter: [:rack, Sinatra::Application],
  response_key_format: :dasherize

module TestClient
  class Author < Munson::Resource
    self.type = :authors
  end

  class Comment < Munson::Resource
    self.type = :comments
  end

  class Post < Munson::Resource
    self.type = :posts
  end

  class Tag < Munson::Resource
    self.type = :tags
  end
end
