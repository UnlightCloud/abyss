Feature: Root API
  Background:
    Given authorized by JWT
      """
      {}
      """

  Scenario: The API should return a 200 status code
    When I make a GET request to "/"
    Then the response status code should be 200
    And the response body should be
    """
    {
      "message": "Powered by UnlightCloud"
    }
    """
