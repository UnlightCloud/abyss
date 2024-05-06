Feature: List Avatar Items

  Background:
    Given authorized by JWT
      """
      {}
      """

  Scenario: The avatar items list is returned
    Given the following avatar items
      | id | name   |
      | 1  | Elixir |
    When I make a GET request to "/v1/avatar_items"
    Then the response body should be
    """
    {
      "data": [
        {
          "id": 1,
          "name": "Elixir"
        }
      ]
    }
    """
    And the response status code should be 200
