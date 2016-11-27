# frozen_string_literal: true
require 'json'

module Sinja
  module Helpers
    module Relationships
      def dispatch_relationship_request(id, path, **opts)
        fakenv = env.merge 'PATH_INFO'=>"/#{id}/relationships/#{path}"
        fakenv['REQUEST_METHOD'] = opts[:method].to_s.tap(&:upcase!) if opts[:method]
        fakenv['rack.input'] = StringIO.new(JSON.fast_generate(opts[:body])) if opts.key?(:body)
        fakenv['sinja.passthru'] = opts.fetch(:from, :unknown).to_s
        fakenv['sinja.resource'] = resource if resource
        call(fakenv)
      end

      def dispatch_relationship_requests!(id, **opts)
        data.fetch(:relationships, {}).each do |path, body|
          code, _, *json = dispatch_relationship_request(id, path, opts.merge(:body=>body))
          # TODO: Gather responses and report all errors instead of only first?
          # `halt' was called (instead of raise); rethrow it as best as possible
          raise SideloadError.new(code, json) unless (200...300).cover?(code)
        end
      end
    end
  end
end
