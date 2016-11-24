# require_string_literal: true
require_relative 'boot'

class BaseSerializer
  include JSONAPI::Serializer
end

Sequel::Model.plugin :tactical_eager_loading
Sequel::Model.plugin :validation_helpers
