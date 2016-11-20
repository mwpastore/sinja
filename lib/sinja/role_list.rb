# frozen_string_literal: true
require 'set'

module Sinja
  class RoleList < Set
    def ===(other)
      self.intersect?(Set === other ? other : Set[*other])
    end
  end
end
