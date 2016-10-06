# frozen_string_literal: true
module Sinatra::JSONAPI::Helpers
  def deserialize_request_body
    return {} unless request.body.respond_to?(:size) && request.body.size > 0

    request.body.rewind
    JSON.parse(request.body.read, :symbolize_names=>true)
  rescue JSON::ParserError
    halt 400, 'Malformed JSON in the request body'
  end

  def serialize_response_body
    JSON.generate(response.body)
  rescue JSON::GeneratorError
    halt 400, 'Unserializable entities in the response body'
  end

  def normalized_error
    return body if body.is_a?(Hash)

    if not_found? && detail = [*body].first
      title = 'Not Found'
      detail = nil if detail == '<h1>Not Found</h1>'
    elsif env.key?('sinatra.error') && detail = env['sinatra.error'].message
      title = 'Unknown Error'
    elsif detail = [*body].first
    end

    { title: title, detail: detail }
  end

  def error_hash(title: nil, detail: nil, source: nil)
    { id: SecureRandom.uuid }.tap do |hash|
      hash[:title] = title if title
      hash[:detail] = detail if detail
      hash[:status] = status.to_s if status
      hash[:source] = source if source
    end
  end
end
