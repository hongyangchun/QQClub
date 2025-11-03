#!/usr/bin/env ruby

# Simple Flower Incentive System Test

require 'net/http'
require 'json'
require 'uri'

API_BASE = 'http://localhost:3000/api/v1'
TOKEN = "eyJhbGciOiJIUzI1NiJ9.eyJ1c2VyX2lkIjoxLCJ3eF9vcGVuaWQiOiJ0ZXN0X2RoaF8wMDEiLCJyb2xlIjoidXNlciIsImV4cCI6MTc2MzI2MDU3MywiaWF0IjoxNzYwNjYxNTczLCJ0eXBlIjoiYWNjZXNzIn0.k2y0mzQ24BDRO4vJjeiZ23Dke3b5MB6k9BqJvmuGQ3g"

def make_request(method, path, data = nil)
  uri = URI("#{API_BASE}#{path}")
  http = Net::HTTP.new(uri.host, uri.port)
  http.read_timeout = 30

  request = case method
            when :get
              Net::HTTP::Get.new(uri)
            when :post
              Net::HTTP::Post.new(uri)
            else
              raise "Unsupported method: #{method}"
            end

  request['Content-Type'] = 'application/json'
  request['Authorization'] = "Bearer #{TOKEN}"
  request.body = data.to_json if data

  response = http.request(request)
  JSON.parse(response.body)
end

# Test 1: Get quota info
puts "Test 1: Getting quota info..."
begin
  response = make_request(:get, '/reading_events/1/flower_incentives/quota_info')
  puts "Response: #{response}"
  if response['success']
    puts "SUCCESS: Quota info retrieved"
    puts "Used: #{response['data']['used_flowers']}, Max: #{response['data']['max_flowers']}, Remaining: #{response['data']['remaining_flowers']}"
  else
    puts "ERROR: #{response['error']}"
  end
rescue => e
  puts "EXCEPTION: #{e.message}"
end
puts

# Test 2: Get my certificates
puts "Test 2: Getting my certificates..."
begin
  response = make_request(:get, '/reading_events/1/flower_incentives/my_certificates')
  puts "Response: #{response}"
  if response['success']
    puts "SUCCESS: Certificates retrieved"
    puts "Total certificates: #{response['data']['total_certificates']}"
  else
    puts "ERROR: #{response['error']}"
  end
rescue => e
  puts "EXCEPTION: #{e.message}"
end
puts

# Test 3: Get top three (will likely fail as event is not completed)
puts "Test 3: Getting top three..."
begin
  response = make_request(:get, '/reading_events/1/flower_incentives/top_three')
  puts "Response: #{response}"
  if response['success']
    puts "SUCCESS: Top three retrieved"
    puts "Event: #{response['data']['event']}"
  else
    puts "ERROR (expected): #{response['error']}"
  end
rescue => e
  puts "EXCEPTION: #{e.message}"
end
puts

puts "Simple flower incentive test completed."