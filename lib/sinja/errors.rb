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
    def initialize(*args) super(400, *args) end
  end

  class ForbiddenError < HttpError
    def initialize(*args) super(403, *args) end
  end

  class NotFoundError < HttpError
    def initialize(*args) super(404, *args) end
  end

  class MethodNotAllowedError < HttpError
    def initialize(*args) super(405, *args) end
  end

  class NotAcceptibleError < HttpError
    def initialize(*args) super(406, *args) end
  end

  class ConflictError < HttpError
    def initialize(*args) super(409, *args) end
  end

  class UnsupportedTypeError < HttpError
    def initialize(*args) super(415, *args) end
  end

  class UnprocessibleEntityError < HttpError
    attr_reader :tuples

    def initialize(tuples=[])
      @tuples = [*tuples]

      fail 'Tuples not properly formatted' \
        unless @tuples.any? && @tuples.all? { |t| Array === t && t.length == 2 }

      super(422)
    end
  end
end
