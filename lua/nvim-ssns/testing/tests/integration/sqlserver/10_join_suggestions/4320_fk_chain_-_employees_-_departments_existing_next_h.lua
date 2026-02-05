-- Test 4320: FK chain - Employees -> Departments (existing) + next hops

return {
  number = 4320,
  description = "FK chain - Employees -> Departments (existing) + next hops",
  database = "vim_dadbod_test",
  query = "SELECT * FROM Employees e JOIN Departments d ON e.DepartmentID = d.DepartmentID JOI█N ",
  expected = {
    items = {
      includes_any = {
        "Orders",
        "Countries",
      },
    },
    type = "join_suggestion",
  },
}
