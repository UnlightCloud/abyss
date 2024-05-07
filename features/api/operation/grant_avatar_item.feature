Feature: Grant Avatar Item
  Background:
    Given authorized by JWT
      """
      {}
      """

  Scenario: The player name is required
    When I make a POST request to "/v1/operation/avatar_items"
    """
      {}
    """
    Then the response status code should be 400
    And the response body should be
    """
    {
      "error": "Player Name is missing"
    }
    """

  Scenario: The avatar part id is required
    When I make a POST request to "/v1/operation/avatar_items"
    """
      {
        "player_name": "aotoki"
      }
    """
    Then the response status code should be 400
    And the response body should be
    """
    {
      "error": "Avatar Item Id is missing"
    }
    """

  Scenario: The player is not found
    When I make a POST request to "/v1/operation/avatar_items"
    """
      {
        "player_name": "aotoki",
        "avatar_item_id": 1
      }
    """
    Then the response body should be
    """
    {
      "error": "Player not found"
    }
    """
    And the response status code should be 404

  Scenario: The avatar is not found
    Given the following players
      | name   |
      | aotoki |
    When I make a POST request to "/v1/operation/avatar_items"
    """
      {
        "player_name": "aotoki",
        "avatar_item_id": 1
      }
    """
    Then the response body should be
    """
    {
      "error": "Avatar not found"
    }
    """
    And the response status code should be 404

  Scenario: The avatar part is not found
    Given the following players
      | name   |
      | aotoki |
    And the following avatars
      | name   | player_name |
      | Aotoki | aotoki      |
    When I make a POST request to "/v1/operation/avatar_items"
    """
      {
        "player_name": "aotoki",
        "avatar_item_id": 1
      }
    """
    Then the response body should be
    """
    {
      "error": "Avatar Item not found"
    }
    """
    And the response status code should be 404

  Scenario: Grant the avatar item success
    Given the following players
      | name   |
      | aotoki |
    And the following avatars
      | id | name   | player_name |
      | 1  | Aotoki | aotoki      |
    And the following avatar items
      | id | name       |
      | 1  | Elixir     |
    When I make a POST request to "/v1/operation/avatar_items"
    """
      {
        "player_name": "aotoki",
        "avatar_item_id": 1
      }
    """
    Then the response body should be
    """
    {
      "avatar_id": 1,
      "avatar_item_id": 1
    }
    """
    And the response status code should be 200
