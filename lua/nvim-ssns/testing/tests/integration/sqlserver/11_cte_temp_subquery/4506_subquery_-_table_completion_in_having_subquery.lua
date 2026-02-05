-- Test 4506: Subquery - table completion in HAVING subquery

return {
  number = 4506,
  description = "Subquery - table completion in HAVING subquery",
  database = "vim_dadbod_test",
  query = "SELECT DepartmentID, COUNT(*) FROM Employees GROUP BY DepartmentID HAVING COUNT(*) > (SELECT AVG(Budget) FROM █ )",
  expected = {
    items = {
      includes_any = {
        "Departments",
        "Employees",
      },
    },
    type = "table",
  },
}
