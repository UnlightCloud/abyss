# frozen_string_literal: true

When('I make a GET request to {string}') do |path|
  get path
end

Then('the response status code should be {int}') do |status_code|
  expect(last_response.status).to eq(status_code)
end

Then('the response body should be') do |expected_json|
  expected = JSON.parse(expected_json)
  actual = JSON.parse(last_response.body)

  expect(actual).to eq(expected)
end
