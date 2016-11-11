# frozen_string_literal: true
require 'json'

module Sinja
  module Helpers
    module Relationships
      def dispatch_relationship_request(id, path, **opts)
        fake_env = env.merge 'PATH_INFO'=>"/#{id}/relationships/#{path}"
        fake_env['REQUEST_METHOD'] = opts[:method].to_s.tap(&:upcase!) if opts[:method]
        fake_env['rack.input'] = StringIO.new(JSON.fast_generate(opts[:body])) if opts.key?(:body)
        call(fake_env) # TODO: we may need to bypass postprocessing here
      end

      def dispatch_relationship_requests!(id, **opts)
        data.fetch(:relationships, {}).each do |path, body|
          response = dispatch_relationship_request(id, path, opts.merge(:body=>body))
          # TODO: Gather responses and report all errors instead of only first?
          halt(*response) unless (200...300).cover?(response[0])
        end
      end
    end
  end
end
