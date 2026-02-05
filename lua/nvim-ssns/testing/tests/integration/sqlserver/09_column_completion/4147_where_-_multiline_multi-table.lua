-- Test 4147: WHERE - multiline multi-table

return {
  number = 4147,
  description = "WHERE - multiline multi-table",
  database = "vim_dadbod_test",
  query = [[SELECT *
FROM Employees e,
     Departments d
WHERE e.DepartmentID = d.DepartmentID
  AND e.█]],
  expected = {
    items = {
      includes = {
        "FirstName",
        "Salary",
      },
    },
    type = "column",
  },
}
