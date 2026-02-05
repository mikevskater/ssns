-- Test 4584: UPDATE - subquery in SET

return {
  number = 4584,
  description = "UPDATE - subquery in SET",
  database = "vim_dadbod_test",
  query = "UPDATE Employees SET DepartmentID = (SELECT █ FROM Departments WHERE DepartmentName = 'IT')",
  expected = {
    items = {
      includes = {
        "DepartmentID",
      },
    },
    type = "column",
  },
}
