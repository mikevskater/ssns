-- Test 4098: DELETE FROM - JOIN for filtering

return {
  number = 4098,
  description = "DELETE FROM - JOIN for filtering",
  database = "vim_dadbod_test",
  query = "DELETE e FROM Employees e JOIN █",
  expected = {
    items = {
      includes = {
        "Departments",
      },
    },
    type = "table",
  },
}
