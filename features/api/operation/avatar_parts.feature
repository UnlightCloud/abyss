Feature: Avatar Part Operation
  Background:
    Given authorized by JWT
      """
      {}
      """

  Scenario: Grant Avatar Part to Player
    When I make a POST request to "/v1/operation/avatar_parts"
    """
    {}
    """
    Then the response status code should be 200
    And the response body should be
    """
    {}
    """
