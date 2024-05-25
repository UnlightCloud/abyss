Feature: List Character Cards

  Background:
    Given authorized by JWT
      """
      {}
      """

  Scenario: The character cards list is returned
    Given the following character cards
      | id | name  |
      | 1  | Sheri |
    When I make a GET request to "/v1/character_cards"
    Then the response body should be
    """
    {
      "data": [
        {
          "id": 1,
          "name": "Sheri"
        }
      ]
    }
    """
    And the response status code should be 200
