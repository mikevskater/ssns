-- Test 4659: Type compatibility - varchar = varchar comparison

return {
  number = 4659,
  description = "Type compatibility - varchar = varchar comparison",
  database = "vim_dadbod_test",
  query = "SELECT * FROM Employees WHERE Email = FirstNa█me",
  expected = {
    items = {
      valid = true,
    },
    type = "no_warning",
  },
}
