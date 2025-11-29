-- Test 4241: Scalar subquery - column reference

return {
  number = 4241,
  description = "Scalar subquery - column reference",
  database = "vim_dadbod_test",
  query = "SELECT (SELECT █ FROM Departments d WHERE d.DepartmentID = e.DepartmentID) AS DeptName FROM Employees e",
  expected = {
    items = {
      includes = {
        "DepartmentName",
      },
    },
    type = "column",
  },
}
