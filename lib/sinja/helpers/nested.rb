# frozen_string_literal: true
module Sinja
  module Helpers
    module Nested
      def relationship_link?
        !params[:r].nil?
      end

      def resource
        super || self.resource = find(params[:resource_id])
      end

      def sanity_check!
        super(params[:resource_id])
      end
    end
  end
end
