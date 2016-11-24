# frozen_string_literal: true
require 'bundler/gem_tasks'
require 'rake/testtask'

Rake::TestTask.new do |t|
  t.test_files = FileList[File.expand_path('test/**/*_test.rb', __dir__)]
  t.warning = false
end

task default: :test
