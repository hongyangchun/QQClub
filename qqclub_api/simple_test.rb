#!/usr/bin/env ruby

# Simple test to check if methods are public
require_relative 'config/environment'

def check_method_visibility(model_class, method_name)
  model = model_class.first
  unless model
    puts "No #{model_class} found"
    return false
  end

  puts "Testing #{model_class}##{method_name}:"
  puts "  Method exists: #{model.respond_to?(method_name)}"
  puts "  Method is public: #{model.public_methods.include?(method_name)}"
  puts "  Method is private: #{model.private_methods.include?(method_name)}"

  begin
    result = model.send(method_name)
    puts "  Method call successful: #{result.class}"
    true
  rescue => e
    puts "  Method call failed: #{e.message}"
    false
  end
end

def main
  puts "🔍 Checking Method Visibility"
  puts "=" * 40

  models_and_methods = [
    [ReadingEvent, :as_json_for_api],
    [CheckIn, :as_json_for_api],
    [EventEnrollment, :as_json_for_api],
    [User, :as_json_for_api],
    [ShareAction, :as_json_for_api]
  ]

  results = models_and_methods.map do |model_class, method_name|
    check_method_visibility(model_class, method_name)
  end

  puts "\n📊 Summary:"
  puts "Working methods: #{results.count(true)}/#{results.count}"
end

main if __FILE__ == $0