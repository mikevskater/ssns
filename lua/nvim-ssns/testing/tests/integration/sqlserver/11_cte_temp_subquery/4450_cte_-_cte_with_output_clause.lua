-- Test 4450: CTE - CTE with OUTPUT clause
-- SKIPPED: OUTPUT clause column completion not yet supported

return {
  number = 4450,
  description = "CTE - CTE with OUTPUT clause",
  database = "vim_dadbod_test",
  skip = false,
  query = [[WITH ToUpdate AS (SELECT EmployeeID FROM Employees WHERE DepartmentID = 1)
UPDATE Employees SET Salary = Salary * 1.1
OUTPUT inserted.█
WHERE EmployeeID IN (SELECT EmployeeID FROM ToUpdate)]],
  expected = {
    items = {
      includes = {
        "EmployeeID",
        "Salary",
        "FirstName",
      },
    },
    type = "column",
  },
}
