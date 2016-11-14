# frozen_string_literal: true
require 'set'

class RoleList < Set
  def ===(other)
    self.intersect?(self.class === other ? other : self.class[*other])
  end
end
