# frozen_string_literal: true
module Sinja
  module Helpers
    module Nested
      def defer(msg=nil)
        halt DEFER_CODE, msg
      end

      def relationship_link?
        !params[:r].nil?
      end
    end
  end
end
