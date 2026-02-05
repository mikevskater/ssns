-- Test 4526: Subquery - subquery in INSERT SELECT

return {
  number = 4526,
  description = "Subquery - subquery in INSERT SELECT",
  database = "vim_dadbod_test",
  query = [[INSERT INTO Archive_Employees
SELECT * FROM (SELECT █ FROM Employees WHERE IsActive = 0) sub]],
  expected = {
    items = {
      includes = {
        "EmployeeID",
        "FirstName",
      },
    },
    type = "column",
  },
}
