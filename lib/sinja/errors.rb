# frozen_string_literal: true
require 'json'

module Sinja
  class SinjaError < StandardError
  end

  class ActionHelperError < SinjaError
  end

  class SideloadError < SinjaError
    attr_reader :http_status, :error_hashes

    def initialize(http_status, json)
      @http_status = http_status.to_i
      @error_hashes = JSON.parse(json, :symbolize_names=>true).fetch(:errors)
      super()
    end
  end

  class BadRequestError < defined?(Sinatra::BadRequest) ? Sinatra::BadRequest : TypeError
    def http_status; 400 end
  end

  class ForbiddenError < RuntimeError
    def http_status; 403 end
  end

  class NotFoundError < Sinatra::NotFound
    def http_status; 404 end
  end

  class MethodNotAllowedError < NameError
    def http_status; 405 end
  end

  class NotAcceptibleError < StandardError
    def http_status; 406 end
  end

  class ConflictError < StandardError
    def http_status; 409 end
  end

  class UnsupportedTypeError < TypeError
    def http_status; 415 end
  end

  class UnprocessibleEntityError < StandardError
    attr_reader :tuples

    def initialize(tuples=[])
      @tuples = [*tuples]

      fail 'Tuples not properly formatted' \
        unless @tuples.any? && @tuples.all? { |t| Array === t && t.length == 2 }
    end

    def http_status; 422 end
    def title; 'Validation Error' end
  end
end
