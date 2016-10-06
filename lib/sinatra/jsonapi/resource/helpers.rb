# frozen_string_literal: true
module Sinatra::JSONAPI::Resource::Helpers
  def normalize_params!
    # TODO: halt 400 if other params, or params not implemented?
    {
      :filter=>{},
      :fields=>{},
      :page=>{},
      :include=>[]
    }.each { |k, v| params[k] ||= v }
  end

  def data
    deserialize_request_body[:data]
  end

  def serialize_model(model=nil, options={})
    options[:is_collection] = false
    options[:skip_collection_check] = defined?(Sequel)

    ::JSONAPI::Serializer.serialize(model, options)
  end

  def serialize_models(models=[], options={})
    options[:is_collection] = true

    ::JSONAPI::Serializer.serialize([*models], options)
  end
end
