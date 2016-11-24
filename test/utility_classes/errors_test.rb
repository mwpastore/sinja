# frozen_string_literal: true
require_relative '../test_helper'

require 'sinja/errors'
require 'json'

class TestHttpError < Minitest::Test
  def setup
    @error = Sinja::HttpError.new(418, "I'm a little teapot!")
  end

  def test_it_is_an_error
    assert_kind_of StandardError, @error
  end

  def test_it_has_attributes
    assert_equal 418, @error.http_status
    assert_match %r{teapot}, @error.message
  end
end

class TestOtherHttpError < Minitest::Test
  def setup
    @error = Sinja::HttpError.new(418)
  end

  def test_it_is_an_error
    assert_kind_of StandardError, @error
  end

  def test_it_has_attributes
    assert_equal 418, @error.http_status
    assert_match @error.class.name, @error.message
  end
end

class TestBadHttpError < Minitest::Test
  def setup
    Sinja::HttpError.new
  rescue Exception=>e
    @error = e
  end

  def test_it_raises_an_error
    assert_kind_of ArgumentError, @error
    refute_kind_of Sinja::HttpError, @error
  end
end

class TestSideloadError < Minitest::Test
  def setup
    @error = Sinja::SideloadError.new(418, '{"errors":[{"foo":"bar"}]}')
  end

  def test_it_is_an_error
    assert_kind_of Sinja::HttpError, @error
  end

  def test_it_has_attributes
    assert_equal 418, @error.http_status
    assert_equal [{:foo=>'bar'}], @error.error_hashes
    assert_equal @error.class.name, @error.message
  end
end

class TestBadSideloadError < Minitest::Test
  def setup
    Sinja::SideloadError.new(418, '{"this is bad json":')
  rescue Exception=>e
    @error = e
  end

  def test_it_raises_an_error
    assert_kind_of JSON::ParserError, @error
    refute_kind_of Sinja::HttpError, @error
  end
end

class TestBadSideloadError1 < Minitest::Test
  def setup
    Sinja::SideloadError.new(418, '{"this is ok json but with no errors key":null}')
  rescue Exception=>e
    @error = e
  end

  def test_it_raises_an_error
    assert_kind_of KeyError, @error
    refute_kind_of Sinja::HttpError, @error
  end
end

class TestBadSideloadError2 < Minitest::Test
  def setup
    Sinja::SideloadError.new(418, '["this is ok json but not a hash"]')
  rescue Exception=>e
    @error = e
  end

  def test_it_raises_an_error
    assert_kind_of TypeError, @error
    refute_kind_of Sinja::HttpError, @error
  end
end

class TestUnprocessibleEntityError < Minitest::Test
  def setup
    @error = Sinja::UnprocessibleEntityError.new([[:a, 1], [:b, 2], [:c, 3]])
  end

  def test_it_is_an_error
    assert_kind_of Sinja::HttpError, @error
  end

  def test_it_has_attributes
    assert_equal 422, @error.http_status
    assert_equal [[:a, 1], [:b, 2], [:c, 3]], @error.tuples
    assert_equal @error.class.name, @error.message
  end
end

class TestBadUnprocessibleEntityError < Minitest::Test
  def setup
    Sinja::UnprocessibleEntityError.new([[:a, 1], [:b, 2], [:c]])
  rescue Exception=>e
    @error = e
  end

  def test_it_is_an_error
    assert_kind_of RuntimeError, @error
    refute_kind_of Sinja::HttpError, @error
  end
end


class TestBadRequestError < Minitest::Test
  def setup
    @error = Sinja::BadRequestError.new('baba booey')
  end

  def test_it_is_an_error
    assert_kind_of Sinja::HttpError, @error
  end

  def test_it_has_attributes
    assert_equal 400, @error.http_status
    assert_equal 'baba booey', @error.message
  end
end

class TestForbiddenError < Minitest::Test
  def setup
    @error = Sinja::ForbiddenError.new('baba booey')
  end

  def test_it_is_an_error
    assert_kind_of Sinja::HttpError, @error
  end

  def test_it_has_attributes
    assert_equal 403, @error.http_status
    assert_equal 'baba booey', @error.message
  end
end

class TestNotFoundError < Minitest::Test
  def setup
    @error = Sinja::NotFoundError.new('baba booey')
  end

  def test_it_is_an_error
    assert_kind_of Sinja::HttpError, @error
  end

  def test_it_has_attributes
    assert_equal 404, @error.http_status
    assert_equal 'baba booey', @error.message
  end
end

class TestMethodNotAllowedError < Minitest::Test
  def setup
    @error = Sinja::MethodNotAllowedError.new('baba booey')
  end

  def test_it_is_an_error
    assert_kind_of Sinja::HttpError, @error
  end

  def test_it_has_attributes
    assert_equal 405, @error.http_status
    assert_equal 'baba booey', @error.message
  end
end

class TestNotAcceptibleError < Minitest::Test
  def setup
    @error = Sinja::NotAcceptibleError.new('baba booey')
  end

  def test_it_is_an_error
    assert_kind_of Sinja::HttpError, @error
  end

  def test_it_has_attributes
    assert_equal 406, @error.http_status
    assert_equal 'baba booey', @error.message
  end
end

class TestConflictError < Minitest::Test
  def setup
    @error = Sinja::ConflictError.new('baba booey')
  end

  def test_it_is_an_error
    assert_kind_of Sinja::HttpError, @error
  end

  def test_it_has_attributes
    assert_equal 409, @error.http_status
    assert_equal 'baba booey', @error.message
  end
end

class TestUnsupportedTypeError < Minitest::Test
  def setup
    @error = Sinja::UnsupportedTypeError.new('baba booey')
  end

  def test_it_is_an_error
    assert_kind_of Sinja::HttpError, @error
  end

  def test_it_has_attributes
    assert_equal 415, @error.http_status
    assert_equal 'baba booey', @error.message
  end
end
