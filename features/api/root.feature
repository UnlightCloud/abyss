Feature: Root API

  Scenario: The API should return a 200 status code
    When I make a GET request to "/"
    Then the response status code should be 401
    And the response body should be
    """
    {
      "error": "Unauthorized"
    }
    """
