Feature: Grant Avatar Part
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

  Scenario: Grant the avatar part success
    Given the following players
      | name   |
      | aotoki |
    And the following avatars
      | id | name   | player_name |
      | 1  | Aotoki | aotoki      |
    And the following avatar parts
      | id | name       |
      | 1  | Basic Hair |
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
      "avatar_id": 1,
      "avatar_part_id": 1
    }
    """
    And the response status code should be 200

  Scenario: Grant the avatar part duplicate
    Given the following players
      | name   |
      | aotoki |
    And the following avatars
      | id | name   | player_name |
      | 1  | Aotoki | aotoki      |
    And the following avatar parts
      | id | name       |
      | 1  | Basic Hair |
    And the following avatar part grants
      | avatar_name | avatar_part_id |
      | Aotoki      | 1              |
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
      "error": "Avatar Part is duplicate"
    }
    """
    And the response status code should be 400
