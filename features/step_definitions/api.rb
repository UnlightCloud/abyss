# frozen_string_literal: true

When('I make a GET request to {string}') do |path|
  get path
end

Then('the response status code should be {int}') do |status_code|
  expect(last_response.status).to eq(status_code)
end
