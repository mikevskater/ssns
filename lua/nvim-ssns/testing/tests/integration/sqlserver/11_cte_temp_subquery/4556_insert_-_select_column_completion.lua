-- Test 4556: INSERT - SELECT column completion

return {
  number = 4556,
  description = "INSERT - SELECT column completion",
  database = "vim_dadbod_test",
  query = "INSERT INTO Employees_Archive SELECT █ FROM Employees",
  expected = {
    items = {
      includes = {
        "EmployeeID",
        "FirstName",
        "DepartmentID",
      },
    },
    type = "column",
  },
}
