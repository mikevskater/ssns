-- Test 4158: WHERE - complex boolean expression

return {
  number = 4158,
  description = "WHERE - complex boolean expression",
  database = "vim_dadbod_test",
  query = "SELECT * FROM Employees e WHERE (e.DepartmentID = 1 OR e.DepartmentID = 2) AND e█. > 50000",
  expected = {
    items = {
      includes = {
        "Salary",
      },
    },
    type = "column",
  },
}
