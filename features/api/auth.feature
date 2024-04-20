Feature: API Authentication

  Scenario: With invalid credentials
    Given http headers
      | key           | value                |
      | Authorization | Bearer invalid_token |
    When I make a GET request to "/"
    Then the response status code should be 401
