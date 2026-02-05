-- Test 4539: Subquery - subquery in IIF

return {
  number = 4539,
  description = "Subquery - subquery in IIF",
  database = "vim_dadbod_test",
  query = "SELECT EmployeeID, IIF(Salary > (SELECT AVG()█ FROM Employees), 'Above', 'Below') FROM Employees",
  expected = {
    items = {
      includes = {
        "Salary",
      },
    },
    type = "column",
  },
}
