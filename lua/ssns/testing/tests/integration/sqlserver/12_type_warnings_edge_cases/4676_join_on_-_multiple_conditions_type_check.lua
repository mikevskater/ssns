-- Test 4676: JOIN ON - multiple conditions type check

return {
  number = 4676,
  description = "JOIN ON - multiple conditions type check",
  database = "vim_dadbod_test",
  query = "SELECT * FROM Employees e JOIN Departments d ON e.DepartmentID = d.DepartmentID AND e.FirstName = d.DepartmentI█D",
  expected = {
    items = {
      includes_any = {
        "type_mismatch",
      },
    },
    type = "warning",
  },
}
