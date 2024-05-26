Feature: List Weapon Cards

  Background:
    Given authorized by JWT
      """
      {}
      """

  Scenario: The weapon cards list is returned
    Given the following weapon cards
      | id | name       |
      | 1  | Ales Knife |
    When I make a GET request to "/v1/weapon_cards"
    Then the response body should be
    """
    {
      "data": [
        {
          "id": 1,
          "name": "Ales Knife"
        }
      ]
    }
    """
    And the response status code should be 200
