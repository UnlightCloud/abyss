Feature: Avatar Part Operation
  Background:
    Given authorized by JWT
      """
      {}
      """

  Scenario: The player name is required
    When I make a POST request to "/v1/operation/avatar_parts"
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
    When I make a POST request to "/v1/operation/avatar_parts"
    """
      {
        "player_name": "aotoki"
      }
    """
    Then the response status code should be 400
    And the response body should be
    """
    {
      "error": "Avatar Part Id is missing"
    }
    """

  Scenario: The player is not found
    When I make a POST request to "/v1/operation/avatar_parts"
    """
      {
        "player_name": "aotoki",
        "avatar_part_id": 1
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
    When I make a POST request to "/v1/operation/avatar_parts"
    """
      {
        "player_name": "aotoki",
        "avatar_part_id": 1
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
    When I make a POST request to "/v1/operation/avatar_parts"
    """
      {
        "player_name": "aotoki",
        "avatar_part_id": 1
      }
    """
    Then the response body should be
    """
    {
      "error": "Avatar Part not found"
    }
    """
    And the response status code should be 404
