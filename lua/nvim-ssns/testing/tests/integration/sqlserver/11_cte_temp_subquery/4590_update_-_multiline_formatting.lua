-- Test 4590: UPDATE - multiline formatting

return {
  number = 4590,
  description = "UPDATE - multiline formatting",
  database = "vim_dadbod_test",
  query = [[UPDATE Employees
SET
  FirstName = 'John',
  LastName = 'Doe',
 █ = 50000
WHERE EmployeeID = 1]],
  expected = {
    items = {
      includes = {
        "Salary",
        "DepartmentID",
      },
    },
    type = "column",
  },
}
