# frozen_string_literal: true
require 'json'

module Sinja
  class SinjaError < StandardError
  end

  class ActionHelperError < SinjaError
  end

  class HttpError < SinjaError
    attr_reader :http_status

    def initialize(http_status, message=nil)
      @http_status = http_status
      super(message)
    end
  end

  class SideloadError < HttpError
    attr_reader :error_hashes

    def initialize(http_status, json)
      @error_hashes = JSON.parse(json, :symbolize_names=>true).fetch(:errors)
      super(http_status)
    end
  end

  class BadRequestError < HttpError
    HTTP_STATUS = 400

    def initialize(*args) super(HTTP_STATUS, *args) end
  end

  class ForbiddenError < HttpError
    HTTP_STATUS = 403

    def initialize(*args) super(HTTP_STATUS, *args) end
  end

  class NotFoundError < HttpError
    HTTP_STATUS = 404

    def initialize(*args) super(HTTP_STATUS, *args) end
  end

  class MethodNotAllowedError < HttpError
    HTTP_STATUS = 405

    def initialize(*args) super(HTTP_STATUS, *args) end
  end

  class NotAcceptableError < HttpError
    HTTP_STATUS = 406

    def initialize(*args) super(HTTP_STATUS, *args) end
  end

  class ConflictError < HttpError
    HTTP_STATUS = 409

    def initialize(*args) super(HTTP_STATUS, *args) end
  end

  class UnsupportedTypeError < HttpError
    HTTP_STATUS = 415

    def initialize(*args) super(HTTP_STATUS, *args) end
  end

  class UnprocessibleEntityError < HttpError
    HTTP_STATUS = 422

    attr_reader :tuples

    def initialize(tuples=[])
      @tuples = [*tuples]

      fail 'Tuples not properly formatted' \
        unless @tuples.any? && @tuples.all? { |t| Array === t && t.length == 2 }

      super(HTTP_STATUS)
    end
  end
end
