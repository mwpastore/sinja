# frozen_string_literal: true
require 'json'

module Sinja
  module Helpers
    module Relationships
      def dispatch_relationship_request(id, path, **opts)
        fake_env = env.merge 'PATH_INFO'=>"/#{id}/relationships/#{path}"
        fake_env['REQUEST_METHOD'] = opts[:method].to_s.tap(&:upcase!) if opts[:method]
        fake_env['rack.input'] = StringIO.new(JSON.fast_generate(opts[:body])) if opts.key?(:body)
        fake_env['sinja.passthru'] = opts.fetch(:from, :unknown).to_s
        fake_env['sinja.resource'] = resource if resource
        call(fake_env)
      end

      def dispatch_relationship_requests!(id, **opts)
        data.fetch(:relationships, {}).each do |path, body|
          response = dispatch_relationship_request(id, path, opts.merge(:body=>body))
          # TODO: Gather responses and report all errors instead of only first?
          # TODO: Will this break out of a transaction and force a rollback?
          throw(:halt, response) unless (200...300).cover?(response.first)
        end
      end
    end
  end
end
