-- Test 4664: Type compatibility - decimal = decimal (compatible)

return {
  number = 4664,
  description = "Type compatibility - decimal = decimal (compatible)",
  database = "vim_dadbod_test",
  query = "SELECT * FROM Projects WHERE Budget = Budget█",
  expected = {
    items = {
      valid = true,
    },
    type = "no_warning",
  },
}
