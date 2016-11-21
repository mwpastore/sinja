# frozen_string_literal: true
module Sinja
  class MethodOverride
    def initialize(app)
      @app = app
    end

    def call(env)
      env['REQUEST_METHOD'] = env['HTTP_X_HTTP_METHOD_OVERRIDE'] if env.key?('HTTP_X_HTTP_METHOD_OVERRIDE') &&
        env['REQUEST_METHOD'] == 'POST' && env['HTTP_X_HTTP_METHOD_OVERRIDE'].tap(&:upcase!) == 'PATCH'

      @app.call(env)
    end
  end
end
