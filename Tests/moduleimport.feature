Feature: We can import the module
    In order to use the module
    As a user
    I want to import the module

Scenario: The module manifest can be imported
    Given the module manifest exists
    Given the module manifest is valid
    When we try to import the module
    Then the module is loaded without any exceptions

