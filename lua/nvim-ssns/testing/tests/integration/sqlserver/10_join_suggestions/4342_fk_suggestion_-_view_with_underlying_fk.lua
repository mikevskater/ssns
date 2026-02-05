-- Test 4342: FK suggestion - view with underlying FK

return {
  number = 4342,
  description = "FK suggestion - view with underlying FK",
  database = "vim_dadbod_test",
  query = "SELECT * FROM vw_ActiveEmployees v JOIN █",
  expected = {
    items = {
      includes = {
        "Departments",
      },
    },
    type = "table",
  },
}
