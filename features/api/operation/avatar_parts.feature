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
        "player_name": "player"
      }
    """
    Then the response status code should be 400
    And the response body should be
    """
    {
      "error": "Avatar Part Id is missing"
    }
    """
