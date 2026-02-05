-- Test 4528: Subquery - lateral/APPLY with outer reference

return {
  number = 4528,
  description = "Subquery - lateral/APPLY with outer reference",
  database = "vim_dadbod_test",
  query = [[SELECT d.*, emp.*
FROM Departments d
CROSS APPLY (SELECT █ FROM Employees e WHERE e.DepartmentID = d.DepartmentID ORDER BY e.Salary DESC) emp]],
  expected = {
    items = {
      includes = {
        "EmployeeID",
        "FirstName",
        "Salary",
      },
    },
    type = "column",
  },
}
