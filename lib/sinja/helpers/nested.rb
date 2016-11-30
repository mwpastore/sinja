# frozen_string_literal: true
module Sinja
  module Helpers
    module Nested
      def relationship_link?
        !params[:r].nil?
      end
    end
  end
end
