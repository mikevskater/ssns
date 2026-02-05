-- Test 4538: Subquery - subquery in COALESCE

return {
  number = 4538,
  description = "Subquery - subquery in COALESCE",
  database = "vim_dadbod_test",
  skip = false,
  query = "SELECT EmployeeID, COALESCE(DepartmentID, (SELECT █ FROM Departments WHERE DepartmentID = 1)) FROM Employees",
  expected = {
    items = {
      includes_any = {
        "DepartmentID",
        "ManagerID",
      },
    },
    type = "column",
  },
}
