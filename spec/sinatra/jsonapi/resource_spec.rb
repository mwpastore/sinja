require 'spec_helper'

describe Sinatra::JSONAPI::Resource do
  it 'has a version number' do
    expect(Sinatra::JSONAPI::Resource::VERSION).not_to be nil
  end

  it 'does something useful' do
    expect(false).to eq(true)
  end
end
