-- Test 4608: DELETE - FROM with JOIN

return {
  number = 4608,
  description = "DELETE - FROM with JOIN",
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
