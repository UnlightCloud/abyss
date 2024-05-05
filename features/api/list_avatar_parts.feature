Feature: List Avatar Parts
  Background:
    Given authorized by JWT
      """
      {}
      """

  Scenario: The avatar parts list is returned
    Given the following avatar parts
      | id | name       |
      | 1  | Basic Hair |
    When I make a GET request to "/v1/avatar_parts"
    Then the response body should be
    """
    {
      "data": [
        {
          "id": 1,
          "name": "Basic Hair"
        }
      ]
    }
    """
    And the response status code should be 200
