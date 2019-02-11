# require_string_literal: true
require_relative '../boot'
require_relative '../database'

class BaseSerializer
  include JSONAPI::Serializer
end

Sequel::Model.plugin :tactical_eager_loading
Sequel::Model.plugin :whitelist_security
