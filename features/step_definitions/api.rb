# frozen_string_literal: true

Given('http headers') do |table|
  @headers ||= {}
  table.hashes.each do |row|
    @headers[row['key']] = row['value']
  end
end

When('I make a GET request to {string}') do |path|
  get path, nil, @headers || {}
end

Then('the response status code should be {int}') do |status_code|
  expect(last_response.status).to eq(status_code)
end

Then('the response body should be') do |expected_json|
  expected = JSON.parse(expected_json)
  actual = JSON.parse(last_response.body)

  expect(actual).to eq(expected)
end
