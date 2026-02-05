-- Test 4592: UPDATE - WHERE with subquery

return {
  number = 4592,
  description = "UPDATE - WHERE with subquery",
  database = "vim_dadbod_test",
  skip = false,
  query = [[UPDATE Employees SET Salary = Salary * 1.1
WHERE DepartmentID IN (SELECT █ FROM Departments WHERE Budget > 100000)]],
  expected = {
    items = {
      includes = {
        "DepartmentID",
      },
    },
    type = "column",
  },
}
