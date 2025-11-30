-- Test 4676: JOIN ON - multiple conditions type check
-- SKIPPED: Type warning/compatibility checks not yet supported

return {
  number = 4676,
  description = "JOIN ON - multiple conditions type check",
  database = "vim_dadbod_test",
  skip = true,
  skip_reason = "Type warning/compatibility checks not yet supported",
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
